library(here) # consistent file paths
library(readxl) # read excel files
library(dplyr) # data manipulation
library(stringr) # string manipulation
library(readr) # read/write data files


hud_study_areas <- read_rds(here("data", "derived_data", "hud_study_areas.rds"))

# HUD Area to County / county Sub-Division Crosswalks ----------------------

# Get two crosswalks for counties & HUD areas, and county sub-divisions & HUD areas

hud_area_xwalk <- here("data", "raw_data", "FY18_4050_FMRs.xls") %>%
  read_xls() %>%
  mutate(
    county = str_c(str_pad(state, 2, "left", "0"), str_pad(county, 3, "left", "0")),
    cousub = str_c(county, str_pad(cousub, 5, "left", "0"))
  ) %>%
  select(hud_area_code = metro_code, county, cousub) %>%
  distinct() %>%
  semi_join(hud_study_areas, by = "hud_area_code")

hud_area_cousub_xwalk <- hud_area_xwalk %>%
  filter(!str_detect(cousub, "99999$")) %>%
  select(-county)

hud_area_county_xwalk <- hud_area_xwalk %>%
  filter(str_detect(cousub, "99999$")) %>%
  select(-cousub)


# Census ZCTA to County/County Sub-Division Crosswalk ---------------------

# From Census, get two crosswalks for ZCTA & counties, and ZCTA & county
# sub-divisions. Then merge in the two other crosswalks from above.

xwalk_cols <- cols_only(
  ZCTA5 = "c",
  COUNTY = "c",
  COUSUB = "c",
  STATE = "c",
  HUPT = "d", # unit count for relationship record (part of zcta in county sub-division)
  ZHU = "d" # unit count for ZCTA
)

zcta_xwalk <- here("data", "raw_data", "zcta_cousub_rel_10.txt") %>%
  read_csv(col_types = xwalk_cols) %>%
  rename_all(str_to_lower) %>%
  rename(zcta = zcta5) %>%
  mutate(
    county = str_c(state, county),
    cousub = str_c(county, cousub)
  ) %>%
  filter(!(hupt == 0 & zhu == 0))

zcta_xwalk_county <- right_join(zcta_xwalk, hud_area_county_xwalk, by = "county")
zcta_xwalk_cousub <- right_join(zcta_xwalk, hud_area_cousub_xwalk, by = "cousub")


# Create ZCTA to HUD Area Crosswalk (with allocation factor) --------------


# Stack the two crosswalks above, then group by HUD area and create allocation
# factor representing the share of each ZCTA's housing units that fall in each
# HUD area. For most it will be 1, indicating that the zcta is completely within
# the HUD area, but there are some ZCTAs that cross hud areas, and in these
# cases the allocation factor will be less than 0. There are some cases where
# ZCTAs cross HUD areas and only part of it will be within one of our study
# areas so there will only be one row for that ZCTA with an afact < 0, other
# times it will cross between two HUD areas in the study and there will be
# multiple rows for that zcta with afact for each HUD area.

zcta_hud_area_xwalk <- bind_rows(zcta_xwalk_county, zcta_xwalk_cousub) %>%
  group_by(zcta, zhu, hud_area_code) %>%
  summarise(hupt = sum(hupt, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(afact = hupt / zhu) %>%
  select(zcta, hud_area_code, afact)



# Validate Data -----------------------------------------------------------

# Confirm the county and county sub-divisions crosswalks contain different hua_areas
stopifnot(
  hud_area_county_xwalk %>%
    inner_join(hud_area_cousub_xwalk, by = "hud_area_code") %>%
    nrow() == 0
)

# Confirm there are no unwanted duplicates
stopifnot(no_dupes(hud_area_county_xwalk))
stopifnot(no_dupes(hud_area_cousub_xwalk))
stopifnot(no_dupes(zcta_hud_area_xwalk))

# Confirm that there are no missing values

stopifnot(no_na_rows(hud_area_county_xwalk))
stopifnot(no_na_rows(hud_area_cousub_xwalk))
stopifnot(no_na_rows(zcta_hud_area_xwalk))


# Save Data ---------------------------------------------------------------

write_rds(zcta_hud_area_xwalk, here("data", "derived_data", "zcta_hud_area_xwalk.rds"))