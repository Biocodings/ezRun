% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/gage.r
\name{runGageAnalysis}
\alias{runGageAnalysis}
\alias{gageAnalysis}
\alias{getExpressionGage}
\alias{writeGageResults}
\alias{gageHeatmap}
\alias{gagePathview}
\title{Runs the gage analysis}
\usage{
runGageAnalysis(result, param = NULL, output = NULL, rawData = NULL,
  gene.pValue = param[["gageGeneThreshold"]])

gageAnalysis(result, rawData = NULL, param = NULL, geneSets = NULL)

getExpressionGage(gageResults, result = NULL, rawData = NULL,
  param = NULL, signal = NULL)

writeGageResults(gageResults, param = NULL, output = NULL, prefix = NULL,
  signal = c("greater", "less", "both"))

gageHeatmap(x, param = NULL, output = NULL, gene.pValue = NULL,
  signal = NULL, fileName = NULL, prefix = "gage-heatmap")

gagePathview(x, param = NULL, output = NULL, signal = NULL,
  kegg.id = NULL, gene.pValue = NULL, result = result, anno)
}
\arguments{
\item{result}{a list of results obtained from \code{twoGroupCountComparison()}.}

\item{param}{a list of parameters, passed to other functions as well:
\itemize{
  \item{featureLevel}{ a character representing the feature level. Must be "gene", otherwise the function gets stopped.}
  \item{pathView}{ a logical indicating whether to do a path view.}
}}

\item{output}{a list, file path or an object of the class EzDataset containing the output information.}

\item{rawData}{a list of raw data obtained from \code{loadCountDataset()}.}

\item{gene.pValue}{a numeric specifying the p-value threshold.}
}
\value{
Returns the gage results.
}
\description{
Runs the gage analysis.
}
\section{Functions}{
\itemize{
\item \code{gageAnalysis}: Runs the gage command, filters the results and returns them.

\item \code{getExpressionGage}: Gets the expression from the gage results.

\item \code{writeGageResults}: Writes the gage results into separate tables.

\item \code{gageHeatmap}: Plots heatmaps of the significant gage results.

\item \code{gagePathview}: Performs the pathview for each gene set and signal.
}}

\seealso{
\code{\link{getGeneSets}}

\code{\link[gage]{gage}}

\code{\link{gageSigGenes}}

\code{\link{getSpeciesName}}

\code{\link{getKeggId}}

\code{\link[pathview]{pathview}}
}
\author{
Rehrauer, Hubert

Schmid, Peter
}
