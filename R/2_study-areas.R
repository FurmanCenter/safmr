library(here) # consistent file paths
library(tibble) # making dataframes (tribble)
library(readr) # read/write data files


# For the analysis we will only examine these 24 HUD areas

hud_study_areas <- tribble(
  ~hud_area_code,
  "METRO12060M12060",
  "METRO35620MM0875",
  "METRO16740M16740",
  "METRO16980M16980",
  "METRO17820M17820",
  "METRO19100M19100",
  "METRO33100MM2680",
  "METRO19100MM2800",
  "METRO16980MM2960",
  "METRO25540M25540",
  "METRO27140M27140",
  "METRO27260M27260",
  "METRO35620MM5190",
  "METRO35840M35840",
  "METRO37340M37340",
  "METRO37980M37980",
  "METRO38300M38300",
  "METRO40900M40900",
  "METRO41700M41700",
  "METRO41740M41740",
  "METRO45300M45300",
  "METRO46520M46520",
  "METRO47900M47900",
  "METRO33100MM8960"
)


# Save Data ---------------------------------------------------------------

write_rds(hud_study_areas, here("data", "derived_data", "hud_study_areas.rds"))