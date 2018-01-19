library(purrr) # iteration
library(glue) # interpreted strings
library(here) # consistent file paths

# Download public files from HUD's SAFMR webpage, and from Census.

hud_url_base <- "https://www.huduser.gov/portal/datasets/fmr"

# HUD ZCTA Rents Data -----------------------------------------------------

zip_ranges <- c("00001thru19999", "20000thru39999", "40000thru59999", "60000thru79999", "80000thru99999")
hud_file_names <- glue("asq_zctadata_2015_{zip_ranges}.xlsx")
hud_file_urls <- glue("{hud_url_base}/fmr2018/{hud_file_names}")
hud_file_paths <- here("data", "raw_data", hud_file_names)

# download all files
walk2(hud_file_urls, hud_file_paths, download.file, quiet = TRUE, mode = "wb")


# Payment Standards -------------------------------------------------------

safmr_file_name <- "fy2018_advisory_safmrs.xlsx"

download.file(
  url = glue("{hud_url_base}/fmr2018/{safmr_file_name}"),
  destfile = here("data", "raw_data", safmr_file_name),
  mode = "wb"
)


fmr_file_name <- "FY18_4050_FMRs.xls"

download.file(
  url = glue("{hud_url_base}/fmr2018/{fmr_file_name}"),
  destfile = here("data", "raw_data", fmr_file_name),
  mode = "wb"
)


factors_file_name <- "FY18_SAFMR_Component_Factors.xls"

download.file(
  url = glue("{hud_url_base}/fmr2018/{factors_file_name}"),
  destfile = here("data", "raw_data", factors_file_name),
  mode = "wb"
)


# There are 5 areas that have used the 50th percentile for FMRs, but for
# comparisons to the SAMFRs using the 40th percentile we replace the 50th
# percentile FMRs with with the 40th. These are taken from HUD's "FY 2018 Fair
# Market Rent Documentation System" which is available at the following address.
# As a record there is a PDF with this link and screen shots of the pages where
# the values below where found (see "data/raw_data/fmr_40_screenshots.pdf")

# https://www.huduser.gov/portal/datasets/fmr.html#2018_query


# Census ZCTA-County Sub-division correspondence --------------------------

xwalk_doc_file_name <- "explanation_zcta_cousub_rel_10.pdf"

download.file(
  url = glue("https://www2.census.gov/geo/pdfs/maps-data/data/rel/{xwalk_doc_file_name}"),
  destfile = here("data", "raw_data", xwalk_doc_file_name),
  mode = "wb"
)


xwalk_data_file_name <- "zcta_cousub_rel_10.txt"

download.file(
  url = glue("https://www2.census.gov/geo/docs/maps-data/data/rel/{xwalk_data_file_name}"),
  destfile = here("data", "raw_data", xwalk_data_file_name)
)