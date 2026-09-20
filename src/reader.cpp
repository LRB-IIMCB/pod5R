#include <Rcpp.h>
#include <pod5_format/c_api.h>

// [[Rcpp::export]]
bool cpp_check_pod5() {
  if (pod5_init() != POD5_OK) {
    Rcpp::stop("POD5: %s", pod5_get_error_string());
  }

  return true;
}
