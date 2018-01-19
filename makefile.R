
# Un-comment and run following chunk to install packages required for analysis

# pkgs <- c(
#   "here",    # consistent file paths
#   "glue",    # interpreted strings
#   "readxl",  # read excel files
#   "dplyr",   # data manipulation
#   "tidyr",   # data reshaping
#   "stringr", # string manipulation
#   "tibble",  # making dataframes
#   "readr",   # read/write data files
#   "purrr",   # iteration
#   "ggplot2"  # graphing
# )
#
# install.packages(pkgs)



library(here)

# Load custom functions for validating data throughout the following scripts
source(here("R", "utils.R"))

source(here("R", "1_download-files.R"))
source(here("R", "2_study-areas.R"))
source(here("R", "3_zcta-hud-area-xwalk.R"))
source(here("R", "4_payment-standards.R"))
source(here("R", "5_zcta-units.R"))
source(here("R", "6_afford-units.R"))