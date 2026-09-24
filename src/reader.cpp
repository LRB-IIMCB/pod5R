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
        Batch batch(raw, pod5_free_read_batch); // Retrieve the number of reads/row in this batch
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

// [[Rcpp::export]]
// Open a POD5 file and return an R external pointer
SEXP cpp_open_pod5(std::string path) {
  XPtr<Reader> ptr(new Reader(path), true, Rf_install("pod5r_reader"));
  return ptr;
}

// [[Rcpp::export]]
// close an open POD5 reader
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
                      _["file_version"] = std::to_string(info.version.major) + "." +
                        std::to_string(info.version.minor) + "." + std::to_string(info.version.revision),
                        _["num_reads"] = exact(r.offsets.back()), _["num_batches"] = exact(r.offsets.size() - 1),
                        _["num_runs"] = runs);
}



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
  result["adc_max"] = r.adc_max; result["adc_min"] = r.adc_min; result["sample_rate"] =
    r.sample_rate;
  result["context_tags"] = tags(r.context_tags); result["tracking_id"] = tags(r.tracking_id);
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

