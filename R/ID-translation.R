## function to figure out exact endpoint based on TCGA barcode
.barcode_files <- function(startPoint = "cases", submitter_id = TRUE) {
    keywords <- c("cases", "samples", "portions", "analytes", "aliquots")
    last <- match.arg(startPoint, keywords)
    indx <- seq_len(which(keywords == last))
    sub_id <- if (submitter_id) "submitter_id" else NULL
    paste(c(keywords[indx], sub_id), collapse = ".")
}

.subword_id <- function(keyword) {
    ret <- paste0(keyword, "_ids")
    setNames(paste0("submitter_", ret), ret)
}

.barcode_cases <- function(bcodeType = "case") {
    if (identical(bcodeType, "case"))
        setNames("submitter_id", "case_id")
    else
        .subword_id(bcodeType)
}

.findBarcodeLimit <- function(barcode) {
    filler <- .uniqueDelim(barcode)
    splitCodes <- strsplit(barcode, filler)
    maxIndx <- unique(lengths(splitCodes))
    if (!S4Vectors::isSingleInteger(maxIndx))
        stop("Inconsistent barcode lengths found")
    if (maxIndx < 3L)
        stop("Minimum barcode fields required: 'project-TSS-participant'")
    key <- c(rep("case", 3L), "sample", "analyte", "aliquot", "aliquot")[maxIndx]
    if (identical(key, "analyte")) {
        analyte_chars <- unique(
            vapply(splitCodes, function(x) nchar(x[[maxIndx]]), integer(1L))
        )
        if (!S4Vectors::isSingleInteger(analyte_chars))
            stop("Inconsistent '", key, "' barcodes")
        if (analyte_chars < 3)
            key <- "portion"
    } else if (identical(key, "aliquot")) {
        if (identical(maxIndx, 6L)) {
            ali_chars <- vapply(splitCodes, function(x)
                nchar(x[c(maxIndx-1L, maxIndx)]), integer(2L))
            if (identical(ali_chars, c(2L, 3L)))
                key <- "slide"
        }
    }
    key
}

.buildIDframe <- function(info, id_list) {
    barcodes_per_file <- lengths(id_list)
    # And build the data.frame
    data.frame(
        id = rep(ids(info), barcodes_per_file),
        barcode = if (!length(ids(info))) character(0L) else unlist(id_list),
        row.names = NULL,
        stringsAsFactors = FALSE
    )
}

#' @name ID-translation
#'
#' @title Translate study identifiers from barcode to UUID and vice versa
#'
#' @description These functions allow the user to enter a character vector of
#' identifiers and use the GDC API to translate from TCGA barcodes to
#' Universally Unique Identifiers (UUID) and vice versa. These relationships
#' are not one-to-one. Therefore, a \code{data.frame} is returned for all
#' inputs. The UUID to TCGA barcode translation only applies to file and case
#' UUIDs. Two-way UUID translation is available from 'file_id' to 'case_id'
#' and vice versa. Please double check any results before using these
#' features for analysis. Case / submitter identifiers are translated by
#' default, see the \code{from_type} argument for details. All identifiers are
#' converted to lower case.
#'
#' @details
#' Based on the file UUID supplied, the appropriate entity_id (TCGA barcode) is
#' returned. In previous versions of the package, the 'end_point' parameter
#' would require the user to specify what type of barcode needed. This is no
#' longer supported as `entity_id` returns the appropriate one.
#'
#' @param id_vector A \code{character} vector of UUIDs corresponding to
#' either files or cases (default assumes case_ids)
#' @param from_type Either \code{case_id} or \code{file_id} indicating the type of
#' \code{id_vector} entered (default "case_id")
#' @param legacy (logical default FALSE) whether to search the legacy archives
#'
#' @return A \code{data.frame} of TCGA barcode identifiers and UUIDs
#'
#' @examples
#' ## Translate UUIDs >> TCGA Barcode
#'
#' uuids <- c("0001801b-54b0-4551-8d7a-d66fb59429bf",
#' "002c67f2-ff52-4246-9d65-a3f69df6789e",
#' "003143c8-bbbf-46b9-a96f-f58530f4bb82")
#'
#' UUIDtoBarcode(uuids, from_type = "file_id")
#'
#' UUIDtoBarcode("ae55b2d3-62a1-419e-9f9a-5ddfac356db4", from_type = "case_id")
#'
#' @author Sean Davis, M. Ramos
#'
#' @export UUIDtoBarcode
UUIDtoBarcode <-  function(id_vector, from_type = c("case_id", "file_id"),
    legacy = FALSE) {
    from_type <- match.arg(from_type)
    if (identical(from_type, "case_id")) {
        targetElement <- APIendpoint <- "submitter_id"
    } else if (identical(from_type, "file_id")) {
        APIendpoint <- "associated_entities.entity_submitter_id"
        targetElement <- "associated_entities"
    }
    selector <- switch(from_type, case_id = identity,
        function(x) select(x = x, fields = APIendpoint))

    funcRes <- switch(from_type,
        file_id = files(legacy = legacy),
        case_id = cases(legacy = legacy))
    info <- results_all(
        selector(
            filter(funcRes, as.formula(
                paste("~ ", from_type, "%in% id_vector")
            ))
        )
    )

    if (identical(from_type, "case_id"))
        rframe <- data.frame(info[[from_type]], info[[targetElement]],
            stringsAsFactors = FALSE)
    else
        rframe <- data.frame(names(info[[targetElement]]),
            unlist(info[[targetElement]], use.names = FALSE),
            stringsAsFactors = FALSE)
    names(rframe) <- c(from_type, APIendpoint)
    rframe[na.omit(match(id_vector, rframe[[from_type]])), , drop = FALSE]
}

#' @rdname ID-translation
#'
#' @param to_type The desired UUID type to obtain, can either be "case_id" or
#' "file_id"
#'
#' @examples
#' ## Translate file UUIDs >> case UUIDs
#'
#' uuids <- c("0001801b-54b0-4551-8d7a-d66fb59429bf",
#' "002c67f2-ff52-4246-9d65-a3f69df6789e",
#' "003143c8-bbbf-46b9-a96f-f58530f4bb82")
#'
#' UUIDtoUUID(uuids)
#'
#' @export UUIDtoUUID
UUIDtoUUID <- function(id_vector, to_type = c("case_id", "file_id"),
    legacy = FALSE) {
    id_vector <- tolower(id_vector)
    type_ops <- c("case_id", "file_id")
    to_type <- match.arg(to_type)
    from_type <- type_ops[!type_ops %in% to_type]
    if (!length(from_type))
        stop("Provide a valid UUID type")

    endpoint <- switch(to_type,
        case_id = "cases.case_id",
        file_id = "files.file_id")
    apifun <- switch(to_type,
        file_id = cases(legacy = legacy),
        case_id = files(legacy = legacy))
    info <- results_all(
        select(filter(apifun, as.formula(
            paste("~ ", from_type, "%in% id_vector")
            )),
        endpoint)
    )
    targetElement <- gsub("(\\w+).*", "\\1", endpoint)
    id_list <- lapply(info[[targetElement]], function(x) {x[[1]]})

    rframe <- .buildIDframe(info, id_list)
    names(rframe) <- c(from_type, endpoint)
    rframe
}

#' @rdname ID-translation
#'
#' @param barcodes A \code{character} vector of TCGA barcodes
#'
#' @examples
#' ## Translate TCGA Barcode >> UUIDs
#'
#' fullBarcodes <- c("TCGA-B0-5117-11A-01D-1421-08",
#' "TCGA-B0-5094-11A-01D-1421-08",
#' "TCGA-E9-A295-10A-01D-A16D-09")
#'
#' sample_ids <- TCGAbarcode(fullBarcodes, sample = TRUE)
#'
#' barcodeToUUID(sample_ids)
#'
#' participant_ids <- c("TCGA-CK-4948", "TCGA-D1-A17N",
#' "TCGA-4V-A9QX", "TCGA-4V-A9QM")
#'
#' barcodeToUUID(participant_ids)
#'
#' @export barcodeToUUID
barcodeToUUID <-
    function(barcodes, legacy = FALSE)
{
    .checkBarcodes(barcodes)
    bend <- .findBarcodeLimit(barcodes)
    endtargets <- .barcode_cases(bend)
    expander <- gsub("cases\\.", "", .barcode_files(bend, FALSE))

    pand <- switch(expander, cases = identity,
        function(x) expand(x = x, expand = expander))
    info <- results_all(
        pand(x = filter(cases(), as.formula(
            paste("~ ", endtargets, "%in% barcodes")
        )))
    )
    if (identical(expander, "cases")) {
        rframe <- as.data.frame(info[c(endtargets, names(endtargets))],
            stringsAsFactors = FALSE)
    } else {
        idnames <- lapply(ids(info), function(ident) {
            info[["samples"]][[ident]]
        })
        if (!identical(expander, "samples")) {
            exFUN <- switch(expander,
                samples.portions =
                    function(x, i) x[["portions"]],
                samples.portions.analytes =
                    function(x, i) unlist(lapply(
                        x[["portions"]], `[[`, "analytes"), recursive = FALSE),
                samples.portions.analytes.aliquots =
                    function(x, i) unlist(lapply(
                        unlist(
                            lapply(x[["portions"]], `[[`, "analytes"),
                            recursive = FALSE), `[[`, "aliquots"),
                        recursive = FALSE)
                )
            idnames <- unlist(lapply(seq_along(idnames), function(i)
                exFUN(x = idnames[[i]], i = i)
            ), recursive = FALSE)
            idnames <- Filter(function(g) length(g) >= 2L, idnames)
        }
        rescols <- lapply(idnames, `[`,
            c("submitter_id", gsub("s$", "", names(endtargets))))
        rframe <- do.call(rbind, c(rescols, stringsAsFactors = FALSE))
        names(rframe) <- c(endtargets, names(endtargets))
    }
    rframe[na.omit(match(barcodes, rframe[[endtargets]])), , drop = FALSE]
}

#' @rdname ID-translation
#'
#' @param filenames A \code{character} vector of filenames obtained from
#' the GenomicDataCommons
#'
#' @examples
#' library(GenomicDataCommons)
#'
#' fquery <- files() %>%
#'     filter(~ cases.project.project_id == "TCGA-COAD" &
#'         data_category == "Copy Number Variation" &
#'         data_type == "Copy Number Segment")
#'
#' fnames <- results(fquery)$file_name[1:6]
#'
#' filenameToBarcode(fnames)
#'
#' @export filenameToBarcode
filenameToBarcode <- function(filenames, legacy = FALSE) {
    filesres <- files(legacy = legacy)
    info <- results_all(
        select(filter(filesres, ~ file_name %in% filenames),
            "cases.samples.portions.analytes.aliquots.submitter_id")
    )
    id_list <- lapply(info[["cases"]], function(a) {
        a[[1L]][[1L]][[1L]]
    })
    # so we can later expand to a data.frame of the right size
    barcodes_per_file <- lengths(id_list)
    # And build the data.frame
    data.frame(file_name = rep(filenames, barcodes_per_file),
        file_id = rep(ids(info), barcodes_per_file),
        aliquots.submitter_id = unlist(id_list), row.names = NULL,
        stringsAsFactors = FALSE)
}
