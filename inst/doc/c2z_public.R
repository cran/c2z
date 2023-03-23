## ---- include = FALSE---------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----example------------------------------------------------------------------
# Setup
library(c2z)

# Query public library
example <- Zotero(
  user = FALSE, 
  id = "4986462",
  api = NA,
  library = TRUE,
  index = TRUE
)

# Select only names in index and print
example$index |> 
  dplyr::select(name) |>
  print(width = 80)

