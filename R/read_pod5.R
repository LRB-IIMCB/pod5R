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

#' Title
#'
#' @param x
#' @param name
#' @param minimum
#' @param allow_infinite
#'
#' @returns
#' @export
#'
#' @examples
.check_number <- function(x, name, minimum = 0, allow_infinite = FALSE) {

  assert_condition(
    is.numeric(x) && length(x) == 1L &&
    !is.na(x) && x >= minimum && ((is.finite(x) && x==floor(x) && x<=2^53-1) || (allow_infinite && x==Inf)),
    paste0(name, " must be a whole number >= ", minimum, if (allow_infinite) "or Inf. " else "."))

  return(invisible(TRUE))
}

#' Title
#'
#' @param read_ids
#'
#' @returns
#' @export
#'
#' @examples
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

#' Title
#'
#' @param file
#'
#' @returns
#' @export
#'
#' @examples
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




#' Title
#'
#' @param reader External pointer returned by \code{open_pod5()}
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



#' Title
#'
#' @param file
#'
#' @returns
#' @export
#'
#' @examples
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
