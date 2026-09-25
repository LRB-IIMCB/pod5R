################################################################################
# DORADO READ TO POD5 SIGNAL MAPPING
################################################################################
#' Maps Dorado split-read identifiers back to their original POD5 parents using
#' explicitly provided SAM/BAM tags. Returns the signal for the corresponding
#' basecalled interval in acquisition order.
#'
#' Dorado assigns new UUIDs to split-read children, which are generally
#' not present in the original POD5 file. The parent read is identified by
#' \code{pi}. Using zero-based coordinates, the requested interval starts at
#' \code{sp + ts} and ends immediately before \code{sp + ns}. Its length is
#' therefore \code{ns - ts}, rather than \code{ns}.
#'
#' Under the current Dorado SAM specification, \code{ns} is the end coordinate
#' after any rear trimming and does not necessarily represent the full untrimmed
#' child. Do not add the acquisition-level POD5 \code{start_sample} to these
#' offsets.
#'
#' For unsplit reads, set \code{pi} to \code{NA_character_} or an empty string,
#' and \code{sp} to \code{NA_real_} or zero. In that case, the POD5 identifier is
#' \code{read_id}; the interval starts at \code{ts} and ends immediately before
#' \code{ns}. A \code{pi} value equal to \code{read_id} with \code{sp = 0} is
#' also accepted.
#'
#' It does not parse BAM files, infer missing tags, reverse RNA or
#' reverse-strand signals, or support duplex consensus reads. If present,
#' \code{dx} must contain only -1 or 0; duplex records with value 1 are rejected.
#' Supply one row per read rather than repeated alignment records. A child UUID
#' alone, or a parent identifier without sample offsets, is insufficient to
#' recover a split-read interval.
#'
#' @param file [character] or external pointer. Path to the original POD5 file, or
#' an open reader.
#' @param reads Data frame. Columns \code{read_id}, \code{pi}, \code{sp},
#' \code{ts}, and \code{ns} are required. \code{read_id} contains unique Dorado
#' query-name UUIDs, while \code{pi} contains parent UUIDs or missing values for
#' unsplit reads. Numeric \code{sp}, \code{ts}, and \code{ns} contain the
#' corresponding Dorado SAM/BAM tag values. Missing \code{sp} is permitted only
#' when no parent is specified; \code{ts} and \code{ns} must always be present.
#' @param calibrated [logical] Defaults to FALSE. Return picoamperes instead of ADC counts.
#'
#' @returns A list named by canonical lowercase Dorado read UUIDs, preserving
#' input row order. Raw signal vectors are integer; calibrated vectors are
#' numeric. Empty intervals return empty vectors of the corresponding type.
#'
#' @seealso \code{\link{extract_pod5_signal}}, \code{\link{read_pod5}},
#' and \url{https://software-docs.nanoporetech.com/dorado/latest/basecaller/sam_spec/}
#'
#' @export
#' @examples
#' \dontrun{
#' # reads contains read_id plus pi, sp, ts, and ns tags obtained from Dorado BAM
#' signals <- pod5R::extract_pod5_signal_dorado("reads.pod5", reads)
#' }
extract_pod5_signal_dorado <- function(file,
                                       reads,
                                       calibrated = FALSE) {
  #assertions
  if (missing(file)) {
    stop("File is missing. Please provide a valid file argument.", call. = FALSE)
  }

  if (missing(reads)) {
    stop("Reads is missing. Please provide a valid reads argument.", call. = FALSE)
  }
  assert_condition(is.data.frame(reads), "Reads must be a data frame.")

  required_cols <- c("read_id", "pi", "sp", "ts", "ns")
  missing_cols <- setdiff(required_cols, names(reads))

  assert_condition(length(missing_cols) == 0L,
                   paste0("Required columns missing: ", paste(missing_cols, collapse = ", ")))

  assert_condition(!anyDuplicated(names(reads)), "Reads column names must be unique.")

  assert_condition(is.logical(calibrated) && length(calibrated) == 1L && !is.na(calibrated),
                   "Calibrated must be TRUE or FALSE.")

  if ("dx" %in% names(reads)) {
    assert_condition(is.numeric(reads$dx) && !anyNA(reads$dx) &&
                       all(reads$dx %in% c(-1, 0)),
                     "Dx must contain -1 or 0. Duplex consensus reads are not supported.")
  }

  read_ids <- .check_ids(reads$read_id)
  assert_condition(is.character(reads$pi), "Pi must be a character vector.")

  has_parent <- !is.na(reads$pi) & nzchar(reads$pi)
  parent_ids <- read_ids
  parent_ids[has_parent] <- tolower(reads$pi[has_parent])
  .check_ids(unique(parent_ids))

  # Validate coordinates before arithmetic to avoid overflow or silent clipping
  split_start <- reads$sp
  assert_condition(is.numeric(split_start), "Sp must be numeric.")

  split_start[!has_parent & is.na(split_start)] <- 0
  coordinates <- list(sp = split_start, ts = reads$ts, ns = reads$ns)

  for (name in names(coordinates)) {
    value <- coordinates[[name]]
    assert_condition(is.numeric(value) && !anyNA(value) && all(is.finite(value)) &&
                       all(value >= 0 & value == floor(value) & value <= 2^53 - 1),
                     paste0(name, " must contain non-negative whole numbers without missing values."))
  }
  assert_condition(all(split_start[!has_parent] == 0),
                   "Nonzero sp requires a parent UUID in pi.")
  assert_condition(all(reads$ts <= reads$ns), "Ts must be <= ns for every read.")
  assert_condition(all(reads$ns <= (2^53 - 1) - split_start),
                   "Sp + ns exceeds exact R numeric precision.")

  # Numeric conversion avoids overflow when BAM tags were imported as R integers
  start <- as.numeric(split_start) + as.numeric(reads$ts)
  end <- as.numeric(split_start) + as.numeric(reads$ns)
  reader <- file
  if (is.character(file)) {
    reader <- pod5R::open_pod5(file)
    on.exit(pod5R::close_pod5(reader), add = TRUE)
  }
  parents <- pod5R::read_pod5(reader, read_ids = unique(parent_ids))
  parent_rows <- match(parent_ids, parents$read_id)

  assert_condition(all(end <= parents$num_samples[parent_rows]),
                   "Dorado signal interval exceeds the POD5 parent length. Check pi, sp, ts, and ns.")
  out <- vector("list", length(read_ids))
  names(out) <- read_ids

  for (i in seq_along(read_ids)) {
    # Native intervals are zero-based and half-open, including empty intervals
    selected <- cpp_reads_pod5(reader, parent_ids[i], 0, Inf,
                               TRUE, calibrated, start[i], end[i])
    out[[i]] <- selected[['signal']][[1]]
  }
  return(out)
}
