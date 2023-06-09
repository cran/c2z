% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/zotero_cran.R
\name{ZoteroCran}
\alias{ZoteroCran}
\title{Wrangle CRAN metadata into Zotero-type format}
\usage{
ZoteroCran(id, meta = list())
}
\arguments{
\item{id}{name of R package}

\item{meta}{A list collecting all metadata used to create , Default: list()}
}
\value{
A Zotero-type matrix (tibble)
}
\description{
Query CRAN by name and fetch metadata
}
\details{
Please see 
\href{https://oeysan.github.io/c2z/}{https://oeysan.github.io/c2z/}
}
\examples{
\donttest{
  # Search cran for package `dplyr`
  example <- ZoteroCran(c("dplyr", "jsonlite", "httr"))

  # Print index using `ZoteroIndex`
  ZoteroIndex(example) |>
    dplyr::select(name) |>
    print(width = 80)
}
}
\seealso{
\code{\link[httr]{RETRY}}
 \code{\link[rvest]{reexports}}
}
