library(here) # consistent file paths
library(dplyr) # data manipulation
library(tidyr) # data reshaping
library(stringr) # string manipulation
library(readr) # read/write data files
library(ggplot2) # making graphs


# Load data from previous scripts -----------------------------------------

payment_standards <- read_rds(here("data", "derived_data", "payment_standards.rds"))
zcta_hud_area_xwalk <- read_rds(here("data", "derived_data", "zcta_hud_area_xwalk.rds"))
zcta_units <- read_rds(here("data", "derived_data", "zcta_units.rds"))


# Join payment standards, units, and crosswalks ---------------------------

# zctas that cross HUD areas
multi_area_zctas <- payment_standards %>%
  distinct(zcta, hud_area_code) %>%
  count(zcta) %>%
  filter(n != 1)

# separate out zctas that do/don't cross HD_areas, and join each to the zcta
# units data and for the multi-areas zctas merge in the crosswalk then use the
# allocation factor to adjust the zcta total unit counts for the zctas that
# cross HUD areas.

single_zcta_df <- payment_standards %>%
  anti_join(multi_area_zctas, by = "zcta") %>%
  inner_join(zcta_units, by = c("zcta", "bedrooms")) %>%
  rename(total_units = all_units)

multi_zcta_df <- payment_standards %>%
  semi_join(multi_area_zctas, by = "zcta") %>%
  inner_join(zcta_units, by = c("zcta", "bedrooms")) %>%
  inner_join(zcta_hud_area_xwalk, by = c("zcta", "hud_area_code")) %>%
  mutate(total_units = all_units * afact) %>%
  select(-all_units, -afact)


# Calculate Affordable Units ----------------------------------------------

# Stack the two datasets together and calculate the affordable units under SAFMR
# and FMR for each zcta/hud_area and rent range.

afford_df <- bind_rows(single_zcta_df, multi_zcta_df) %>%
  mutate(
    fmr_afford_units = case_when(
      fmr_adj >= rent_hi  ~ total_units,
      fmr_adj >= rent_mid ~ total_units / 2,
      fmr_adj < rent_mid  ~ 0
    ),
    safmr_afford_units = case_when(
      safmr_adj >= rent_hi  ~ total_units,
      safmr_adj >= rent_mid ~ total_units / 2,
      safmr_adj < rent_mid  ~ 0
    )
  )


# Function to summarise units ---------------------------------------------

# This sums up the total and affordable units, then calculates the share
# affordable and differences between FMr and SAFMR

summarise_units <- function(df) {
  df %>%
    summarise_at(
      vars(total_units, fmr_afford_units, safmr_afford_units),
      sum, na.rm = TRUE
    ) %>%
    mutate(
      fmr_afford_pct = fmr_afford_units / total_units,
      safmr_afford_pct = safmr_afford_units / total_units,
      diff_afford_units = safmr_afford_units - fmr_afford_units,
      diff_afford_pct = (diff_afford_units / fmr_afford_units) * 100
    )
}


# Rent Categories Analysis ------------------------------------------------

# Categorize ZCTAs based on the rent ratio, where rent ratio is SAFMR
# (2-bedroom) divided by FMR (2-bedroom)

# create these categorizations for 2-bedroom data, then merge back in the full
# dataset with all unit sizes
zcta_rent_cat <- payment_standards %>%
  filter(bedrooms == "2") %>%
  mutate(
    rent_ratio = safmr_adj / fmr_adj,
    rent_cat = case_when(
      rent_ratio < 0.9              ~ "< 0.9",
      between(rent_ratio, 0.9, 1.1) ~ "0.9-1.1",
      rent_ratio > 1.1              ~ "> 1.1"
    )
  ) %>%
  select(hud_area_code, zcta, rent_cat)


# Use the summarise_units function from above to calculate the share of units
# affordable for all 24 areas
total_rent_cat_stats <- afford_df %>%
  summarise_units() %>%
  ungroup() %>% 
  mutate(rent_cat = "Total")

# Now do the same for each area, stack the total values on, reshape and clean up
# for plotting
rent_cat_table <- afford_df %>% 
  left_join(zcta_rent_cat, by = c("hud_area_code", "zcta")) %>%
  group_by(rent_cat) %>%
  summarise_units() %>%
  ungroup() %>% 
  bind_rows(total_rent_cat_stats) %>%
  select(rent_cat, safmr_afford_pct, fmr_afford_pct) %>%
  gather("type", "afford_pct", -rent_cat) %>%
  mutate(
    type = str_extract(type, "^[a-z]*") %>% str_to_upper() %>% recode(SAFMR = "Small Area FMR"),
    rent_cat = factor(rent_cat, levels = c("< 0.9", "0.9-1.1", "> 1.1", "Total")),
    afford_pct = afford_pct * 100
  )


# Validata rent category data

stopifnot(no_na_rows(zcta_rent_cat))
stopifnot(no_dupes(zcta_rent_cat, hud_area_code, zcta))

stopifnot(no_na_rows(rent_cat_table))
stopifnot(no_dupes(rent_cat_table, rent_cat, type))
stopifnot(equal_rows(rent_cat_table, rent_cat))


write_csv(rent_cat_table, here("results", "rent_category_table.csv"))


# Replicate figure 4.2 from Interim report (pg. 29)
rent_cat_table %>% 
  ggplot(aes(rent_cat, afford_pct, fill = type)) +
  geom_col(position = "dodge", color = "black") +
  geom_text(
    aes(label = round(afford_pct, 0), y = afford_pct / 2),
    position = position_dodge(width = 0.9)
  ) +
  scale_y_continuous(breaks = seq(0, 70, 10)) +
  scale_x_discrete() +
  scale_fill_manual(values = c("white", "grey60")) +
  theme_minimal() +
  labs(
    title = "Share of Rental Units Below Small Area FMR and Metropolitan Area FMR",
    y = "Share of all rental units",
    x = "ZIP Code rent ratio categories",
    fill = NULL
  )

ggsave(here("results", "rent_category_figure.png"), width = 7, height = 5, units = "in")


# Create Results Tables ---------------------------------------------------


# For each HUD_area sum up the various unit counts, then do the same for all the
# areas overall, and stack them together into the final table of results.


metro_afford_table <- afford_df %>%
  group_by(hud_area_code, hud_area_name) %>%
  summarise_units()

total_afford_table <- afford_df %>%
  mutate(
    hud_area_code = "",
    hud_area_name = "All SAFMR Areas"
  ) %>%
  group_by(hud_area_code, hud_area_name) %>%
  summarise_units()


final_afford_table <- bind_rows(total_afford_table, metro_afford_table) %>%
  select(
    hud_area_code, hud_area_name,
    total_units, fmr_afford_units, safmr_afford_units,
    fmr_afford_pct, safmr_afford_pct,
    diff_afford_units, diff_afford_pct
  ) %>% 
  arrange(hud_area_name)


# Validate Data results table

# Confirm there are no unwanted duplicates
stopifnot(no_dupes(afford_df))

# Confirm that there are no missing values
stopifnot(no_na_rows(afford_df))

# Confirm that there are an equal number of rows by different groups
stopifnot(equal_rows(afford_df, bedrooms))
stopifnot(equal_rows(afford_df, rent_lo))


# Save Data ---------------------------------------------------------------

write_csv(final_afford_table, here("results", "afford_table.csv"))