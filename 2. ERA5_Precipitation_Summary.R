# Title: ERA5 Precipitation Summary and Aggregation
# Desc: Calculates area-averaged precipitation time series and annual total rasters.
# Data Source: European Centre for Medium-Range Weather Forecasts

# //////////////////////////////////////////////////////////////////////////////
# SECTION 1: PACKAGE MANAGEMENT ----
# //////////////////////////////////////////////////////////////////////////////
# Installs missing packages and loads all required libraries.
required_packages <- c(
  "terra", "sf", "dplyr", "stringr", "readxl", "stats", "data.table")
install_and_load <- function(pkgs) {
  to_install <- pkgs[!(pkgs %in% installed.packages()[, "Package"])]
  if (length(to_install) > 0) {
    install.packages(to_install, repos = "https://cloud.r-project.org")
  }
  invisible(lapply(pkgs, library, character.only = TRUE))
}
install_and_load(required_packages)

# //////////////////////////////////////////////////////////////////////////////
# SECTION 2: CONFIGURATION ----
# //////////////////////////////////////////////////////////////////////////////
# Define or override main directories via environment variables for flexibility
main_dir <- normalizePath(Sys.getenv("ONCC_MAIN", "C:/ONCC_ERA5_postprocessing"), mustWork = FALSE)
dir_config <- list(
  aoi            = file.path(main_dir, "AOI"),
  input          = file.path(main_dir, "Input"),
  outcome        = file.path(main_dir, "Outcome"),
  raster_outcome = file.path(main_dir, "Raster_Outcome")
)
# Ensure output directories exist (creates if missing)
if (!dir.exists(dir_config$outcome)) {
  dir.create(dir_config$outcome, recursive = TRUE, showWarnings = FALSE)
}
if (!dir.exists(dir_config$raster_outcome)) {
  dir.create(dir_config$raster_outcome, recursive = TRUE, showWarnings = FALSE)
}

# //////////////////////////////////////////////////////////////////////////////
# SECTION 3: UTILITY FUNCTIONS ----
# //////////////////////////////////////////////////////////////////////////////
# Helper function to get the number of days in a month.
get_days_in_month <- function(month) {
  as.numeric(
    case_when(
      month == "02" ~ 28,  # Simplified for standard years; could be expanded for leap years
      month %in% c("04", "06", "09", "11") ~ 30,
      TRUE ~ 31
    )
  )
}

# Load AOI vector and convert to SpatVector
load_aoi <- function(pattern, dir_path) {
  vector_files <- list.files(dir_path, pattern, full.names = TRUE)
  if (length(vector_files) == 0) stop("No AOI files found matching pattern: ", pattern)
  sf_obj  <- sf::st_read(vector_files, quiet = TRUE)
  terra::vect(sf_obj)
}

# Delete all contents of a folder
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
# 4.1 Load Area of Interest
message("Loading AOI...")
aoi <- load_aoi("Falcon", dir_config$aoi)

# 4.2 Clear previous outputs
message("Cleaning output directories...")
delete_contents(dir_config$outcome)
delete_contents(dir_config$raster_outcome)

# 4.3 Process monthly precipitation time series
message("Processing monthly area-averaged precipitation...")
geotiff_files <- list.files(dir_config$input, pattern = "\\.tif$", full.names = TRUE)

monthly_data <- lapply(geotiff_files, function(file_path) {
  # Extract metadata from filename
  metadata <- stringr::str_split_fixed(basename(file_path), "\\.", 5)
  year <- metadata[, 3]
  month <- metadata[, 4]

  # Process the raster
  r <- terra::rast(file_path)
  r_masked <- terra::mask(terra::crop(r, aoi), aoi)
  
  # Calculate area-averaged daily value and convert to monthly total
  daily_value <- global(r_masked, fun = mean, na.rm = TRUE)$mean
  monthly_value <- daily_value * get_days_in_month(month)

  # Return as a data frame row
  data.frame(
    State = 'FALCON',
    Year = as.numeric(year),
    Month = as.numeric(month),
    Precipitation_mm = round(monthly_value, 3)
  )
}) |> bind_rows()

# Write the calculated area-averaged monthly values to a CSV file
out_file <- file.path(dir_config$outcome, "Falcon_Precipitation.csv")
data.table::fwrite(monthly_data, out_file, na = "NA")
message("Monthly time series saved to: ", out_file)

# 4.4 Generate annual total rasters
message("Generating annual total rasters...")
# Get unique years from the file names
years_to_process <- unique(stringr::str_split_fixed(basename(geotiff_files), "\\.", 5)[, 3])

for (year_i in years_to_process) {
  # Filter files for the current year
  files_subset <- geotiff_files[grepl(paste0("\\.", year_i, "\\."), geotiff_files)]
  
  if (length(files_subset) == 0) {
    warning("No files found for year: ", year_i)
    next
  }

  # Create a list of monthly rasters with corrected values (daily to monthly total)
  monthly_rasters <- lapply(files_subset, function(file) {
    month_val <- stringr::str_split_fixed(basename(file), "\\.", 5)[, 4]
    r <- terra::rast(file)
    r_masked <- terra::mask(terra::crop(r, aoi), aoi)
    r_monthly_total <- r_masked * get_days_in_month(month_val)
    return(r_monthly_total)
  })

  # Sum all monthly rasters to get the annual total
  annual_total_raster <- Reduce(`+`, monthly_rasters)
  names(annual_total_raster) <- paste("Falcon.AnnualPrecipitation", year_i, sep = ".")

  # Save the annual raster
  out_file <- file.path(dir_config$raster_outcome, paste0(names(annual_total_raster), ".tif"))
  terra::writeRaster(annual_total_raster, out_file, overwrite = TRUE)
  message("Annual raster saved for year: ", year_i)
}

# //////////////////////////////////////////////////////////////////////////////
# SECTION 5: CLEANUP ----
# //////////////////////////////////////////////////////////////////////////////
message("Processing complete. Cleaning up environment.")
rm(list = ls(all.names = TRUE), envir = .GlobalEnv)
invisible(gc())
quit(save = "no", status = 0)