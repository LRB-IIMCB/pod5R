# pod5r 0.1.0 (development)

## Native POD5 reading

* **`extract_pod5_signal_dorado()`** maps Dorado simplex child UUIDs through
  explicit `pi`, `sp`, `ts`, and `ns` tags to parent POD5 signal intervals.
  It preserves separate children and rejects missing or out-of-range coordinates.

* **Missing floating-point metadata** is normalised to `NA_real_` at the R boundary.
  Historical v0 event counts remain upstream migration defaults; see `read_pod5()`.
* **Read-count limits** are checked before selection and output allocations.
* **Duplicate file UUIDs** have regression coverage and documented selection semantics.
* **Native linkage** explicitly includes zlib. Fixture generation uses named member
  assignments to make changes to upstream structs easier to review.

* **`read_pod5()`** retrieves read metadata and optional signals through the native
  POD5 C API, without Python or reticulate.
* **`extract_pod5_signal()`** supports indexed UUID selection, exact raw counts,
  picoampere calibration, and chunk-aware sample intervals.
* **`process_pod5()`** processes consecutive read groups without retaining callback
  results, supporting incremental workflows on larger files.
* **`read_pod5_runs()`** exposes run metadata, context tags, and tracking dictionaries.
* **Mixed-run readers** initialise the upstream run cache in file-index order,
  preventing duplicate run records after acquisition-ID lookups.
