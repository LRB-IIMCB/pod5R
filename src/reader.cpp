#include <Rcpp.h>
#include <pod5_format/c_api.h>
#include <algorithm>
#include <cmath>
#include <cctype>
#include <vector>
#include <array>
#include <unordered_map>
#include <climits>
#include <memory>
using namespace Rcpp;

namespace {
void check(pod5_error_t status) {
  if (status != POD5_OK) stop("POD5: %s", pod5_get_error_string());
}

using Batch = std::unique_ptr<Pod5ReadRecordBatch_t, decltype(&pod5_free_read_batch)>;
using Run = std::unique_ptr<RunInfoDictData_t, decltype(&pod5_free_run_info())>;
struct Reader {
  Pod5FileReader_t* file;
  std::vector<size_t> offsets;
  explicit Reader(const std::string& path) : file(nullptr) {
    check(pod5_init());
    file= pod5_open_file(path.c_str());
    if (!file) stop("POD5: %s", pod5_get_error_string());
    // Get batch boundaries - loading run info upfront would prevent from
    // errors in mixed-run files caused by the same indices
    try {
      run_info_index_t run_count=0;
      check(pod5_get_file_run_info_count(file, &run_count));
      for (run_info_index_t i=0; i<run_count; ++i) {
        RunInfoDictData_t* raw=nullptr;
        check(pod5_get_file_run_info(file, i, &raw));
        Run run(raw, pod5_free_run_info());
      }
      size_t count=0;
      check(pod5_get_read_batch_count(&count, file));
      offsets.push_back(0);
      for (size_t i = 0; i < count; ++i) {
        checkUserInterrupt();
        Pod5ReadRecordBatch_t* raw = nullptr;
        check(pod5_get_read_batch(&raw, file, i));
        Batch batch(raw, pod5_free_read_batch);
        size_t rows=0;
        check(pod5_get_read_batch_row_count(&rows, batch.get()));
        offsets.push_back(offsets.back() + rows);
      }
    } catch (...) { pod5_close_and_free_reader(file); throw; }
  }
  ~Reader() {if (file) pod5_close_and_free_reader(file);}
};
Reader& reader(SEXP pointer) {
  if (TYPEOF(pointer) !=EXTPTRSXP || R_ExternalPtrTag(pointer) != Rf_install("pod5r_reader"))
    stop("Provide a valid POD5 reader");
  XPtr<Reader> value(pointer);
  if (!value.get() || !value->file) stop("POD5 reader is closed. Reopen the file once again.");
  return *value;
}
std::string uuid(const uint8_t* id) {
  char value[37];
  check(pod5_format_read_id(id, value));
  return std::string(value);
}
double exact(uint64_t value) {
  if (value > 9007199254740991ULL)
    stop("POD5 integer exceeds R numeric precision (2^53-1)");
  return static_cast<double>(value);
}
}

// [[Rcpp::export]]
SEXP cpp_open_pod5(std::string path) {
  XPtr<Reader> ptr(new Reader(path), true, Rf_install("pod5r_reader"));
  return ptr;
}

// [[Rcpp::export]]
void cpp_close_pod5(SEXP pointer) {
  if (TYPEOF(pointer) != EXTPTRSXP || R_ExternalPtrTag(pointer) != Rf_install("pod5r_reader"))
    stop("Provided POD5 reader is invalid. Provide a correct one.");
  XPtr<Reader> ptr(pointer);
  if (ptr.get() && ptr->file) { check(pod5_close_and_free_reader(ptr->file)); ptr->file = nullptr; }
}

// [[Rcpp::export]]
List cpp_info_pod5(SEXP pointer) {
  Reader& r = reader(pointer);
  FileInfo_t info{}; check(pod5_get_file_info(r.file, &info));
  run_info_index_t runs; check(pod5_get_file_run_info_count(r.file, &runs));
  return List::create(_["file_identifier"] =uuid(info.file_identifier),
                      _["file_version"] = std::to_string(info.version.major) + "." + std::to_string(info.version.minor) + "." + std::to_string(info.version.revision),
                      _["num_reads"] = exact(r.offsets.back()),
                      _["num_batches"] = exact(r.offsets.size() -1),
                      _["num_runs"] = runs);
}
