% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/simplifyTCGA.R
\name{mirToRanges}
\alias{mirToRanges}
\title{Convert SummarizedExperiment elements with microRNA to
RangedSummarizedExperiment}
\usage{
mirToRanges(obj, keep = FALSE)
}
\arguments{
\item{obj}{A MultiAssayExperiment object obtained from curatedTCGAData}

\item{keep}{If FALSE (default), remove the SummarizedExperiment
objects that have been converted to RangedSummarizedExperiment}
}
\value{
a MultiAssayExperiment where any of the original SummarizedExperiment
  containing gene symbols as rownames have been replaced or supplemented by a
  RangedSummarizedExperiment for miR that could be mapped to GRanges, and
  another SummarizedExperiment for miR that could not be mapped to GRanges.
}
\description{
Convert SummarizedExperiment elements with microRNA to
RangedSummarizedExperiment
}
\examples{
library(curatedTCGAData)

accmae <- curatedTCGAData("ACC", "miRNASeqGene", dry.run = FALSE)

mirToRanges(accmae)
}
\seealso{
symbolsToRanges
}
\author{
L. Waldron
}
