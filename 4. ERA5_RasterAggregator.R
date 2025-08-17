# Title: ERA5 Raster Aggregator
# Desc: Generates aggregated rasters by calculating long-term averages from monthly and annual data.
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
	annual_input  = file.path(main_dir, "Raster_outcome"),
	monthly_input = file.path(main_dir, "Input"),
	outcome       = file.path(main_dir, "Aggregated_outcome")
)
# Ensure output directory exists (creates if missing)
if (!dir.exists(dir_config$outcome)) {
  dir.create(dir_config$outcome, recursive = TRUE, showWarnings = FALSE)
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

# 4.1 Aggregate Annual Raster Data
message("Processing annual rasters...")
annual_files <- list.files(dir_config$annual_input, pattern = "\\.tif$", full.names = TRUE)
if (length(annual_files) == 0) {
  warning("No annual raster files found in: ", dir_config$annual_input)
} else {
  # Define the time range for the average
  start_year <- 1942
  end_year <- 1948
  
  # Extract the year from each filename
  years <- as.numeric(gsub(".*\\.([0-9]{4})\\.tif$", "\\1", annual_files))
  
  # Filter files within the desired year range
  selected_files <- annual_files[years >= start_year & years <= end_year]
  
  if (length(selected_files) > 0) {
    # Create a multi-layered SpatRaster object from the selected files
    precip_stack <- terra::rast(selected_files)
    
    # Calculate the mean across all layers (i.e., the long-term annual average)
    mean_precip_raster <- app(precip_stack, fun = mean, na.rm = TRUE)
    
    # Construct the output filename and path
    output_filename <- paste0("Falcon_Annual_Average_Precipitation_", start_year, "_", end_year, ".tif")
    output_path <- file.path(dir_config$outcome, output_filename)
    
    # Write the mean raster to a GeoTIFF file
    writeRaster(mean_precip_raster, output_path, overwrite = TRUE)
    
    message("Long-term annual average precipitation raster saved to:", output_path)
  } else {
    warning("No annual files found for the specified date range.")
  }
}

# 4.2 Aggregate Monthly Raster Data
message("Processing monthly rasters...")
monthly_files <- list.files(dir_config$monthly_input, pattern = "\\.tif$", full.names = TRUE)
if (length(monthly_files) == 0) {
  warning("No monthly raster files found in: ", dir_config$monthly_input)
} else {
  # Define the start and end years for the analysis
  start_year <- 1940
  end_year <- 1941
  
  # Filter files by year range
  years <- as.numeric(substr(basename(monthly_files), 6, 9))
  selected_files_by_year <- monthly_files[years >= start_year & years <= end_year]
  
  # Group files by month
  months <- substr(basename(selected_files_by_year), 11, 12)
  files_grouped_by_month <- split(selected_files_by_year, months)
  
  # Use a for loop to iterate over each month
  for (month_key in names(files_grouped_by_month)) {
    monthly_stack <- terra::rast(files_grouped_by_month[[month_key]])
    
    # Calculate the mean across all years for this month
    mean_monthly_raster <- app(monthly_stack, fun = mean, na.rm = TRUE)
    
    # Get the number of days in the month
    days_in_month <- as.numeric(
      case_when(
        month_key == "02" ~ 28,
        month_key %in% c("04", "06", "09", "11") ~ 30,
        TRUE ~ 31
      )
    )
    
    # Convert daily average to monthly total
    mean_monthly_raster <- mean_monthly_raster * days_in_month
    
    # Create a descriptive filename for the output
    output_filename <- paste0(
      "Venezuela_Average_Precipitation_Month_",
      month_key,
      "_",
      start_year,
      "_",
      end_year,
      ".tif"
    )
    output_path <- file.path(dir_config$outcome, output_filename)
    
    # Write the resulting raster to disk
    writeRaster(mean_monthly_raster, output_path, overwrite = TRUE)
    
    message("Saved: ", output_path)
  }
}

print("--- All monthly averages have been calculated and saved. ---")

# //////////////////////////////////////////////////////////////////////////////
# SECTION 5: CLEANUP ----
# //////////////////////////////////////////////////////////////////////////////
message("Processing complete. Cleaning up environment.")
rm(list = ls(all.names = TRUE), envir = .GlobalEnv)
invisible(gc())
quit(save = "no", status = 0)