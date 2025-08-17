# Title: ERA5 Site-Level Precipitation Report
# Desc: Extracts and reports monthly precipitation from ERA5 data for specific sites.
# Data Source: European Centre for Medium-Range Weather Forecasts

# //////////////////////////////////////////////////////////////////////////////
# SECTION 1: PACKAGE MANAGEMENT ----
# //////////////////////////////////////////////////////////////////////////////
# Desc: Installs missing packages and loads all required libraries.
required_packages <- c(
  "terra", "sf", "dplyr", "stringr", "readxl", "data.table", "tidyr")
install_and_load <- function(pkgs) {
  to_install <- pkgs[!(pkgs %in% installed.packages()[, "Package"])]
  if (length(to_install) > 0) {
    install.packages(to_install, repos = "https://cloud.r-project.org")
  }
  invisible(sapply(pkgs, library, character.only = TRUE))
}
install_and_load(required_packages)

# //////////////////////////////////////////////////////////////////////////////
# SECTION 2: CONFIGURATION ----
# //////////////////////////////////////////////////////////////////////////////
# Desc: Sets up main directories for input and output.
main_dir <- normalizePath(Sys.getenv("ONCC_MAIN", "C:/ONCC_ERA5_postprocessing"), mustWork = FALSE)
dir_config <- list(
  input_sites    = file.path(main_dir, "Input_sites"),
  raster_outcome = file.path(main_dir, "Input"),
  outcome        = file.path(main_dir, "Sites_outcome")
)
# Ensure output directory exists (creates if missing)
if (!dir.exists(dir_config$outcome)) {
  dir.create(dir_config$outcome, recursive = TRUE, showWarnings = FALSE)
}
# Set the tabular data path
raw_data_path <- file.path(dir_config$input_sites, "Sites.xlsx")
if (!file.exists(raw_data_path)) {
  stop("Input file 'Sites.xlsx' not found at: ", raw_data_path)
}

# //////////////////////////////////////////////////////////////////////////////
# SECTION 3: UTILITY FUNCTIONS ----
# //////////////////////////////////////////////////////////////////////////////
# Desc: Helper function to delete all contents of a folder.
delete_contents <- function(folder) {
  if (!dir.exists(folder)) {
    warning("Folder does not exist, nothing to delete: ", folder)
    return(invisible(NULL))
  }
  all_items <- list.files(folder, full.names = TRUE)
  if (length(all_items) > 0) {
    unlink(all_items, recursive = TRUE, force = TRUE)
  }
}

# //////////////////////////////////////////////////////////////////////////////
# SECTION 4: MAIN PROCESSING PIPELINE ----
# //////////////////////////////////////////////////////////////////////////////
message("Cleaning output directory: ", dir_config$outcome)
delete_contents(dir_config$outcome)

# 4.1 Load site and raster data
message("Loading site data...")
sites_df <- readxl::read_excel(path = raw_data_path, sheet = 1, na = "NA") |>
  # Add a robust SiteID for joining and naming files
  mutate(SiteID = sprintf("ID%02d", 1:nrow(.)))

message("Loading raster data...")
geotiff_files <- list.files(dir_config$raster_outcome, pattern = "\\.tif$", full.names = TRUE)
if (length(geotiff_files) == 0) {
  stop("No GeoTIFF files found in the raster input directory.")
}
# Create a multi-layer SpatRaster object
raster_stack <- terra::rast(geotiff_files)

# 4.2 Extract precipitation data for each site
message("Extracting precipitation values from rasters...")
# The result is a data frame with an ID column and one column per raster layer
precip_wide <- terra::extract(
  x = raster_stack,
  y = terra::vect(sites_df, geom = c("Longitud", "Latitud"), crs = "EPSG:4326")
)

# 4.3 Tidy the extracted data
message("Tidying data for processing...")
# Get Year and Month from raster layer names
time_metadata <- as.data.frame(
  stringr::str_split_fixed(basename(geotiff_files), "\\.", 6)[, 2:3]
) |> 
  `names<-`(c("Year", "Month")) |> 
  mutate(across(everything(), as.numeric))

# Reshape the extracted data from wide to long format
precip_long <- precip_wide |>
  select(-ID) |>
  # Corrected: use base R `setNames` or backticks ` to handle names
  `names<-`(paste0("Layer_", 1:ncol(.))) |>
  mutate(SiteID = sites_df$SiteID) |>
  tidyr::pivot_longer(
    cols = -SiteID,
    names_to = "LayerIndex",
    values_to = "Precipitation"
  ) |>
  # Add Year and Month by joining with the metadata
  mutate(LayerIndex = as.integer(stringr::str_remove(LayerIndex, "Layer_"))) |>
  bind_cols(time_metadata[.$LayerIndex, ]) |>
  select(SiteID, Year, Month, Precipitation)

# Update the Precipitation values to represent monthly totals
precip_long_updated <- precip_long |>
  mutate(
    DaysInMonth = case_when(
      Month == 2  ~ 28,  # Simplified for standard years; could be expanded for leap years
      Month %in% c(4, 6, 9, 11) ~ 30,
      TRUE ~ 31
    ),
    Precipitation = Precipitation * DaysInMonth
  ) |>
  select(-DaysInMonth)

# 4.4 Reshape and write data for each site
message("Writing site-level CSV files...")
precip_long_updated |>
  group_by(SiteID) |>
  group_walk(~ {
    file_path <- file.path(dir_config$outcome, paste0(.y$SiteID, ".csv"))
    .x |>
      # Sort and pivot for a clean, wide-format report
      arrange(Year, Month) |>
      mutate(Month = factor(month.abb[Month], levels = month.abb)) |>
      tidyr::pivot_wider(names_from = Month, values_from = Precipitation) |>
      data.table::fwrite(file = file_path, row.names = FALSE, na = "NA")
  })

# 4.5 Save the site metadata file with assigned SiteIDs
message("Writing site metadata file...")
out_file <- file.path(dir_config$outcome, "Sites_ID.csv")
data.table::fwrite(sites_df, out_file, na = "NA", bom = TRUE)

# /////////////////////////////////////////////////////////////////////////////
# SECTION 5: CLEANUP ----
# /////////////////////////////////////////////////////////////////////////////
cat("Script finished successfully.\n")
rm(list = ls())
invisible(gc())
quit(save = "no", status = 0)