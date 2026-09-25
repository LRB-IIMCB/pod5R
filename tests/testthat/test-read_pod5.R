# Use the POD5 test file provided with the package.
file <- system.file("extdata", "drs-filtered.pod5",
                    package = "pod5R", mustWork = TRUE)


# Calling `open_pod5()` without the `file` argument should fail with  error.
testthat::test_that("invalid inputs and closed readers are rejected", {
  testthat::expect_error(pod5R::open_pod5(), "POD5 file is missing")
  # A missing string value is not a valid file path.
  testthat::expect_error(pod5R::open_pod5(NA_character_), "single, non-empty")
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
  # Read the first read together with its complete raw signal
  full <- pod5R::read_pod5(file, num_reads = 1, signal = TRUE)
  raw <- full$signal[[1]] # Extract the signal vector
  testthat::expect_type(raw, "integer")
  # The number of decoded signal samples should agree exactly with the `num_samples`
  testthat::expect_length(raw, full$reads$num_samples[1])
  testthat::expect_gt(length(raw), 0)
  # native implementation should apply stored calibration parameters correctly
  current <- pod5R::read_pod5(file, num_reads = 1, signal = TRUE, calibrated = TRUE)$signal[[1]]
  expected <- (raw + full$reads$calibration_offset[1]) *
    full$reads$calibration_scale[1]
  testthat::expect_equal(current, expected, tolerance = 1e-12)
  last <- min(100, length(raw))
  # should return the leading portion of the signal
  slice <- pod5R::read_pod5(file, num_reads = 1, signal = TRUE, end_sample = last)$signal[[1]]
  testthat::expect_identical(slice, raw[seq_len(last)])
})


testthat::test_that("DRS grouped processing preserves all read IDs", {
  ids <- pod5R::read_pod5_ids(file)
  seen <- character()
  # should traverse the entire file sequentially avoiding keeping all reads in memory
  count <- pod5R::process_pod5(file, function(reads) {
    seen <<- c(seen, reads$read_id)
  }, part_size = 10, verbose = FALSE)
  testthat::expect_identical(seen, ids)
  testthat::expect_equal(count, length(ids))
})


################################################################################
# INPUT VALIDATION AND READER LIFETIME
################################################################################

testthat::test_that("paths are validated before filesystem access", {
  invalid <- list(NULL, 1, TRUE, character(), NA_character_, "", c(file, file))
  for (path in invalid) {
    testthat::expect_error(pod5R::open_pod5(path), "single, non-empty")
  }
  testthat::expect_error(pod5R::open_pod5(tempdir()), "directory")
  testthat::expect_error(pod5R::open_pod5(tempfile()), "does not exist")

  corrupt_file <- tempfile(fileext = ".pod5")
  on.exit(unlink(corrupt_file), add = TRUE)
  writeLines("This is not a POD5 file", corrupt_file)
  testthat::expect_error(pod5R::open_pod5(corrupt_file), "POD5:")
})


testthat::test_that("invalid and serialised readers cannot be used", {
  testthat::expect_error(pod5R::close_pod5(1), "valid POD5 reader")
  reader <- pod5R::open_pod5(file)
  on.exit(pod5R::close_pod5(reader), add = TRUE)
  restored <- unserialize(serialize(reader, NULL))
  testthat::expect_error(pod5R::read_pod5_info(restored), "closed")
  testthat::expect_gt(pod5R::read_pod5_info(reader)$num_reads, 0)
})


################################################################################
# READ SELECTION AND SIGNAL BOUNDARIES
################################################################################

testthat::test_that("UUID validation and row ranges preserve selection semantics", {
  ids <- pod5R::read_pod5_ids(file)
  testthat::expect_error(pod5R::read_pod5(file, "invalid"), "UUID")
  testthat::expect_error(pod5R::read_pod5(file, NA_character_), "without missing")
  testthat::expect_error(pod5R::read_pod5(file, c(ids[1], toupper(ids[1]))), "unique")
  testthat::expect_error(pod5R::read_pod5(file, ids[1], first_read = 2), "row range")
  testthat::expect_error(pod5R::read_pod5(file, num_reads = -1), "Num_reads")
  testthat::expect_error(pod5R::read_pod5(file, first_read = 1.5), "First_read")
  testthat::expect_error(pod5R::read_pod5(file, signal = NA), "Signal")
  testthat::expect_error(pod5R::read_pod5(file, calibrated = 1), "Calibrated")
  testthat::expect_identical(pod5R::read_pod5(file, toupper(ids[2:1]))$read_id, ids[2:1])
  testthat::expect_identical(
    pod5R::read_pod5(file, first_read = 2, num_reads = 3)$read_id, ids[2:4]
  )

  for (selection in list(list(read_ids = character()), list(num_reads = 0),
                         list(first_read = length(ids) + 1))) {
    out <- do.call(pod5R::read_pod5, c(list(file = file, signal = TRUE), selection))
    testthat::expect_s3_class(out$reads, "data.frame")
    testthat::expect_equal(nrow(out$reads), 0)
    testthat::expect_identical(out$signal, stats::setNames(list(), character()))
  }
})


testthat::test_that("signal slices handle interior and out-of-range boundaries", {
  full <- pod5R::read_pod5(file, num_reads = 1, signal = TRUE)
  id <- full$reads$read_id[1]
  raw <- full$signal[[1]]
  testthat::expect_error(
    pod5R::extract_pod5_signal(file, id, start_sample = 5, end_sample = 4), "End_sample"
  )
  testthat::expect_identical(
    pod5R::extract_pod5_signal(file, id, start_sample = 2, end_sample = 20)[[1]], raw[2:20]
  )
  testthat::expect_identical(
    pod5R::extract_pod5_signal(file, id, end_sample = length(raw) + 100)[[1]], raw
  )
  testthat::expect_identical(
    pod5R::extract_pod5_signal(file, id, start_sample = length(raw) + 1)[[1]], integer()
  )
  testthat::expect_identical(
    pod5R::extract_pod5_signal(file, id, calibrated = TRUE,
                               start_sample = length(raw) + 1)[[1]], numeric()
  )
})


################################################################################
# GROUPED PROCESSING AND CALLBACK ERRORS
################################################################################

testthat::test_that("grouped signals and callback arguments are preserved", {
  expected <- pod5R::read_pod5(file, signal = TRUE)
  observed <- new.env(parent = emptyenv())
  observed$ids <- character()
  observed$signal <- list()
  observed$sizes <- integer()

  count <- pod5R::process_pod5(file, function(out, state) {
    state$ids <- c(state$ids, out$reads$read_id)
    state$signal <- c(state$signal, out$signal)
    state$sizes <- c(state$sizes, nrow(out$reads))
  }, state = observed, part_size = 10, signal = TRUE, verbose = FALSE)

  testthat::expect_equal(count, nrow(expected$reads))
  testthat::expect_identical(observed$ids, expected$reads$read_id)
  testthat::expect_identical(observed$signal, expected$signal)
  testthat::expect_true(all(observed$sizes <= 10))
})


testthat::test_that("callback failures preserve borrowed reader ownership", {
  reader <- pod5R::open_pod5(file)
  on.exit(pod5R::close_pod5(reader), add = TRUE)
  fail <- function(reads) stop("callback failure")
  testthat::expect_error(pod5R::process_pod5(reader, fail, verbose = FALSE), "callback failure")
  testthat::expect_gt(pod5R::read_pod5_info(reader)$num_reads, 0)
  testthat::expect_error(pod5R::process_pod5(file, fail, verbose = FALSE), "callback failure")
  testthat::expect_gt(pod5R::read_pod5_info(file)$num_reads, 0)
})
