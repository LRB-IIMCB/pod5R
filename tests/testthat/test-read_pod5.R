# Use the POD5 test file provided with the package.
file <- system.file("extdata", "drs-filtered.pod5",
                    package = "pod5R", mustWork = TRUE)


# Calling `open_pod5()` without the `file` argument should fail with  error.
testthat::test_that("invalid inputs and closed readers are rejected", {
  testthat::expect_error(pod5R::open_pod5(), "File is missing")
  # A missing string value is not a valid file path.
  testthat::expect_error(pod5R::open_pod5(NA_character_), "single non-empty")
  reader <- pod5R::open_pod5(file)
  pod5R::close_pod5(reader)
  testthat::expect_error(pod5R::read_pod5_info(reader), "closed")
  # Closing an already closed reader should be harmless.
  testthat::expect_silent(pod5R::close_pod5(reader))
  # Sample coordinates exposed to R are one-based, so zero is invalid.
  testthat::expect_error(pod5R::read_pod5(file, start_sample = 0), "Start_sample")
})


testthat::test_that("DRS metadata and selection agree", {
  info <- pod5R::read_pod5_info(file)  # Read file metadata
  ids <- pod5R::read_pod5_ids(file) # Read all read UUIDs
  reads <- pod5R::read_pod5(file) # Read all read metadata
  testthat::expect_equal(nrow(reads), info$num_reads)
  # Reading all metadata in file order should produce the same UUID sequence as`read_pod5_ids()`
  testthat::expect_identical(reads$read_id, ids)
  testthat::expect_gte(length(ids), 3)
  # Request two reads by UUID in deliberately non-file order
  selected <- pod5R::read_pod5(file, read_ids = ids[c(3, 1)])
  # Confirm that the result follows the requested UUID order
  testthat::expect_identical(selected$read_id, ids[c(3, 1)])
  testthat::expect_length(pod5R::read_pod5_runs(file), info$num_runs)
})

testthat::test_that("DRS raw signal, calibration, and slicing agree", {
  full <- pod5R::read_pod5(file, num_reads = 1, signal = TRUE)
  raw <- full$signal[[1]]
  testthat::expect_type(raw, "integer")
  testthat::expect_length(raw, full$reads$num_samples[1])
  testthat::expect_gt(length(raw), 0)
  current <- pod5R::read_pod5(
    file, num_reads = 1, signal = TRUE, calibrated = TRUE
  )$signal[[1]]
  expected <- (raw + full$reads$calibration_offset[1]) *
    full$reads$calibration_scale[1]
  testthat::expect_equal(current, expected, tolerance = 1e-12)
  last <- min(100, length(raw))
  slice <- pod5R::read_pod5(
    file, num_reads = 1, signal = TRUE, end_sample = last
  )$signal[[1]]
  testthat::expect_identical(slice, raw[seq_len(last)])
})


testthat::test_that("DRS grouped processing preserves all read IDs", {
  ids <- pod5R::read_pod5_ids(file)
  seen <- character()
  count <- pod5R::process_pod5(file, function(reads) {
    seen <<- c(seen, reads$read_id)
  }, part_size = 10, verbose = FALSE)
  testthat::expect_identical(seen, ids)
  testthat::expect_equal(count, length(ids))
})
