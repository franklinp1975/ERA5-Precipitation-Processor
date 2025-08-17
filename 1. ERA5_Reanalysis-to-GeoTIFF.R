# Title: ERA5 Monthly Precipitation Reanalysis
# Desc: Processes ERA5 total precipitation data from NetCDF to GeoTIFF format.
# Data Source: European Centre for Medium-Range Weather Forecasts

# //////////////////////////////////////////////////////////////////////////////
# SECTION 1: PACKAGE MANAGEMENT ----
# //////////////////////////////////////////////////////////////////////////////
# Load essential libraries for geospatial data and data manipulation
library(terra)   # For raster and vector operations
library(sf)      # For simple features vector data
library(dplyr)   # For data manipulation
library(stringr) # For string operations

# //////////////////////////////////////////////////////////////////////////////
# SECTION 2: CONFIGURATION ----
# //////////////////////////////////////////////////////////////////////////////
# Define and set the main project directory
main_dir <- file.path("C:", "CopernicusAnalyzer")
if (!dir.exists(main_dir)) {
  stop("Main directory does not exist: ", main_dir)
}
setwd(main_dir)

# Define core project paths
dir_config <- list(
  aoi    = file.path(main_dir, "AOI"),
  input  = file.path(main_dir, "Input"),
  output = file.path(main_dir, "Outcome")
)

# Ensure output directory exists (creates if missing)
if (!dir.exists(dir_config$output)) {
  dir.create(dir_config$output, recursive = TRUE, showWarnings = FALSE)
}

# Define processing parameters
variable_name <- "TotalPrecipitation"
# Unit conversion factor from meters to millimeters
conversion_factor <- 1000

# //////////////////////////////////////////////////////////////////////////////
# SECTION 3: DATA LOADING AND PREPARATION ----
# //////////////////////////////////////////////////////////////////////////////
# 3.1 Locate input files
nc_file <- list.files(
  path = dir_config$input,
  pattern = "TotalPrecipitation\\.nc$",
  full.names = TRUE
)
if (length(nc_file) == 0) {
  stop("No NetCDF file found in the input directory.")
}

# 3.2 Load the Area of Interest (AOI) vector file
aoi_file <- list.files(dir_config$aoi, full.names = TRUE)
if (length(aoi_file) == 0) {
  stop("No AOI file found in the AOI directory.")
}
aoi_vector <- sf::st_read(dsn = aoi_file, quiet = TRUE) |>
  terra::vect()

# 3.3 Load and process the ERA5 precipitation raster
precipitation_raster <- terra::rast(nc_file) |>
  terra::crop(aoi_vector) |>    # Crop to the AOI extent
  terra::mask(aoi_vector)       # Mask to the AOI shape

# Convert units from meters to millimeters
precipitation_raster <- precipitation_raster * conversion_factor

# 3.4 Handle NoData values
# The NoData value is a large number used to indicate missing data.
nodata_value <- 3.4028234663852886E38
precipitation_raster[precipitation_raster == nodata_value] <- NA

# //////////////////////////////////////////////////////////////////////////////
# SECTION 4: TEMPORAL PROCESSING AND EXPORT ----
# //////////////////////////////////////////////////////////////////////////////
message("Processing and exporting monthly rasters...")
num_layers <- terra::nlyr(precipitation_raster)

# Loop through each monthly layer
for (i in 1:num_layers) {
  # Extract the current layer
  current_raster <- precipitation_raster[[i]]
  
  # Get the timestamp from the layer name
  seconds_since_epoch <- as.numeric(gsub(".*=", "", names(current_raster)))
  
  # Convert to a date object
  date <- as.POSIXct(seconds_since_epoch, origin = "1970-01-01", tz = "UTC")
  
  # Format the date to extract year, month, and day
  year  <- format(date, "%Y")
  month <- format(date, "%m")
  day   <- format(date, "%d") # Day is always 01 for monthly data
  
  # Construct the output filename
  output_filename <- paste(
    c("ERA5", variable_name, year, month, "tif"), 
    collapse = "."
  )
  output_path <- file.path(dir_config$output, output_filename)
  
  # Write the raster to a GeoTIFF file
  terra::writeRaster(current_raster, filename = output_path, overwrite = TRUE)
}

message("Processing complete.")

# //////////////////////////////////////////////////////////////////////////////
# SECTION 5: CLEANUP ----
# //////////////////////////////////////////////////////////////////////////////
rm(list = ls())
invisible(gc())
quit(save = "no", status = 0)