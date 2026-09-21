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

.check_number <- function(x, name, minimum = 0, allow_infinite = FALSE) {

  return(invisible(TRUE))
}

################################################################################
# NATIVE POD5 READING
################################################################################


