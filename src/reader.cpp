#include <Rcpp.h>
#include <pod5_format/c_api.h>
#include <cmath>
#include <algorithm>
#include <array>
#include <vector>
#include <cctype>
#include <climits>
#include <memory>
#include <unordered_map>

using namespace Rcpp;

namespace {
void check(pod5_error_t status) {
  if (status != POD5_OK) stop("POD5: %s", pod5_get_error_string());
}

// RAII wrapper for a POD5 read batch
using Batch = std::unique_ptr<Pod5ReadRecordBatch_t, decltype(&pod5_free_read_batch)>;
//RAII wrapper for POD5 run information
using Run = std::unique_ptr<RunInfoDictData_t, decltype(&pod5_free_run_info)>;
// Internal representation of an open POD5 file
struct Reader {
  Pod5FileReader_t* file;
  std::vector<size_t> offsets;
  explicit Reader(const std::string& path) : file(nullptr) {
    check(pod5_init());
    file = pod5_open_file(path.c_str());
    if (!file) stop("POD5: %s", pod5_get_error_string());
    // Store batch boundaries once for repeated bounded row-range reads
    try {
      // Populate the index cache first so mixed-run files stay consistent
      // no matter of the order of metadata and run-info requests.
      run_info_index_t run_count = 0;
      check(pod5_get_file_run_info_count(file, &run_count));
      // Iterate over every run-info entry
      for (run_info_index_t i = 0; i < run_count; ++i) {
        RunInfoDictData_t* raw = nullptr;
        check(pod5_get_file_run_info(file, i, &raw));
        Run run(raw, pod5_free_run_info);
      }
      size_t count = 0;
      check(pod5_get_read_batch_count(&count, file));
      offsets.push_back(0);
      for (size_t i = 0; i < count; ++i) {
        // Allow an R user to interrupt a potentially long scan
        checkUserInterrupt();
        Pod5ReadRecordBatch_t* raw = nullptr;
        check(pod5_get_read_batch(&raw, file, i));
        Batch batch(raw, pod5_free_read_batch); // Get the number of reads/row in this batch
        size_t rows = 0;
        check(pod5_get_read_batch_row_count(&rows, batch.get()));
        offsets.push_back(offsets.back() + rows);
      }
    } catch (...) { pod5_close_and_free_reader(file); throw; }
  }
  // Destructor
  ~Reader() { if (file) pod5_close_and_free_reader(file); }
};
// The R-facing POD5 reader is represented as an external pointer
Reader& reader(SEXP pointer) {
  if (TYPEOF(pointer) != EXTPTRSXP || R_ExternalPtrTag(pointer) != Rf_install("pod5r_reader"))
    stop("Please provide a valid POD5 reader.");
  XPtr<Reader> value(pointer); // Wrap the existing R external pointer
  if (!value.get() || !value->file) stop("POD5 reader is closed. Please open file again.");
  return *value;
}

// POD5 stores read IDs as 16-byte binary UUID - convert them to string
// which contains 36 visible characters plus a terminating null byte
std::string uuid(const uint8_t* id) {
  char value[37];
  check(pod5_format_read_id(id, value));
  return std::string(value);
}

// R ordinary numeric type is an IEEE-754 double. Values above 2^53 - 1
// silently lose integer precision. This converts an unsigned 64-bit integer
// safely to an R-compatible double
double exact(uint64_t value) {
  if (value > 9007199254740991ULL)
    stop("POD5 integer exceeds R precision ceiling (2^53 - 1).");
  return static_cast<double>(value);
}
}

// Open a POD5 file and return an R external pointer
// [[Rcpp::export]]
SEXP cpp_open_pod5(std::string path) {
  XPtr<Reader> ptr(new Reader(path), true, Rf_install("pod5r_reader"));
  return ptr;
}

// close an open POD5 reader
// [[Rcpp::export]]
void cpp_close_pod5(SEXP pointer) {
  if (TYPEOF(pointer) != EXTPTRSXP || R_ExternalPtrTag(pointer) != Rf_install("pod5r_reader"))
    stop("Please provide a valid POD5 reader.");
  XPtr<Reader> ptr(pointer); // Recover the typed C++ pointer
  if (ptr.get() && ptr->file) { check(pod5_close_and_free_reader(ptr->file)); ptr->file = nullptr; } // Mark the reader as closed
}

// [[Rcpp::export]]
List cpp_info_pod5(SEXP pointer) {
  Reader& r = reader(pointer); // Validate the R external pointer and get the associated C++ Reader
  FileInfo_t info{}; check(pod5_get_file_info(r.file, &info));
  run_info_index_t runs; check(pod5_get_file_run_info_count(r.file, &runs));
  // Construct the R list
  return List::create(_["file_identifier"] = uuid(info.file_identifier),
                      _["file_version"] = std::to_string(info.version.major) + "." + std::to_string(info.version.minor) + "." + std::to_string(info.version.revision),
                      _["num_reads"] = exact(r.offsets.back()),
                      _["num_batches"] = exact(r.offsets.size() - 1),
                      _["num_runs"] = runs);
}

// Read identifiers and sequencing run information

namespace {
// Convert POD5 key-value metadata to a named R character vector
CharacterVector tags(const KeyValueData& data) {
  CharacterVector values(data.size), names(data.size);
  for (size_t i = 0; i < data.size; ++i) { values[i] = data.values[i]; names[i] = data.keys[i]; }
  values.attr("names") = names;
  return values;
}
  // Convert one POD5 run-information record into an R list
  List run_info(const RunInfoDictData_t& r) {
    List result;
#define TEXT_FIELD(name) result[#name] = std::string(r.name)
    TEXT_FIELD(acquisition_id);
    TEXT_FIELD(experiment_name);
    TEXT_FIELD(flow_cell_id);
    TEXT_FIELD(flow_cell_product_code);
    TEXT_FIELD(protocol_name);
    TEXT_FIELD(protocol_run_id);
    TEXT_FIELD(sample_id);
    TEXT_FIELD(sequencing_kit);
    TEXT_FIELD(sequencer_position);
    TEXT_FIELD(sequencer_position_type);
    TEXT_FIELD(software);
    TEXT_FIELD(system_name);
    TEXT_FIELD(system_type);
#undef TEXT_FIELD
    // POD5 stores these timestamps as integer millisecond
    result["acquisition_start_time_ms"] = static_cast<double>(r.acquisition_start_time_ms);
    result["protocol_start_time_ms"] = static_cast<double>(r.protocol_start_time_ms);
    result["adc_max"] = r.adc_max;
    result["adc_min"] = r.adc_min;
    result["sample_rate"] = r.sample_rate;
    result["context_tags"] = tags(r.context_tags);
    result["tracking_id"] = tags(r.tracking_id);
    return result;
  }
}


// [[Rcpp::export]]
CharacterVector cpp_ids_pod5(SEXP pointer) {
  Reader& r = reader(pointer);
  size_t n = r.offsets.back();
  std::vector<std::array<uint8_t, 16>> ids(n);
  if (n) check(pod5_get_read_ids(r.file, n, reinterpret_cast<read_id_t*>(ids.data())));
  CharacterVector out(n);
  //check periodically to reduce overhead for large files
  for (size_t i = 0; i < n; ++i) { if (i % 4096 == 0) checkUserInterrupt(); out[i] =
    uuid(ids[i].data()); }
  return out;
}

// [[Rcpp::export]]
List cpp_runs_pod5(SEXP pointer) {
  Reader& r = reader(pointer);
  run_info_index_t n; check(pod5_get_file_run_info_count(r.file, &n));
  List out(n); CharacterVector names(n);
  for (run_info_index_t i = 0; i < n; ++i) {
    RunInfoDictData_t* raw = nullptr; check(pod5_get_file_run_info(r.file, i, &raw));
    // wrap the POD5 allocation in RAII smart pointer
    Run run(raw, pod5_free_run_info);
    out[i] = run_info(*run); names[i] = run->acquisition_id;
  }
  out.attr("names") = names;
  return out;
}

// Read metadata

namespace {
// POD5 stores reads in batches not a table, so identifying read of interest
// requires 2 coordinates: 'batch' - which read batch contains the read
// and 'row' inside batch to visit for finding given read
struct Location { size_t batch; size_t row; size_t output; };
  // R dataframes use integer-style row names so the single returned dataframe
  // can have at most 'INT_MAX' rows; so big POD5 need to be processed incrementally
  void check_read_count(size_t count) {
    if (count > INT_MAX) stop("Too many reads for one data frame. Use process_pod5().");
  }
  // convert floating point from pod5 to R numeric
  double metadata_number(float value) {
    // represent IEEE NaN missing values
    return std::isnan(value) ? NA_REAL : static_cast<double>(value);
  }
  // Determine which row should be returned (ID based or positional)
  std::vector<Location> select_rows(Reader& r, Nullable<CharacterVector> selection,
                                    double first, double limit) {
    std::vector<Location> result;
    // Explicid IDs supplied
    if (selection.isNotNull()) {
      CharacterVector ids(selection);
      check_read_count(ids.size());
      std::vector<uint8_t> bytes(ids.size() * 16);
      std::unordered_map<std::string, size_t> order;
      for (R_xlen_t i = 0; i < ids.size(); ++i) {
        if (CharacterVector::is_na(ids[i])) stop("Read IDs must not be missing.");
        std::string id = as<std::string>(ids[i]);
        // Exactly this pattern xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
        if (id.size() != 36) stop("Invalid read UUID.");
        for (size_t k = 0; k < id.size(); ++k) {
          // hyphens at exact positions
          bool dash =
            k == 8 ||
            k == 13 ||
            k == 18 ||
            k == 23;
          if (dash ? id[k] != '-' : !std::isxdigit(static_cast<unsigned char>(id[k])))
            stop("Invalid read UUID.");
          id[k] = static_cast<char>(std::tolower(static_cast<unsigned char>(id[k])));
        }
        if (order.count(id)) stop("Duplicate read UUID."); // TODO: figure out split reads!!!
        order[id] = i;
        size_t j = 0;
        for (size_t k = 0; k < id.size();) {
          if (id[k] == '-') { ++k; continue; }
          bytes[i * 16 + j++] = static_cast<uint8_t>(std::stoul(id.substr(k, 2), nullptr, 16));
          k += 2;
        }
      }
      std::vector<uint32_t> counts(r.offsets.size() - 1), rows(ids.size());
      size_t found = 0;
      if (ids.size()) check(pod5_plan_traversal(r.file, bytes.data(), ids.size(), counts.data(),
                   rows.data(), &found)); // Output: total number of located reads
      // Require every requested UUID to exist
      if (found != static_cast<size_t>(ids.size()))
        stop("Some requested read IDs were not found in this POD5 file.");
      // track the next entry to consume from that row array
      size_t cursor = 0;
      // Visit each batch that contains one or more requested reads
      for (size_t b = 0; b < counts.size(); ++b) {
        if (!counts[b]) continue;
        // Get the POD5 batch
        Pod5ReadRecordBatch_t* raw = nullptr;
        check(pod5_get_read_batch(&raw, r.file, b));
        // Transfer to the RAII wrapper
        Batch batch(raw, pod5_free_read_batch);
        // Process every requested row found inside this batch
        for (size_t j = 0; j < counts[b]; ++j) {
          size_t row = rows[cursor++];
          // POD5 metadata for this read
          ReadBatchRowInfo_t info{}; uint16_t version; // report version
          check(pod5_get_read_batch_row_info_data(batch.get(), row, READ_BATCH_ROW_INFO_VERSION,
                                                  &info, &version));
          result.push_back({b, row, order.at(uuid(info.read_id))});
        }
      }
      // Positional range-based read selection
    } else {
      size_t total = r.offsets.back(); //cumulative row count after the final batch
      // Clamp `first` to the total number of reads
      size_t begin = static_cast<size_t>(std::min(first, static_cast<double>(total)));
      // Determine how many rows can be returned
      size_t count = static_cast<size_t>(std::min(limit, static_cast<double>(total - begin)));
      // Check if the result can fit in a single R data frame
      check_read_count(count);
      result.reserve(count);
      // `upper_bound` finds the first boundary greater than `begin`
      auto upper = std::upper_bound(r.offsets.begin(),
                                    r.offsets.end(),
                                    begin
      );
      // Convert the iterator position into the batch index
      size_t b = static_cast<size_t>(upper - r.offsets.begin() - 1);
      // Generate one Location entry for every selected global read
      for (size_t i = 0; i < count; ++i) {
        while (begin + i >= r.offsets[b + 1]) ++b;
        result.push_back({b, begin + i - r.offsets[b], i});
      }
    }
    return result;
  }


  // Extract a requested portion of the signal for one POD5 read
  // Signals are divided into independently stored signal chunks.
  // 1. Determine which sample slice is requested.
  // 2. Obtain signal chunks associated with the read.
  // 3. Convert chunks overlapping the requested slice.
  // 4. Copy required samples into R vector.
  SEXP signal_slice(Reader& r, Pod5ReadRecordBatch_t* batch, size_t row,
                    const ReadBatchRowInfo_t& info, bool calibrated, double start, double end) {
    // represent POD5 uint64_t values as R-compatible doubles
    uint64_t begin = static_cast<uint64_t>(std::min(start, exact(info.num_samples)));
    uint64_t finish = static_cast<uint64_t>(std::min(end, exact(info.num_samples)));
    // Length of requested interval
    size_t length = finish > begin ? finish - begin : 0;
    if (length > static_cast<size_t>(R_XLEN_T_MAX)) stop("Signal is too long for an R vector.");
    // Raw signal values are integral ADC measurements -> IntegerVector
    // Calibrated values are floating-point physical signal values -> NumericVector
    RObject output = calibrated ? RObject(NumericVector(length)) : RObject(IntegerVector(length));
    if (!length) return output;
    std::vector<uint64_t> indices(info.signal_row_count);
    // Get the signal-row indices associated with this particular read
    check(pod5_get_signal_row_indices(batch, row, info.signal_row_count, indices.data()));
    std::vector<SignalRowInfo_t*> chunks(indices.size(), nullptr);
    // Get metadata for all relevant signal chunks
    check(pod5_get_signal_row_info(r.file, indices.size(), indices.data(), chunks.data()));
    // Ensure that cleanup happens automatically even in case of error
    struct Guard {
      std::vector<SignalRowInfo_t*>& chunks;
      ~Guard() { pod5_free_signal_row_info(chunks.size(), chunks.data()); }
    } guard{chunks};
    uint64_t position = 0;
    // sequentially process chunks
    for (auto chunk : chunks) {
      checkUserInterrupt();
      uint64_t next = position + chunk->stored_sample_count;
      // Decode chunk only if its interval overlaps requested slice
      if (next > begin && position < finish) {
        // Allocate temporary storage for the fully decoded raw signal chunk
        std::vector<int16_t> values(chunk->stored_sample_count);
        // Decode/decompress sig chunk into `values`
        check(pod5_get_signal(r.file, chunk, values.size(), values.data()));
        uint64_t lo = std::max(position, begin), hi = std::min(next, finish);
        // Copy overlapping samples to R output vector
        for (uint64_t i = lo; i < hi; ++i) {
          int value = values[i - position];
          if (calibrated) REAL(output)[i - begin] = (value +
              static_cast<double>(info.calibration_offset)) * info.calibration_scale;
          else INTEGER(output)[i - begin] = value;
        }
      }
      position = next;
      if (position >= finish) break;
    }
    if (position < finish) stop("POD5 signal chunks do not cover the declared sample count.");
    return output;
  }
}

// Read metadata and signals from selected POD5 reads

// return an R list containing:
// reads  -> dataframe with per-read metadata
// signal -> named list of signal vectors
// [[Rcpp::export]]
List cpp_reads_pod5(
    SEXP pointer,
    Nullable<CharacterVector> ids,
    double first,
    double limit,
    bool signal,
    bool calibrated,
    double start,
    double end
) {
  // Validate all numeric range arguments if they fall within limits
  // it can be effectively +Inf
  if (!std::isfinite(first) ||
      first < 0 ||
      first != std::floor(first) ||
      first > 9007199254740991.0 ||
      std::isnan(limit) ||
      limit < 0 ||
      limit != std::floor(limit) ||
      !std::isfinite(start) ||
      start < 0 ||
      start != std::floor(start) ||
      start > 9007199254740991.0 ||
      std::isnan(end) ||
      end < start ||
      end != std::floor(end))
    stop("Invalid native read or sample range.");

  // recover the underlying C++ Reader
  Reader& r = reader(pointer);
  auto locations = select_rows(r, ids, first, limit);
  size_t n = locations.size();
  // size check
  check_read_count(n);
  // Allocate all R output columns up front
  CharacterVector read_id(n), acquisition_id(n), pore_type(n), end_reason(n);
  // NumericVector is used for fields that may exceed the 32-bit R integer or otherwise pod5 numeric data
  NumericVector read_number(n), start_sample(n), num_samples(n), num_minknow_events(n), channel(n);
  NumericVector calibration_offset(n), calibration_scale(n), median_before(n), open_pore_level(n),
  expected_open_pore_level(n), selected_read_level(n);
  // R integer/logical
  IntegerVector well(n), sample_rate(n); LogicalVector forced(n);
  // one list element per selected read otherwise empty
  List signals(signal ? n : 0);
  Batch batch(nullptr, pod5_free_read_batch); size_t current = SIZE_MAX;
  std::unordered_map<int16_t, std::pair<std::string, int>> runs;
  std::unordered_map<int16_t, std::string> pores, reasons;
  // Process every selected read
  for (const auto& loc : locations) {
    // Allow R users to interrupt long operations
    checkUserInterrupt();
    if (loc.batch != current) {
      // Load a new batch only when necessary
      Pod5ReadRecordBatch_t* raw = nullptr; check(pod5_get_read_batch(&raw, r.file, loc.batch));
      // Replace the previously loaded batch
      batch.reset(raw);
      // Record which batch is now loaded
      current =
        loc.batch;
      // clear caches
      runs.clear(); pores.clear(); reasons.clear();
    }
    // Metadata for selected row within current batch
    ReadBatchRowInfo_t info{}; uint16_t version;
    check(pod5_get_read_batch_row_info_data(batch.get(), loc.row, READ_BATCH_ROW_INFO_VERSION,
                                            &info, &version));
    // Output to fill
    size_t i = loc.output;
    // Basic read metadata
    read_id[i] = uuid(info.read_id);
    read_number[i] = info.read_number;
    start_sample[i] = exact(info.start_sample);
    num_samples[i] = exact(info.num_samples);
    num_minknow_events[i] = exact(info.num_minknow_events);
    // Sequencing channel and well
    channel[i] = info.channel;
    well[i] = info.well;
    // Calibration and signal-level metadata
    calibration_offset[i] = metadata_number(info.calibration_offset);
    calibration_scale[i] =metadata_number(info.calibration_scale);
    median_before[i] = metadata_number(info.median_before); forced[i] = info.end_reason_forced; // Boolean indicating whether the end reason was forced
    open_pore_level[i] = metadata_number(info.open_pore_level);
    expected_open_pore_level[i] = metadata_number(info.expected_open_pore_level);
    selected_read_level[i] = metadata_number(info.selected_read_level);
    // Run information
    if (!runs.count(info.run_info)) {
      RunInfoDictData_t* raw = nullptr; check(pod5_get_run_info(batch.get(), info.run_info, &raw));
      // Ensure run-info memory is freed automatically at the end
      Run run(raw, pod5_free_run_info); runs[info.run_info] = {run->acquisition_id,
                                                               run->sample_rate};
    }
    acquisition_id[i] = runs.at(info.run_info).first; sample_rate[i] =
      runs.at(info.run_info).second;
    // `info.pore_type` is a dictionary index, not directly a string!!!
    if (!pores.count(info.pore_type)) {
      // two-step buffer-size pattern
      char dummy; size_t size = 0; auto status = pod5_get_pore_type(batch.get(), info.pore_type,
                                                                    &dummy, &size);
      // The expected response to the first is intentionally POD5_ERROR_STRING_NOT_LONG_ENOUGH
      if (status != POD5_ERROR_STRING_NOT_LONG_ENOUGH) check(status);
      // libpod5 writes the terminator one byte past the reported size, so allocate a spare byte
      std::vector<char> text(size + 1); check(pod5_get_pore_type(batch.get(), info.pore_type,
                                              text.data(), &size));
      // Copy string into std::string before the tmp vector disappears
      pores[info.pore_type] = text.data();
    }
    // Store pore-type text in R output
    pore_type[i] = pores.at(info.pore_type);

    // End-reason lookup
    if (!reasons.count(info.end_reason)) {
      char dummy; size_t size = 0; pod5_end_reason_t value;
      // required string buffer size
      auto status = pod5_get_end_reason(batch.get(), info.end_reason, &value, &dummy, &size);
      // Buffer-too-small is expected
      if (status != POD5_ERROR_STRING_NOT_LONG_ENOUGH) check(status);
      // Get complete end-reason
      // libpod5 writes the terminator one byte past the reported size, so allocate a spare byte
      std::vector<char> text(size + 1); check(pod5_get_end_reason(batch.get(), info.end_reason, &value,
                                              text.data(), &size));
      reasons[info.end_reason] = text.data();
    }
    end_reason[i] = reasons.at(info.end_reason);
    // Optional signal extraction - on demand
    if (signal) signals[i] = signal_slice(r, batch.get(), loc.row, info, calibrated, start, end);
  }
  // Construct the R metadata data frame
  List metadata;
#define COLUMN(name) metadata[#name] = name // Macro to avoid repetition
  COLUMN(read_id);
  COLUMN(read_number);
  COLUMN(start_sample);
  COLUMN(num_samples);
  COLUMN(channel);
  COLUMN(well);
  COLUMN(pore_type);
  COLUMN(calibration_offset);
  COLUMN(calibration_scale);
  COLUMN(median_before);
  COLUMN(end_reason); metadata["end_reason_forced"] = forced;
  COLUMN(acquisition_id);
  COLUMN(sample_rate);
  COLUMN(num_minknow_events);
  COLUMN(open_pore_level);
  COLUMN(expected_open_pore_level);
  COLUMN(selected_read_level);
#undef COLUMN // Remove macro definition
  // Force to behave as a data.frame
  metadata.attr("class") = "data.frame";
  metadata.attr("row.names") = IntegerVector::create(NA_INTEGER, -static_cast<int>(n));
  if (signal) signals.attr("names") = read_id;
  // Return both metadata and signal data in one structured R list
  return List::create(_["reads"] = metadata, _["signal"] = signals);
}


