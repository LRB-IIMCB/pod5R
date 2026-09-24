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
    asseet_condition(is.character(read_ids) && !anyNA(read_ids),
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

  assert_condition(file.exists(file) && !dir.exists(file),
                   "File does not exist or is a directory")

  assert_condition(is.character(file) && length(file) ==1L && !is.na(file) && nzchar(file),
                   "File must be a single, non-empty path")


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









