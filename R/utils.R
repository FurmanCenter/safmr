
# returns TRUE/FALSE if there are any duplicate rows in the dataset for a given
# set of columns.

no_dupes <- function(df, ...) {
  cols <- dplyr::quos(...)
  nrow(df) == nrow(dplyr::distinct(df, !!! cols))
}


# returns TRUE/FALSE if there are any missing values in the dataset

no_na_rows <- function(df) {
  nrow(dplyr::filter_all(df, dplyr::any_vars(is.na(.)))) == 0
}


# returns TRUE/FALSE if there are an equal number of  rows in a dataset for a
# given set of columns.

equal_rows <- function(df, ...) {
  cols <- dplyr::quos(...)
  df %>%
    ungroup() %>% 
    dplyr::count(!!! cols) %>% 
    dplyr::mutate(same = n == dplyr::lag(n)) %>%
    tidyr::drop_na() %>%
    dplyr::pull(same) %>%
    all()
}
