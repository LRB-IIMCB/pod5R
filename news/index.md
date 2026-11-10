# Changelog

## pod5r 0.2.0 (development)

### Bug fixes

- **Heap memory is no longer overwritten when pore types and end reasons
  are read.** The pinned POD5 C API (`c0be435`) writes the string
  terminator one byte past the size it reports in `pod5_get_pore_type()`
  and `pod5_get_end_reason()`. The native reader now allocates one
  additional byte for both buffers. The issue affected every metadata
  request through
  [`read_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5.md),
  [`extract_pod5_signal()`](https://lrb-iimcb.github.io/pod5R/reference/extract_pod5_signal.md),
  [`process_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/process_pod5.md),
  and
  [`extract_pod5_signal_dorado()`](https://lrb-iimcb.github.io/pod5R/reference/extract_pod5_signal_dorado.md).
  Returned values are unchanged, but the overflow could corrupt memory
  and cause unpredictable crashes on other data or systems.

## pod5r 0.1.0 (development)

### Native POD5 reading

- **[`extract_pod5_signal_dorado()`](https://lrb-iimcb.github.io/pod5R/reference/extract_pod5_signal_dorado.md)**
  maps Dorado simplex child UUIDs through explicit `pi`, `sp`, `ts`, and
  `ns` tags to parent POD5 signal intervals. It preserves separate
  children and rejects missing or out-of-range coordinates.

- **Missing floating-point metadata** is normalised to `NA_real_` at the
  R boundary. Historical v0 event counts remain upstream migration
  defaults; see
  [`read_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5.md).

- **Read-count limits** are checked before selection and output
  allocations.

- **Duplicate file UUIDs** have regression coverage and documented
  selection semantics.

- **Native linkage** explicitly includes zlib. Fixture generation uses
  named member assignments to make changes to upstream structs easier to
  review.

- **[`read_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5.md)**
  retrieves read metadata and optional signals through the native POD5 C
  API, without Python or reticulate.

- **[`extract_pod5_signal()`](https://lrb-iimcb.github.io/pod5R/reference/extract_pod5_signal.md)**
  supports indexed UUID selection, exact raw counts, picoampere
  calibration, and chunk-aware sample intervals.

- **[`process_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/process_pod5.md)**
  processes consecutive read groups without retaining callback results,
  supporting incremental workflows on larger files.

- **[`read_pod5_runs()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5_runs.md)**
  exposes run metadata, context tags, and tracking dictionaries.

- **Mixed-run readers** initialise the upstream run cache in file-index
  order, preventing duplicate run records after acquisition-ID lookups.
