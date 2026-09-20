#include <pod5_format/c_api.h>
#include <cstdio>

int main() {
  if (pod5_init() != POD5_OK) {
    std::fprintf(stderr, "%s\n", pod5_get_error_string());
    return 1;
  }

  std::puts("POD5 initialised successfully");

  if (pod5_terminate() != POD5_OK) {
    std::fprintf(stderr, "%s\n", pod5_get_error_string());
    return 1;
  }

  return 0;
}
