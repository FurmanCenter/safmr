library(here) # consistent file paths
library(readxl) # read excel files
library(dplyr) # data manipulation
library(tidyr) # data reshaping
library(stringr) # string manipulation
library(tibble) # making dataframes (tribble)
library(readr) # read/write data files


# Clean the SAFMR and FMR rent payment standards to that there are only the 24
# HUD areas we're studying, and the dataset has a row for each combination of
# ZCTA, HUD area, and number of bedrooms. Also read in the HUD-provided
# deflation factor to adjust 2018 payment standards to 2015 levels to match the
# zcta-level unit distribution data. We deflate the 2018 rent standards by
# factors for inflation (CPI), trends, and recent-mover info.

hud_study_areas <- read_rds(here("data", "derived_data", "hud_study_areas.rds"))


# Load and clean payment standards and deflation factors ------------------

# Important and clean the SAFMR payment standards for 1-3 bedrooms
safmr_rents <- here("data", "raw_data", "fy2018_advisory_safmrs.xlsx") %>%
  read_xlsx() %>%
  rename_all(funs(str_replace_all(., "[\\s\\-%]+", "_"))) %>%
  rename_all(str_to_lower) %>%
  select(
    zcta = zip_code,
    hud_area_code,
    hud_area_name = hud_metro_fair_market_rent_area_name,
    matches("safmr_[123]br$")
  ) %>%
  distinct() %>%
  gather("bedrooms", "safmr", -zcta, -hud_area_code, -hud_area_name) %>%
  mutate(bedrooms = str_sub(bedrooms, 7, 7))


# There are 5 areas that have used the 50th percentile for FMRs, but for
# comparisons to the SAMFRs using the 40th percentile we replace the 50th
# percentile FMRs with with the 40th. These are taken from HUD's "FY 2018 Fair
# Market Rent Documentation System" which is available at the following address.
# As a record there is a PDF with this link and screen shots of the pages where
# the values below where found (see "data/raw_data/fmr_40_screenshots.pdf")

# https://www.huduser.gov/portal/datasets/fmr.html#2018_query

fmr_40 <- tibble::tribble(
  ~hud_area_code, ~hud_area_name, ~bedrooms, ~fmr,
  "METRO37980M37980", "Philadelphia-Camden-Wilmington, PA-NJ-DE-MD MSA", "1", 967,
  "METRO37980M37980", "Philadelphia-Camden-Wilmington, PA-NJ-DE-MD MSA", "2", 1169,
  "METRO37980M37980", "Philadelphia-Camden-Wilmington, PA-NJ-DE-MD MSA", "3", 1466,
  "METRO41740M41740", "San Diego-Carlsbad, CA MSA", "1", 1287,
  "METRO41740M41740", "San Diego-Carlsbad, CA MSA", "2", 1669,
  "METRO41740M41740", "San Diego-Carlsbad, CA MSA", "3", 2400,
  "METRO35620MM0875", "Bergen-Passaic, NJ HUD Metro FMR Area", "1", 1343,
  "METRO35620MM0875", "Bergen-Passaic, NJ HUD Metro FMR Area", "2", 1578,
  "METRO35620MM0875", "Bergen-Passaic, NJ HUD Metro FMR Area", "3", 2017,
  "METRO33100MM8960", "West Palm Beach-Boca Raton, FL HUD Metro FMR Area", "1", 1054,
  "METRO33100MM8960", "West Palm Beach-Boca Raton, FL HUD Metro FMR Area", "2", 1319,
  "METRO33100MM8960", "West Palm Beach-Boca Raton, FL HUD Metro FMR Area", "3", 1802,
  "METRO47900M47900", "Washington-Arlington-Alexandria, DC-VA-MD HUD Metro FMR Area", "1", 1446,
  "METRO47900M47900", "Washington-Arlington-Alexandria, DC-VA-MD HUD Metro FMR Area", "2", 1661,
  "METRO47900M47900", "Washington-Arlington-Alexandria, DC-VA-MD HUD Metro FMR Area", "3", 2180
)

# Load all the metro-level FMRs, then remove data for the 5 50th percentile
# areas, and substitute in the above values.
fmr_rents <- here("data", "raw_data", "FY18_4050_FMRs.xls") %>%
  read_xls() %>%
  select(hud_area_code = metro_code, matches("fmr_[123]")) %>%
  distinct() %>%
  gather("bedrooms", "fmr", -hud_area_code) %>%
  mutate(bedrooms = str_sub(bedrooms, -1)) %>%
  anti_join(fmr_40, by = "hud_area_code") %>%
  bind_rows(fmr_40) %>%
  select(-hud_area_name)

# Import the various adjustment factors to apply to FY2018 payment standards for
# use with 2015 unit distribution data.
adj_factors <- here("data", "raw_data", "FY18_SAFMR_Component_Factors.xls") %>%
  read_xls() %>%
  select(
    hud_area_code = cbsasub18,
    recent_mover_factor = rm_final,
    cpi_factor = cpi_updatefactor,
    trend_factor
  )



# Join all files together and deflate rent standards ----------------------

# Join all the payment standards and make the adjustments
payment_standards <- safmr_rents %>%
  left_join(fmr_rents, by = c("hud_area_code", "bedrooms")) %>%
  semi_join(hud_study_areas, by = "hud_area_code") %>%
  left_join(adj_factors, by = "hud_area_code") %>%
  mutate(
    fmr_adj = fmr / (recent_mover_factor * cpi_factor * trend_factor),
    safmr_adj = safmr / (recent_mover_factor * cpi_factor * trend_factor)
  ) %>%
  select(-ends_with("factor"), -fmr, -safmr)



# Validate Data -----------------------------------------------------------

# Confirm there are no unwanted duplicates

stopifnot(no_dupes(safmr_rents))
stopifnot(no_dupes(fmr_rents))
stopifnot(no_dupes(adj_factors))
stopifnot(no_dupes(payment_standards))


# Confirm that there are no missing values

stopifnot(no_na_rows(payment_standards))


# Confirm that there are an equal number of rows by different groups

stopifnot(equal_rows(payment_standards, bedrooms))


# Save Data ---------------------------------------------------------------

write_rds(payment_standards, here("data", "derived_data", "payment_standards.rds"))