% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/reports.R
\name{ezImageFileLink}
\alias{ezImageFileLink}
\title{Gets an image link as html}
\usage{
ezImageFileLink(plotCmd, file = NULL, name = "imagePlot",
  plotType = "plot", mouseOverText = "my mouse over", addPdfLink = TRUE,
  width = 480, height = 480, ppi = 72, envir = parent.frame())
}
\arguments{
\item{plotCmd}{an expression of plot commands.}

\item{file}{a character specifying the name of the image with a .png suffix.}

\item{name}{a character specifying the name of the image together with \code{plotType}, if \code{file} is null.}

\item{plotType}{a character specifying the name of the image together with \code{name}, if \code{file} is null.}

\item{mouseOverText}{a character specifying the text being displayed when mousing over the image.}

\item{addPdfLink}{a logical indicating whether to add a link on the image to a pdf version of itself.}

\item{width}{an integer specifying the width of each plot to create an image from.}

\item{height}{an integer specifying the height of each plot to create an image from.}

\item{ppi}{an integer specifying points per inch.}

\item{envir}{the environment to evaluate \code{plotCmd} in.}
}
\value{
Returns a character specifying a link to an image in html.
}
\description{
Gets an image link as html. Also plots and creates the image.
}
\examples{
x = 1:10
plotCmd = expression({
  plot(x)
  text(2,1, "my Text")
})
ezImageFileLink(plotCmd)
}
\author{
Rehrauer, Hubert

Schmid, Peter
}
