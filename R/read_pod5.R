################################################################################
# ASSERTIONS
################################################################################
#' Assert condition is TRUE, stop with message if FALSE
#'
#' Base R replacement for assertthat::assert_that
#'
#' @param cond Logical condition to check
#' @param msg Error message if condition is FALSE
#'
#' @return Invisible TRUE if assertion passes
#' @keywords internal
#'
assert_condition <- function(cond, msg = "Assertion failed") {
  if (!isTRUE(cond)) {
    stop(msg, call. = FALSE)
  }
  return(invisible(TRUE))
}

#' Validate a non-negative whole number
#'
#' Checks if the value is a single numeric whole number greater than or equal to
#' defined minimum. A positive infinity is also accepted.
#'
#' Finite values must be a whole numbers and must not exceed 2^53 -1 (R precision
#' ceiling).
#'
#' @param x [numeric] value to validate
#' @param name [character] string which provides a name for 'x' used in the error
#' message if validation fails
#' @param minimum [numeric] the minimum allowed value. Default is 0.
#' @param allow_infinite [logical] decides whether 'Inf' is accepted. Defaults
#' to "FALSE".
#'
#' @returns Invisibly returns "TRUE" if validation passes.
#' @keywords internal
.check_number <- function(x, name, minimum = 0, allow_infinite = FALSE) {

  assert_condition(
    is.numeric(x) && length(x) == 1L &&
      !is.na(x) && x >= minimum && ((is.finite(x) && x==floor(x) && x<=2^53-1) || (allow_infinite && x==Inf)),
    paste0(name, " must be a whole number >= ", minimum, if (allow_infinite) "or Inf. " else "."))

  return(invisible(TRUE))
}

#' Validate POD5 read IDs
#'
#' Validates a vector of POD5 read identifiers and converts them to lowercase
#' UUID strings.
#'
#' Each read ID must be a non-missing character string containing a valid UUID.
#' Duplicate read IDs are not allowed.
#'
#' @param read_ids [character] vector of read IDs in UUID format or 'NULL'
#'
#' @returns a vector of validated 'read_ids' converted to lowercase or 'NULL'
#'
#' @keywords internal
.check_ids <- function(read_ids){
  if (!is.null(read_ids)){
    assert_condition(is.character(read_ids) && !anyNA(read_ids),
                     "Read_ids must be a character vec without missing values")
    assert_condition(all(grepl("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", read_ids)),
                     "Read ids must be a valid UUID strings")

    read_ids <- tolower(read_ids)
    assert_condition(!anyDuplicated(read_ids),
                     "Read_ids must be unique")
  }
  return(read_ids)
}

################################################################################
# NATIVE POD5 READING
################################################################################

#' Opens POD5 file through the native C API and stores read batch boundaries.
#'
#' The signals are decoded only on demand. Opening visits every read batch to
#' retrieve boundaries, so the cost grows accordingly to number of batches.
#' Reuse a reader for repeated queries.
#'
#' Readers own native resources. Use \code{on.exit(close_pod5(reader))} inside
#' functions. Garbage collector releases unclosed readers as well. Readers can't
#' be serialized or shared between R workers. Each worker must open its own reader.
#' Path inputs to other functions are closed by default.
#'
#' @param file [character] a path to a given POD5 file.
#'
#' @returns external pointer containing a native reader.
#' @export
#'
#' @examples
#' \dontrun{
#' reader <- pod5R::open_pod5("example_reads.pod5")
#' reads <- pod5R::read_pod5(reader)
#' pod5R::close_pod5(reader)
#' }
open_pod5 <- function(file){

  #assertions
  if(missing(file)){
    stop("POD5 file is missing. Please provide a valid file argument", call.=FALSE)
  }

  assert_condition(is.character(file) && length(file) ==1L && !is.na(file) && nzchar(file),
                   "File must be a single, non-empty path")

  assert_condition(file.exists(file) && !dir.exists(file),
                   "File does not exist or is a directory")

  outfile <- cpp_open_pod5(path.expand(file))
  return(outfile)
}




#' Close a native POD5 reader
#'
#' Closes an open POD5 reader and releases the resources. Closing the same reader repeatedly is safe.
#' An error is raised when 'reader' is missing.
#'
#' @param reader A pod5 reader to close - external pointer returned by \code{open_pod5()}
#'
#' @returns invisibly returns \code{NULL}
#' @export
#'
#' @examples
#' \dontrun{
#' reader <- pod5R::open_pod5("example_reads.pod5")
#' pod5R::close_pod5(reader)
#' }
close_pod5 <- function(reader){

  #assertions
  if(missing(reader)){
    stop("POD5 file reader is missing. Please provide a valid reader argument", call.=FALSE)
  }
  cpp_close_pod5(reader)
  return(invisible(NULL))
}



#' Read POD5 file information
#'
#' Retrieves the metadata (file identifier, format version, read, batch and counts).
#' The native \code{file_version} refers to the opened schema and might reflect the
#' automatic migration and not necessarily the original source version.
#'
#' If 'file' is a character string, the POD5 file is opened internally and automatically
#' close on function exit. If an existing reader is provided, it is used directly
#' and is not closed by this function.
#'
#' An error is raised when 'file' is missing.
#'
#' @param file [character] or external pointer: POD5 path or open native reader
#'
#' @returns Named list containing file information
#' @export
#'
#' @examples
#'\dontrun{
#'pod5R::read_pod5_info("example_reads.pod5")
#'}
read_pod5_info <- function(file) {

  #assertions
  if(missing(file)){
    stop("POD5 file is missing. Please provide a valid file argument", call.=FALSE)
  }

  reader <- file
  if (is.character(file)) {
    reader <- pod5R::open_pod5(file)
    on.exit(pod5R::close_pod5(reader), add=TRUE)
  }

  outfile <- cpp_info_pod5(reader)
  return(outfile)

}



#' Read POD5 read identifiers
#'
#' Retrieves read identifiers in file order without decompressing signals.
#'
#' @inheritParams read_pod5_info
#'
#' @returns A character vector of lowercase UUIDs.
#' @export
#' @examples
#' \dontrun{
#' read_ids <- pod5R::read_pod5_ids("reads.pod5")
#' }
read_pod5_ids <- function(file) {
  #assertions
  if (missing(file)) {
    stop("File is missing. Please provide a valid file argument.", call. = FALSE)
  }
  reader <- file
  if (is.character(file)) {
    reader <- pod5R::open_pod5(file)
    on.exit(pod5R::close_pod5(reader), add = TRUE)
  }

  out <- cpp_ids_pod5(reader)
  return(out)
}



#' Read POD5 sequencing run information
#'
#' Fetch acquisition and protocol identifiers, sample rate, device details,
#' calibration limits and the context.
#'
#' Time stamps in milliseconds. Read metadata links to runs through
#' \code{acquisition_id}, rather than batch indices.
#'
#' @inheritParams read_pod5_info
#'
#' @returns A list named by acquisition identifier. Each element contains a named
#' list describing one run, including named character vectors for dictionaries.
#' @export
#'
#' @examples
#' \dontrun{
#' runs <- pod5R::read_pod5_runs("reads.pod5")
#' }
read_pod5_runs <- function(file) {
  #assertions
  if (missing(file)) {
    stop("File is missing. Please provide a valid file argument.", call. = FALSE)
  }
  reader <- file
  if (is.character(file)) {
    reader <- pod5R::open_pod5(file)
    on.exit(pod5R::close_pod5(reader), add = TRUE)
  }
  out <- cpp_runs_pod5(reader)
  return(out)
}



#' Read POD5 metadata and signals (optionally)
#'
#' Captures read metadata with raw or calibrated signal (if requested), using native
#' indexed selection for given read ids (UUIDs).
#'
#' Read identifiers are returned in requested order. Missing identifiers
#' and duplicate selections throw errors. Without identifiers, reads follow file
#' order. Metadata access alone never decompresses signal data. Sample intervals
#' use R coordinates: one-based and inclusive. Bounds beyond a read are clipped;
#' a start beyond the read yields an empty vector. Only overlapping compressed
#' chunks are decoded. Universal interval applies to all selected reads.
#' When a file contains repeated UUIDs, indexed selection returns one occurrence
#' chosen by the native library. Use row ranges or \code{process_pod5()} to get
#' every occurrence.
#'
#' Read \code{start_sample} retains its original zero-based acquisition coordinate.
#' Signal orientation remains acquisition order. Calibration is
#'\code{(raw_signal + calibration_offset) * calibration_scale} in picoamperes.
#'
#' Output memory grows with selected reads and samples. Use \code{process_pod5()}
#' for bounded read groups. Native file mapping and the POD5 chunk cache also
#' consume memory. Opening a reader caches batch boundaries, not signal vectors.
#'
#' Dorado split children have new UUIDs that are not stored in original POD5 file.
#' Use \code{extract_pod5_signal_dorado()} with parent and sample tags from Dorado
#' SAM/BAM to extract their signal intervals.
#'
#' @inheritParams read_pod5_info
#'
#' @param read_ids [character] (default: \code{NULL}). Unique read UUIDs. NULL selects by row range.
#' @param signal [logical] (default: \code{FALSE}). Include signal vectors in the returned list.
#' @param calibrated [logical] (default: \code{FALSE}). Return signal in picoampers instead of ADC counts.
#' @param start_sample [numeric] (default: \code{1}). First signal sample, one-based and inclusive.
#' @param end_sample [numeric] (default: \code{Inf}). Last signal sample, one-based and inclusive.
#' @param first_read [numeric] (default: \code{1}). First read in file order, one-based.
#' @param num_reads [numeric] (default: \code{Inf}). Maximum number of reads. Cannot be combined
#' with read_ids unless first_read and num_reads retain their defaults.
#'
#' @returns If signal is FALSE, a plain metadata data frame. Otherwise, a named
#' list with \code{reads} (metadata) and \code{signal} (vectors named by UUID).
#' Raw signals are integer vectors. Calibrated signals are numeric vectors.
#'
#' @seealso \code{\link{extract_pod5_signal}}
#' @export
#' @examples
#' \dontrun{
#' reads <- pod5R::read_pod5("reads.pod5")
#' out <- pod5R::read_pod5("reads.pod5", read_ids = reads$read_id[1:5],
#' signal = TRUE, calibrated = TRUE)
#' }
read_pod5 <- function(file,
                      read_ids = NULL,
                      signal = FALSE,
                      calibrated = FALSE,
                      start_sample = 1,
                      end_sample = Inf,
                      first_read = 1,
                      num_reads = Inf) {
  #assertions
  if (missing(file)) {
    stop("File is missing. Please provide a valid file argument.", call. = FALSE)
  }
  read_ids <- .check_ids(read_ids)
  assert_condition(is.logical(signal) && length(signal) == 1L && !is.na(signal),
                   "Signal must be TRUE or FALSE.")
  assert_condition(is.logical(calibrated) && length(calibrated) == 1L && !is.na(calibrated),
                   "Calibrated must be TRUE or FALSE.")
  .check_number(start_sample, "Start_sample", 1)
  .check_number(end_sample, "End_sample", 1, TRUE)
  .check_number(first_read, "First_read", 1)
  .check_number(num_reads, "Num_reads", 0, TRUE)
  assert_condition(end_sample >= start_sample, "End_sample must be >= start_sample.")
  assert_condition(is.null(read_ids) || (first_read == 1 && num_reads == Inf),
                   "Read_ids cannot be combined with a read row range.")
  reader <- file
  if (is.character(file)) {
    reader <- pod5R::open_pod5(file)
    on.exit(pod5R::close_pod5(reader), add = TRUE)
  }
  out <- cpp_reads_pod5(reader, read_ids, first_read - 1, num_reads,
                        signal, calibrated, start_sample - 1, end_sample)
  if (!signal) {
    out <- out[['reads']]
  }
  return(out)
}



#' Extract selected POD5 signal vectors
#'
#' This is a convenience wrapper around \code{\link{read_pod5}} that
#' requests signal data and returns only the \code{signal} component of the
#' result. Signals can be returned either as raw ADC counts or as
#' calibrated current values.
#'
#' @inheritParams read_pod5
#'
#' @returns list of signal vectors named by read UUID in requested order.
#' @seealso \code{\link{read_pod5}} for coordinate and calibration details.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' read_ids <- pod5R::read_pod5_ids("reads.pod5")
#' signals <- pod5R::extract_pod5_signal("reads.pod5", read_ids[1],
#' start_sample = 101, end_sample = 500)
#' }
extract_pod5_signal <- function(file,
                                read_ids = NULL,
                                calibrated = FALSE,
                                start_sample = 1,
                                end_sample = Inf) {
  #assertions
  if (missing(file)) {
    stop("File is missing. Please provide a valid file argument.", call. = FALSE)
  }
  out <- pod5R::read_pod5(file, read_ids = read_ids, signal = TRUE,
                          calibrated = calibrated, start_sample = start_sample,
                          end_sample = end_sample)
  return(out[['signal']])
}



#' Process POD5 reads in groups
#'
#' Calls an R function for consecutive groups of reads from a POD5 file or an
#' existing POD5 reader. Each group is read independently, passed to \code{FUN},
#' and then discarded, allowing large files to be processed incrementally
#' without retaining all reads in memory at once.
#'
#' @param file [character] A path to a POD5 file or an existing POD5 reader object.
#' Character paths are opened internally and automatically closed when the
#' function exits, including when \code{FUN} raises an error. Existing reader
#' objects are used directly and are not closed by this function.
#' @param FUN is the R function to run on each group. Receives one metadata
#' data frame, or one named list when signal is TRUE. Additional arguments are
#' passed through \code{...}
#' @param part_size [numeric] A positive whole number giving the maximum number of reads
#' processed in each group. The final group may contain fewer reads. Defaults to \code{1000}.
#' @param signal [logical] whether signal data should be read for each group.
#' If \code{FALSE}, only read metadata are obtained. If \code{TRUE}, signal
#' vectors are included in the object passed to \code{FUN}. Defaults to \code{FALSE}.
#' @param calibrated [logical] whether signal values should be returned as
#' calibrated values rather than raw ADC counts. This argument is only
#' relevant when \code{signal = TRUE}. Defaults to \code{FALSE}.
#' @param verbose Logical; whether progress messages should be printed at the
#'   start and end of processing. Defaults to \code{TRUE}.
#' @param ... Additional arguments passed to FUN.
#'
#' @returns Invisibly returns the number of processed reads. Callback results are
#' not retained. Callback errors propagate after closing internally opened files.
#' @export
#'
#' @examples
#' \dontrun{
#' pod5R::process_pod5("reads.pod5", function(reads) {
#' print(sum(reads$num_samples))
#' }, part_size = 1000)
#' }
process_pod5 <- function(file,
                         FUN,
                         part_size = 1000,
                         signal = FALSE,
                         calibrated = FALSE,
                         verbose = TRUE,
                         ...) {
  #assertions
  if (missing(file)) {
    stop("File is missing. Please provide a valid file argument.", call. = FALSE)
  }
  if (missing(FUN)) {
    stop("FUN is missing. Please provide a valid FUN argument.", call. = FALSE)
  }
  assert_condition(is.function(FUN), "FUN must be a function.")
  .check_number(part_size, "Part_size", 1)
  assert_condition(is.logical(verbose) && length(verbose) == 1L && !is.na(verbose),
                   "Verbose must be TRUE or FALSE.")
  assert_condition(is.logical(signal) && length(signal) == 1L && !is.na(signal),
                   "Signal must be TRUE or FALSE.")
  assert_condition(is.logical(calibrated) && length(calibrated) == 1L && !is.na(calibrated),
                   "Calibrated must be TRUE or FALSE.")
  reader <- file
  if (is.character(file)) {
    reader <- pod5R::open_pod5(file)
    on.exit(pod5R::close_pod5(reader), add = TRUE)
  }
  num_reads <- pod5R::read_pod5_info(reader)$num_reads
  if (verbose) {
    cat(paste0('[', as.character(Sys.time()), '] ', 'Processing POD5 reads...', '\n'))
  }
  first_read <- 1
  while (first_read <= num_reads) {
    out <- pod5R::read_pod5(reader, first_read = first_read, num_reads = part_size,
                            signal = signal, calibrated = calibrated)
    FUN(out, ...)
    first_read <- first_read + part_size
  }
  # Done comm
  if (verbose) {
    cat(paste0('[', as.character(Sys.time()), '] ', 'Done!', '\n'))
  }
  return(invisible(num_reads))
}
