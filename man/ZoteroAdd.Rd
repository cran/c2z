% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/zotero_add.R
\name{ZoteroAdd}
\alias{ZoteroAdd}
\title{Add items to Zotero list}
\usage{
ZoteroAdd(zotero, items = NULL, doi = NULL, isbn = NULL, silent = FALSE)
}
\arguments{
\item{zotero}{A list with information on the specified Zotero library (e.g.,
id, API key, collections, and items)}

\item{items}{Predefined metadata (as tibble), Default: NULL}

\item{doi}{Use \code{\link{ZoteroDoi}} to fetch DOI metadata, Default: NULL}

\item{isbn}{Use \code{\link{ZoteroIsbn}} to fetch ISBN metadata, Default:
NULL}

\item{silent}{c2z is noisy, tell it to be quiet, Default: FALSE}
}
\value{
Will add data to the Zotero list
}
\description{
Use identifiers or predefined data to add to the Zotero list
}
\details{
Please see
  \href{https://oeysan.github.io/c2z/}{https://oeysan.github.io/c2z/}
}
\examples{
\donttest{
  # Add items from `ZoteroIsbn` to the default Zotero list
  example <- ZoteroAdd(
    Zotero(
      id = "9913421",
      api = "RqlAmlH5l1KPghfCseAq1sQ1"
    ),
    isbn = "978-1529797138"
  )
  # Print index using `ZoteroIndex`
  ZoteroIndex(example$items) |>
    dplyr::select(name) |>
    print(width = 80)
}
}
