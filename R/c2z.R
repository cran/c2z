################################################################################
#####################################Import#####################################
################################################################################

#' @importFrom dplyr arrange bind_rows case_when coalesce distinct filter
#' group_by mutate na_if one_of pull row_number select slice_head transmute
#' ungroup full_join join_by
#' @importFrom httr GET RETRY add_headers content http_error
#' @importFrom jsonlite fromJSON toJSON
#' @importFrom purrr map pmap pmap_chr
#' @importFrom rlang syms
#' @importFrom rvest html_attr html_attrs html_children html_name html_nodes
#' html_text read_html
#' @importFrom stats setNames
#' @importFrom tibble add_column as_tibble remove_rownames tibble is_tibble
#' @importFrom utils adist flush.console head tail write.csv
NULL
#> NULL

################################################################################
#################################Internal Data##################################
################################################################################

#' @title List with empty cristin-items
#' @description Each tibble in the list represents a cristin-item
#' @format A list with 70 tibbles with zero rows and various columns
#' @details Used to create Zotero-items from list of metadata
#' @rdname cristin.types
#' @keywords internal
"cristin.types"
#> NULL

#' @title List with empty zotero-items
#' @description Each tibble in the list represents a zotero-item
#' @format A list with 36 tibbles with zero rows and various columns
#' @details Used to create Zotero-items from list of metadata
#' @rdname zotero.types
#' @keywords internal
"zotero.types"
#> NULL

################################################################################
###############################Internal Functions###############################
################################################################################

#' @title FixCreators
#' @keywords internal
#' @noRd
ErrorCode <- \(code, reference = NULL) {

  error.codes <- c(
    "Invalid type/field (unparseable JSON)" = 400,
    "The target library is locked" = 409,
    "Precondition Failed (e.g.,
    the provided Zotero-Write-Token has already been submitted)" = 412,
    "Request Entity Too Large" = 413,
    "Forbidden (check API key)" = 403,
    "Resource not found" = 404
  )

  # Define creator type according to match in creator types
  error.code <- sprintf(
    "Error %s: %s.",
    code,
    names(error.codes[error.codes %in% code])
  )

  # Set as contributor if not found
  if (!length(error.code)) error.code <- "Unknown error. Sorry."

  # Clean code
  error.code <- Trim(gsub("\r?\n|\r", " ", error.code))

  # Add reference if exists
  if (!is.null(reference)) error.code <- sprintf(
    "%s See: %s.", error.code, reference
  )

  return (error.code)

}

#' @title FixCreators
#' @keywords internal
#' @noRd
FixCreators <- \(data = NULL) {


  if (all(is.na(GoFish(data)))) {
    return (NULL)
  }

  data <- AddMissing(
    data, c("firstName", "lastName", "name"), na.type = ""
  ) |>
    dplyr::mutate_if(is.character, list(~dplyr::na_if(., ""))) |>
    dplyr::mutate(
      lastName = dplyr::case_when(
        !is.na(name) ~ NA_character_,
        TRUE ~ lastName
      ),
      firstName = dplyr::case_when(
        !is.na(name) ~ NA_character_,
        TRUE ~ firstName
      ),
      name = dplyr::case_when(
        is.na(firstName) & !is.na(lastName) ~ lastName,
        !is.na(lastName) & is.na(lastName) ~ firstName,
        is.na(firstName) & is.na(lastName) ~ name,
        TRUE ~ NA_character_
      )
    ) |>
    dplyr::select(dplyr::where(~sum(!is.na(.x)) > 0)) |>
    dplyr::filter(!dplyr::if_all(dplyr::everything(), is.na))

  return (data)

}

#' @title ZoteroCreator
#' @keywords internal
#' @noRd
ZoteroCreator <- \(data = NULL) {

  # Visible bindings
  creators <- NULL

  # Run if not empty
  if (all(is.na(GoFish(data)))) {
    return (NULL)
  }

  # Check that first element of data is a list
  if (!is.list(data[[1]])) data <- list(data)

  # Define creator types
  types <- c(
    author = "author",
    editor = "editor",
    translator = "translator",
    aut = "author",
    edt = "editor",
    red = "editor",
    trl = "translator",
    editorialboard = "editor",
    programmer = "programmer",
    curator = "author",
    serieseditor = "seriesEditor"
  )

  # Create zotero-type matrix
  creators <- dplyr::bind_rows(
    lapply(data, \(x) {

      # Remove commas and dots from names
      name <- Trim(gsub("\\.|\\,", " ", x$name))

      # Set as Cher if only one name is given
      if (length(name) == 1) {
        name <- c(name = name)
      } else {
        name <- c(lastName = name[1], firstName = name[2])
      }

      # Define creator type according to match in creator types
      type <- as.character(types[names(types) %in% tolower(x$type)])
      # Set as contributor if not found
      if (!length(type)) type <- "contributor"

      # Combine creatorType and names
      lapply(type, \(type) c(creatorType = type, name))

    })
  )

  return (creators)

}

#' @title ZoteroToJson
#' @keywords internal
#' @noRd
ZoteroToJson <- \(data = NULL) {

  # Run if not empty
  if (all(is.na(GoFish(data)))) {
    return (NULL)
  }

  # Convert data to JSON
  data <- jsonlite::toJSON(data)
  # Convert character FALSE to logical false
  data <- gsub("\"FALSE\"", "false", data)
  # Remove empty elements
  data <- gsub(",\"\\w+?\":\\{\\}", "", data)

  return (data)

}

#' @title ZoteroFormat
#' @keywords internal
#' @noRd
ZoteroFormat <- \(data = NULL,
                  format = NULL,
                  prefix = NULL) {

  # Run if not empty
  if (all(is.na(GoFish(data)))) {
    return (NULL)
  }

  # Visible bindings
  zotero.types <- zotero.types
  creators <- NULL

  multiline.items <- c("tags",
                       "extra",
                       "abstractNote",
                       "note",
                       "creators",
                       "relations")
  double.items <- c("version", "mtime")
  list.items <- c("collections", "relations", "tags")

  # Check if metadata and not in a data frame
  if (!is.data.frame(data) &
      (any(format == "json", is.null(format)))) {

    # Check that first element of data is a list
    if (is.list(data[[1]])) data <-  unlist(data, recursive = FALSE)

    # Check all element in the meta list
    data.list <- lapply(seq_along(data), \(i) {

      # Define data
      x <- data[[i]]
      names <- names(data[i])

      # Make certain fields not in multiline are strings
      if (!names %in% multiline.items) x <- ToString(x)

      # Add to list if element is a data frame
      ## Make certain list.items is in a list
      if (is.data.frame(x) | names %in% list.items) {
        if (!all(is.na(x))) x <- list(x)
        # Make certain double.items are double
      } else if (names %in% double.items) {
        x <- as.double(x)
        # Else make certain remaining items are character
      } else {
        x <- as.character(x)
      }

      return (x)

    })
    # Name elements
    names(data.list) <- names(data)
    # Keep number of columns fixed for simple conversion to tibble/JSON
    ## Replace empty elements with NA
    data.list[lengths(data.list) == 0] <- NA
    # Set key and initial version is missing
    if (!"key" %in% names(data.list)) {
      data.list <- c(key = ZoteroKey(), version = 0, data.list)
    }
    # Remove elements not in category if item
    if (!"parentCollection" %in% names(data.list)) {
      data.list[!names(data.list) %in%
                  c(names(zotero.types[[data.list$itemType]]),
                    "key", "version")] <- NULL
    }

    # Format as tibble and remove empty elements
    data <- tibble::as_tibble(data.list[lengths(data.list) != 0])

  }

  # Set data as tibble if data frame
  if (is.data.frame(data)) {
    data <- tibble::as_tibble(data) |>
      # Replace empty string with NA
      dplyr::mutate_if(is.character, list(~dplyr::na_if(., ""))) |>
      dplyr::mutate(
        # Add prefix if defined
        prefix = GoFish(prefix),
        # Fix creators
        creators = GoFish(purrr::map(creators, FixCreators))
      ) |>
      # Remove empty columns
      dplyr::select(dplyr::where(~sum(!is.na(.x)) > 0))
    # Else convert to string
  } else {
    data <- ToString(data, "\n")
  }

  return (data)

}

#' @title ZoteroUrl
#' @keywords internal
#' @noRd
ZoteroUrl <- \(url,
               collection.key = NULL,
               use.collection = TRUE,
               item.key = NULL,
               use.item = FALSE,
               api = NULL,
               append.collections = FALSE,
               append.items = FALSE,
               append.file = FALSE,
               append.top = FALSE) {

  # Set ute.item to FALSE if item.key is NULL
  if(is.null(item.key)) use.item <- FALSE
  # Default is not key
  use.key <- FALSE

  # Add item.key if defined and use.item set to TRUE
  if (!is.null(item.key) & use.item) {
    url <- paste0(url,"items/",item.key,"/")
    use.key <- TRUE
    # Else add collection key if defined
  } else if (!is.null(collection.key) & use.collection) {
    url <- paste0(url, "collections/", collection.key, "/")
    use.key <- TRUE
    # Else set append.items to TRUE if no keys
  } else if (!append.collections) {
    append.items <- TRUE
  }

  #  Add top if append.top set to TRUE
  if (use.key & append.top) {
    url <- paste0(url,"top")
  }

  #  Add file if append.file set to TRUE
  if (use.key & append.file) {
    url <- paste0(url,"file")
  }

  # If not using specific item or top level
  if (!use.item) {
    #  Add items if append.items set to TRUE
    if (append.items) {
      url <- paste0(url,"items")
      # Else add collections if append.collection set to TRUE
    } else if (append.collections) {
      url <- paste0(url,"collections")
    }
  }

  # Add API if defined
  if (!is.null(api)) {
    if (grepl("Sys.getenv", api, perl = TRUE)) api <- eval(parse(text=api))
    url <- sprintf("%s?key=%s", url, api)
  }

  return (url)

}

#' @title Pad
#' @keywords internal
#' @noRd
Pad <- \(string, sep = "-", max.width = 80) {

  # Find remaining character
  remaining.char <- max(0, max.width - nchar(string)) / 2
  head.char <- paste0(rep(sep, floor(remaining.char)), collapse = "")
  tail.char <- paste0(rep(sep, ceiling(remaining.char)), collapse = "")

  # Add pad
  padded <- paste0(head.char, string, tail.char)

  return (padded)

}

#' @title Eta
#' @keywords internal
#' @noRd
Eta <- \(start.time,
         i ,
         total,
         message = NULL,
         flush = TRUE,
         sep = "-",
         max.width = 80) {

  # Estimate time of arrival
  eta <- Sys.time() + ( (total - i) * ((Sys.time() - start.time) / i) )

  # Format ETA message
  eta.message <- sprintf(
    "Progress: %.02f%% (%s/%s). ETA: %s",
    (i * 100) / total,
    i,
    total,
    format(eta,"%d.%m.%Y - %H:%M:%S")
  )
  # Arrived message
  if (i == total) {

    final <- sprintf(
      "Process: %.02f%% (%s/%s). Elapsed time: %s",
      (i * 100) / total,
      i,
      total,
      format(
        as.POSIXct(
          as.numeric(difftime(Sys.time(), start.time, units = "secs")),
          origin = "1970-01-01", tz = "UTC"
        ),
        '%H:%M:%S'
      )
    )

    arrived <- sprintf(
      "Task completed: %s", format(eta, "%d.%m.%Y - %H:%M:%S")
    )
    eta.message <- c(final, arrived)
    # Else results to ETA message if requested.
  } else if (length(message)) {
    eta.message <- sprintf("%s. %s", message, eta.message)
  }

  # Pad ETA message to avoid spilover-effect
  eta.message[1] <- Pad(eta.message[1], sep, max.width)

  return (eta.message)

}

#' @title SplitData
#' @keywords internal
#' @noRd
SplitData <- \(data, limit) {

  # Split metadata into acceptable chunks (k > 50)
  if (nrow(data)>limit) {
    data <- split(
      data,
      rep(
        seq_len(ceiling(nrow(data)/limit)),
        each=limit,
        length.out=nrow(data)
      )
    )
  } else {
    data <- list(data)
  }

  return (data)

}

#' @title ComputerFriendly
#' @keywords internal
#' @noRd
ComputerFriendly <- \(x, sep = "_", remove.after = FALSE) {

  # Remove after common line identifers
  if (remove.after) {
    character.vector <- c(".",",",":",";","-","--",
                          "\u2013","\u2014","\r","\n","/","?")
    remove.after <- paste0("\\", character.vector, collapse=".*|")
    x <- gsub(remove.after, "", x)
  }

  # Try to replace accents and foreign letters
  s <- iconv(x, "utf8", "ASCII//TRANSLIT")
  # Ignore cyrillic and similiar languages
  if (any(grepl("\\?\\?\\?", s))) {
    s <- s
  } else {
    # Replace foreign and whitespace with sep
    s <- gsub("\\W+", sep, s, perl = TRUE)
    # Trim and set to lower or set as x if only ??? (e.g., russian)
    s <- Trim(tolower(s))
  }

  return (s)

}

#' @title JsonToTibble
#' @keywords internal
#' @noRd
JsonToTibble <- \(data) {

  # Parse url
  data.parsed <-ParseUrl(data, "text")

  # Return NULL if data.pased is empty
  if (is.null(data.parsed)) {
    return(NULL)
  }

  # Parse raw data as JSON
  data <- jsonlite::fromJSON(data.parsed)

  # Convert nested elements in list as data.frame
  if (!is.data.frame(data)) {
    data <- lapply(data, \(x) {
      if (is.list(x) | length(x)>1) x <- list(x)
      return (x)
    })
  }
  # Convert and return as tibble
  return(tibble::as_tibble(data))

}

#' @title GoFish
#' @keywords internal
#' @noRd
GoFish <- \(data, type = NA) {

  data <- suppressWarnings(
    tryCatch(data, silent = TRUE, error=function(err) logical(0))
  )
  if (!length(data) | all(is.na(data))) data <- type

  return (data)

}

#' @title ToString
#' @keywords internal
#' @noRd
ToString <- \(x, sep = ", ") {


  x <- paste(unlist(GoFish(x,NULL)), collapse = sep)

  if (x == "") x <- NULL

  return (x)

}

#' @title AddMissing
#' @keywords internal
#' @noRd
AddMissing <- \(data,
                missing.names,
                na.type = NA_real_,
                location = 1) {

  missing <- stats::setNames(
    rep(na.type, length(missing.names)), missing.names
  )
  data <- tibble::add_column(data, !!!missing[
    setdiff(names(missing), names(data))], .before = location)

  return (data)

}

#' @title Trim
#' @keywords internal
#' @noRd
Trim <- \(x, multi = TRUE) {

  if (multi) {
    x <- gsub("(?<=[\\s])\\s*|^\\s+|\\s+$", "", x, perl = TRUE)
  } else {
    x <- gsub("^\\s+|\\s+$", "", x)
  }

  return(x)

}

#' @title TrimSplit
#' @keywords internal
#' @noRd
TrimSplit <- \(x,
               sep = ",",
               fixed = FALSE,
               perl = FALSE,
               useBytes = FALSE) {

  x <- Trim(unlist(strsplit(x, sep, fixed, perl, useBytes)))

  return(x)

}

#' @title Pluralis
#' @keywords internal
#' @noRd
Pluralis <- \(data, singular, plural, prefix = TRUE) {

  word <- if (data==1) singular else plural

  if (prefix) word <- paste(data, word)

  return (word)

}

#' @title AddAppend
#' @keywords internal
#' @noRd
AddAppend <- \(data = NULL, old.data = NULL, sep = NULL) {

  data <- GoFish(data, NULL)

  old.data <- GoFish(old.data, NULL)

  if (!is.null(old.data) & !is.null(data)) {
    data <- if (is.data.frame(data)) {
      dplyr::bind_rows(old.data, data) |>
        dplyr::distinct()
    } else if (is.double(data) | (is.list(data))) {
      c(old.data, data)
    } else if(is.character(data)) {
      paste(old.data, data, sep = sep)
    }
  }

  return (data)

}

#' @title LogCat
#' @keywords internal
#' @noRd
LogCat <- \(message = NULL,
            error = FALSE,
            fatal = FALSE,
            flush = FALSE,
            trim = TRUE,
            width = 80,
            log = list(),
            append.log = TRUE,
            silent = FALSE,
            debug = FALSE) {

  # Trim message if trim is set to TRUE
  if (trim) message <- Trim(gsub("\r?\n|\r", " ", message))

  # Check for errors if error is set to TRUE
  if (debug & error) {
    fatal <- TRUE
    message <- paste(message, "is not working")
  } else if (debug) {
    message <- paste(message, "is working")
  }

  # if fatal stop function
  if (fatal) {
    stop(message, call. = FALSE)
    # Print message if silent is set to FALSE
  }

  # Print text if silent is set to FALSE
  if (!silent) {
    # flush console after each message if flush and trim is set to TRUE
    if (flush & trim) {
      cat("\r" , message[[1]], sep="")
      utils::flush.console()
      # if arrived is in message insert new line
      if (length(message)>1) cat("\n")
      # else trim message and print if trim is set to TRUE
    } else if (trim) {
      cat(message,"\n")
      # else print message as is
    } else {
      print(message, width = width)
      cat("\n")
    }
  }

  # Append to log if append.log set to TRUE else static
  log <- if (append.log) append(log, message) else message

  return (log)

}

#' @title SaveData
#' @keywords internal
#' @noRd
SaveData <- \(data,
              save.name,
              extension,
              save.path = NULL,
              append = FALSE) {

  # Define path and file
  file <- sprintf("%s.%s", save.name, extension)
  if (!is.null(save.path)) {
    # Create folder if it does not exist
    dir.create(file.path(save.path), showWarnings = FALSE)
    file <- file.path(save.path, file)
  }

  # save as csv
  if (extension == "csv") {
    utils::write.csv(data, file, row.names = FALSE, fileEncoding = "UTF-8")
    # Save as text file
  } else {
    write(data, file = file, append = append)
  }

  return (file)

}

#' @title CleanText
#' @keywords internal
#' @noRd
CleanText <- \(x, multiline = FALSE) {

  # Trim original vector
  x <- Trim(x)

  # List of characters to remove
  character.vector <- c(".",",",":",";","-","--","\u2013","\u2014",
                        "[","]","(",")","{","}","=","&","/")
  remove.characters <- paste0("\\", character.vector, collapse="|")

  # Remove first character if unwanted
  first.character <- gsub(remove.characters, "", substring(x, 1, 1))
  # Put Humpty togheter again
  if (max(0,nchar(Trim(gsub("(\\s).*", "\\1", x)))) == 1) {
    x <- paste(first.character, Trim(substring(x, 2)))
  } else {
    x <- paste0(first.character, Trim(substring(x, 2)))
  }

  # Remove last character if unwanted
  last.character <- gsub(remove.characters, "", substr(x, nchar(x), nchar(x)))
  # Put Humpty togheter again
  x <- paste0(Trim(substr(x, 1, nchar(x)-1)), last.character)

  # Remove any #. (e.g., 1. Title)
  x <- Trim(gsub("^\\s*\\d+\\s*\\.", "", x))

  # Remove \r\n if multiline is set to FALSE
  if (!multiline) x <- Trim(gsub("\r?\n|\r", " ", x))

  # Remove HTML/XML tags
  x <- Trim(gsub("<.*?>|\ufffd|&lt;|&gt", "", x))

  # Remove NA
  x <- x[! x %in% c("NANA")]

  return (x)

}

#' @title Mime
#' @keywords internal
#' @noRd
Mime <- \(x, mime = FALSE, charset = FALSE) {

  # Remove charset information
  if (grepl("charset",x)) {
    x <- unlist(strsplit(x,";"))
    x.charset <- x[2]
    x <- x[1]
  }

  # Define Mime types
  data <- c(bib = "application/x-bibtex",
            csv = "text/csv",
            json = "application/json",
            html = "text/html;charset",
            json = "application/vnd.citationstyles.csl+json",
            xml = "application/mods+xml",
            pdf = "application/pdf",
            ris = "application/x-research-info-systems",
            rdf = "application/rdf+xml",
            xml = "text/xml",
            txt = "text/x-wiki")

  # Set data as either Mime or extension
  data <- if (!mime) names(data[data == x]) else data[[x]]

  # If no data set as json / txt
  if (!length(data)) {
    data <- if (mime) "application/json" else "txt"
  }

  # Append charset if Mime and charset is set to TRUE
  if (!mime & charset) data <- paste0(data,x.charset)

  return (data)

}

#' @title ReadCss
#' @keywords internal
#' @noRd
ReadCss <- \(data, css, clean.text = TRUE) {

  data <- data |>
    rvest::html_nodes(css) |>
    rvest::html_text()

  if (clean.text) data <- data |> CleanText()

  return (data)

}

#' @title ReadXpath
#' @keywords internal
#' @noRd
ReadXpath <- \(data, xpath, clean.text = TRUE) {

  data <- data |>
    rvest::html_nodes(xpath = xpath) |>
    rvest::html_text()

  if (clean.text) data <- data |> CleanText()

  return (data)

}

#' @title ReadAttr
#' @keywords internal
#' @noRd
ReadAttr <- \(data, xpath, attr) {

  data <- data |>
    rvest::html_nodes(xpath = xpath) |>
    rvest::html_attr(attr)

  return (data)

}

#' @title ParseUrl
#' @keywords internal
#' @noRd
ParseUrl <- \(x,
              format = "text",
              as = NULL,
              type = NULL,
              encoding = "UTF-8") {

  # Define parse method
  if (is.null(as)) {

    formats <- c(raw = "raw",
                 coins = "parsed",
                 csv = "parsed",
                 bookmarks = "parsed",
                 json = "text",
                 csljson = "text",
                 bibtex = "text",
                 biblatex = "text",
                 mods = "text",
                 refer = "text",
                 rdf_bibliontology = "text",
                 rdf_dc = "text",
                 rdf_zotero = "text",
                 ris = "text",
                 tei = "text",
                 wikipedia = "text",
                 txt = "text",
                 text = "text")

    as <- formats[format]
    if (is.na(as)) as <- "text"
  }

  # Parse data
  result <- httr::content(
    x, as, type, encoding, show_col_types = FALSE
  )

  # Remove empty json
  if (as == "text") {
    if (result == "[]") result <- NULL
  }

  return (result)

}

#' @title EditionFix
#' @keywords internal
#' @noRd
EditionFix <- \(edition) {

  # Some ISBN lists two edtions (e.g., 2nd ed. and global ed.)
  if (length(edition)>1) {
    edition <-   edition <- GoFish(
      sort(unique(unlist(lapply(edition, \(x) {
        x[grepl("\\d", EditionFix(x))]
      }))))[[1]]
    )
  }

  if (length(edition)) {
    # Convert English letters [1:20] to numeric
    English2Numeric <- \(word) {
      rank <- (c("first", "second", "third", "fourth", "fifth", "sixth",
                 "seventh", "eighth", "ninth", "tenth", "eleventh",
                 "twelfth", "thirteenth", "fourteenth", "fifteenth",
                 "sixteenth", "seventeenth", "eighteenth",
                 "nineteenth", "twentieth"))
      pos <- which(lapply(rank, \(x) grepl(x, tolower(word))) == TRUE)
      if (length(pos)) word <- pos[[1]]
      return (word)
    }

    # Convert Norwegian letters [1:20] to nureric
    Norwegian2Numeric <- \(word) {
      rank <- (c("f\u00f8rste", "andre", "tredje", "fjerde", "femte", "sjette",
                 "syvende", "\u00e5ttende", "niende", "tiende", "ellevte",
                 "tolvte", "trettende", "fjortende", "femtende",
                 "sekstende", "syttende", "attende",
                 "nittende", "tjuende"))
      pos <- which(lapply(rank, \(x) grepl(x, tolower(word))) == TRUE)
      if (length(pos)) word <- pos[[1]]
      return (word)
    }

    # Replace written edition with numeric
    if (!is.null(edition)) {
      if (!grepl("\\d", edition)) {
        edition <- English2Numeric(edition)
        edition <- Norwegian2Numeric(edition)
      }
      if (grepl("\\d", edition)) {
        # Extract numeric only from edition
        edition <-  suppressWarnings(
          as.numeric(gsub("[^0-9-]", "", edition))
        )
      }
    }

    # set edition as NA if first edition
    if (edition == "1") edition <- NA
  }

  return (as.character(edition))

}
