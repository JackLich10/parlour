### Script to scrape Durham's best ice cream shop, The Parlour's daily flavor offerings
# Author: Jack Lichtenstein

# Load libraries
suppressMessages(suppressWarnings(library(dplyr)))
suppressMessages(suppressWarnings(library(lubridate)))
suppressMessages(suppressWarnings(library(readr)))
suppressMessages(suppressWarnings(library(rvest)))
suppressMessages(suppressWarnings(library(stringr)))

# Link to daily menu
link <- "https://theparlour.co/menu/"

cat("Reading The Parlour's menu HTML...\n")

# Read page html
html <- rvest::read_html(link)

cat("Finding The Parlour's current flavors...\n")

# Extract the current flavor offerings
flavor_elements <- html %>%
  rvest::html_elements(".flavor")

flavors <- flavor_elements %>%
  rvest::html_element("h3") %>%
  rvest::html_text() %>%
  stringr::str_squish()

# Extract the current flavor descriptions
descriptions <- flavor_elements %>%
  rvest::html_element("div") %>%
  rvest::html_text() %>%
  stringr::str_squish()

### TO TEST
# flavors <- c(flavors, "Salty Malty Cookie Gravel")

# Detect if my favorite flavor is on the menu
salty_malty <- any(stringr::str_detect(flavors, "(S|s)alty (M|m)alty (C|c)"))

if (isTRUE(salty_malty)) {
  cat("The Parlour has a Salty Malty flavor!\n")
} else {
  cat("The Parlour does not have a Salty Malty flavor :(\n")
}

# Put into a tibble
offerings <- dplyr::tibble(flavor = flavors,
                           description = descriptions,
                           date = Sys.time(),
                           hour = lubridate::hour(date),
                           minute = lubridate::minute(date)) %>%
  dplyr::mutate(date = Sys.Date())

cat("Writing a .csv of the current flavors...\n")

# Path to write to
path <- paste0("data/flavors_", Sys.Date(), ".csv")
yesterday_path <- paste0("data/flavors_", Sys.Date()-1, ".csv")

# Read in previously scraped flavors of the day if possible
prev_offerings <- try(readr::read_csv(path, col_types = readr::cols()), silent = TRUE)
yesterday_offerings <- try(readr::read_csv(yesterday_path, col_types = readr::cols()), silent = TRUE)

# Write data to .csv
if ("try-error" %in% class(prev_offerings)) {
  readr::write_csv(offerings, path)
} else {
  dplyr::bind_rows(prev_offerings, offerings) %>%
    readr::write_csv(path)
}

# Send a text if my favorite flavor is offered
if (isTRUE(salty_malty)) {

  cat("Sending a text message notification for the Salty Malty flavor!\n")

  # Load in `twilio` library
  suppressMessages(suppressWarnings(library(twilio)))

  # Construct text message
  message <- paste0("Durham's The Parlour is currently offering ",
                    stringr::str_subset(flavors, "(S|s)alty (M|m)alty (C|c)ookie"),
                    " as of ", Sys.Date(), "!")

  # Send message to me
  twilio::tw_send_message(
    to = Sys.getenv("my_number"),
    from = Sys.getenv("from_number"),
    body = message
  )

  # Send message to friend
  twilio::tw_send_message(
    to = Sys.getenv("friend_number"),
    from = Sys.getenv("from_number"),
    body = message
  )
}

if (!"try-error" %in% class(yesterday_offerings)) {
  # Find any new flavors
  new_flavors <- setdiff(offerings$flavor, yesterday_offerings$flavor)

  # Send a text for new flavors
  if (length(new_flavors) > 0) {

    cat("Sending a text message notification for new flavors!\n")

    # Load in `twilio` library
    suppressMessages(suppressWarnings(library(twilio)))

    # Construct text message
    message <- paste0("Durham's The Parlour has new flavors today:\n",
                      paste0(new_flavors, collapse = ", "))

    # Send message to me
    twilio::tw_send_message(
      to = Sys.getenv("my_number"),
      from = Sys.getenv("from_number"),
      body = message
    )

    # Send message to friend
    twilio::tw_send_message(
      to = Sys.getenv("friend_number"),
      from = Sys.getenv("from_number"),
      body = message
    )
  }
}

cat("Completed The Parlour daily menu scrape.\n")
