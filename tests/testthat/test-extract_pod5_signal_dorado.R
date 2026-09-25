################################################################################
# DORADO SPLIT MAPPING WITH THE REAL DRS EXAMPLE
################################################################################
.make_drs_split_case <- function() {
  file <- system.file("extdata", "drs-filtered.pod5",
                      package = "pod5R", mustWork = TRUE)
  metadata <- pod5R::read_pod5(file)
  suitable <- which(metadata$num_samples >= 40)
  if (length(suitable) == 0L) {
    stop("The example needs a read with at least 40 samples.")
  }
  parent <- metadata$read_id[suitable[1]]
  children <- c(
    "10000000-0000-4000-8000-000000000001",
    "10000000-0000-4000-8000-000000000002",
    "10000000-0000-4000-8000-000000000003"
  )
  if (any(children %in% metadata$read_id)) {
    stop("A test child UUID already exists in this example.")
  }
  tags <- data.frame(
    read_id = c(children[1:2], parent),
    pi = c(parent, parent, NA_character_),
    sp = c(0L, 12L, NA_integer_),
    ts = c(2L, 3L, 4L),
    ns = c(10L, 12L, 16L)
  )
  raw <- pod5R::extract_pod5_signal(
    file, read_ids = parent, end_sample = 40
  )[[1]]
  out <- list(file = file, tags = tags, raw = raw,
              parent = parent, children = children,
              metadata = metadata[suitable[1], ])
  return(out)
} # .make_drs_split_case
testthat::test_that("children map to distinct exact parent intervals", {
  x <- .make_drs_split_case()
  testthat::expect_error(
    pod5R::read_pod5(x$file, x$children[1]), "not found"
  )
  expected <- list(x$raw[3:10], x$raw[16:24], x$raw[5:16])
  names(expected) <- x$tags$read_id
  actual <- pod5R::extract_pod5_signal_dorado(x$file, x$tags)
  testthat::expect_identical(actual, expected)
  testthat::expect_equal(unname(lengths(actual)), c(8, 9, 12))
  testthat::expect_identical(
    pod5R::extract_pod5_signal_dorado(x$file, x$tags[3:1, ]),
    expected[3:1]
  )
  testthat::expect_identical(
    pod5R::extract_pod5_signal_dorado(x$file, x$tags[2, ]),
    expected[2]
  )
  third <- x$tags[1, ]
  third$read_id <- x$children[3]
  third$sp <- 24L
  third$ts <- 0L
  third$ns <- 8L
  three <- rbind(x$tags[1:2, ], third)
  expected_three <- c(expected[1:2], list(x$raw[25:32]))
  names(expected_three) <- three$read_id
  testthat::expect_identical(
    pod5R::extract_pod5_signal_dorado(x$file, three),
    expected_three
  )
})


testthat::test_that("calibration uses the parent calibration", {
  x <- .make_drs_split_case()
  raw <- pod5R::extract_pod5_signal_dorado(x$file, x$tags)
  expected <- lapply(raw, function(signal) {
    (signal + x$metadata$calibration_offset) *
      x$metadata$calibration_scale
  })
  actual <- pod5R::extract_pod5_signal_dorado(
    x$file, x$tags, calibrated = TRUE
  )
  testthat::expect_equal(actual, expected)
})


testthat::test_that("missing and inconsistent tags fail explicitly", {
  x <- .make_drs_split_case()
  testthat::expect_error(
    pod5R::extract_pod5_signal_dorado(x$file), "Reads is missing"
  )
  testthat::expect_error(
    pod5R::extract_pod5_signal_dorado(x$file, x$tags[, -2]),
    "Required columns missing"
  )
  bad <- x$tags
  bad$read_id[2] <- bad$read_id[1]
  testthat::expect_error(
    pod5R::extract_pod5_signal_dorado(x$file, bad), "unique"
  )
  for (column in c("sp", "ts", "ns")) {
    for (value in c(NA_real_, Inf, -1, 0.5)) {
      bad <- x$tags
      bad[[column]][1] <- value
      testthat::expect_error(
        pod5R::extract_pod5_signal_dorado(x$file, bad),
        "whole numbers"
      )
    }
  }
  bad <- x$tags
  bad$sp[3] <- 1
  testthat::expect_error(
    pod5R::extract_pod5_signal_dorado(x$file, bad),
    "requires a parent"
  )
  bad <- x$tags
  bad$ts[1] <- bad$ns[1] + 1
  testthat::expect_error(
    pod5R::extract_pod5_signal_dorado(x$file, bad),
    "Ts must be <= ns"
  )
  bad <- x$tags
  bad$ns[1] <- x$metadata$num_samples + 1
  testthat::expect_error(
    pod5R::extract_pod5_signal_dorado(x$file, bad),
    "exceeds the POD5 parent length"
  )
  bad <- x$tags
  bad$sp[1] <- 2^53 - 1
  testthat::expect_error(
    pod5R::extract_pod5_signal_dorado(x$file, bad),
    "exact R numeric precision"
  )
  bad <- x$tags
  bad$dx <- c(1, 0, -1)
  testthat::expect_error(
    pod5R::extract_pod5_signal_dorado(x$file, bad),
    "Duplex consensus"
  )
})
testthat::test_that("empty intervals and borrowed readers work", {
  x <- .make_drs_split_case()
  reader <- pod5R::open_pod5(x$file)
  on.exit(pod5R::close_pod5(reader), add = TRUE)
  empty <- x$tags[1, ]
  empty$sp <- x$metadata$num_samples
  empty$ts <- empty$ns <- 0
  testthat::expect_identical(
    pod5R::extract_pod5_signal_dorado(reader, empty)[[1]],
    integer()
  )
  testthat::expect_identical(
    pod5R::extract_pod5_signal_dorado(reader, empty, TRUE)[[1]],
    numeric()
  )
  testthat::expect_identical(
    pod5R::extract_pod5_signal_dorado(reader, x$tags[FALSE, ]),
    stats::setNames(list(), character())
  )
  testthat::expect_identical(
    pod5R::extract_pod5_signal_dorado(reader, x$tags),
    pod5R::extract_pod5_signal_dorado(x$file, x$tags)
  )
  bad <- x$tags
  bad$ns[1] <- x$metadata$num_samples + 1
  testthat::expect_error(
    pod5R::extract_pod5_signal_dorado(reader, bad), "parent length"
  )
  testthat::expect_true(pod5R::read_pod5_info(reader)$num_reads > 0)
  pod5R::close_pod5(reader)
  testthat::expect_error(
    pod5R::extract_pod5_signal_dorado(reader, x$tags), "closed"
  )
})


testthat::test_that("integer tag arithmetic does not overflow before range validation", {
  x <- .make_drs_split_case()
  bad <- x$tags[1, ]
  bad$sp <- .Machine$integer.max
  bad$ts <- 1L
  bad$ns <- 2L
  testthat::expect_error(
    pod5R::extract_pod5_signal_dorado(x$file, bad), "exceeds the POD5 parent length"
  )
})







