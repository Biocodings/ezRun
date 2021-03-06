% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/app-ncpro.R
\name{postProcessResults}
\alias{postProcessResults}
\title{Postprocessing counts produced as results from ncpro}
\usage{
postProcessResults(dataset, psInputFn, psReportDir)
}
\arguments{
\item{psReportDir}{directory where ncpro results are found}

\item{input}{input parameters}
}
\description{
\code{postProcessResults} takes counts for categories all, mature and precursor
and creates a separate result file for each sample. This splitting of count 
results is done in function splitCounts. In the tsv-formatted input metadata the  
path to the read files is replaced by the path to the count result files. This 
replacement is done in function modifyInput.
}
