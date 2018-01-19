library(here) # consistent file paths
library(purrr) # iteration
library(readxl) # read excel files
library(dplyr) # data manipulation
library(tidyr) # data reshaping
library(stringr) # string manipulation
library(readr) # read/write data files & parse_number


# Prepare Census Unit Counts ----------------------------------------------

# Get all the zcta excel file paths in the directory, for each file import it
# then stack (bind_rows) all of the dataframes, then create a bedrooms column,
# remove total rows, convert text rent ranges into numeric columns and calculate
# the midpoint for each range

zcta_units <- here("data", "raw_data") %>%
  dir(pattern = "^asq_zctadata_2015_.*\\.xlsx$", full.names = TRUE) %>%
  map_dfr(read_xlsx) %>%
  mutate(
    bedrooms = if_else(str_detect(stub, "bedroom"), stub, NA_character_) %>%
      recode("No bedroom" = "0") %>%
      str_extract("\\d")
  ) %>%
  fill(bedrooms, .direction = "down") %>%
  filter(!str_detect(stub, "bedroom|rent")) %>%
  filter(bedrooms %in% c("1", "2", "3")) %>%
  mutate(
    stub = stub %>%
      str_replace("Less than", "$0 to") %>%
      str_replace("or more", "to $3500"),
    rent_lo = str_replace(stub, "(.*)to.*", "\\1") %>% parse_number(),
    rent_hi = str_replace(stub, ".*to(.*)", "\\1") %>% parse_number(),
    rent_mid = (rent_hi + rent_lo) / 2
  ) %>%
  select(zcta, bedrooms, all_units = num_estimate, starts_with("rent"))


# Validate Data -----------------------------------------------------------

# Confirm that there are an equal number of rows by different groups
stopifnot(equal_rows(zcta_units, zcta))
stopifnot(equal_rows(zcta_units, bedrooms))
stopifnot(equal_rows(zcta_units, rent_lo))

# Confirm that there are no missing values
stopifnot(no_na_rows(zcta_units))

# Confirm there are no unwanted duplicates
stopifnot(no_dupes(zcta_units))


# Save Data ---------------------------------------------------------------

write_rds(zcta_units, here("data", "derived_data", "zcta_units.rds"))