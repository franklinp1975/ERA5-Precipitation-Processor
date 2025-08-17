#### **Repository Name:** `ERA5-Precipitation-Processor`

#### **Project Description**

This repository contains a suite of R scripts designed for the post-processing and analysis of ERA5 reanalysis data, with a specific focus on total precipitation. The scripts automate key steps in the data workflow, from converting raw NetCDF files to GeoTIFFs to performing statistical aggregations and generating site-specific reports.

**Core functionalities include:**

  * Converting monthly NetCDF data to a series of individual monthly GeoTIFF raster files.
  * Generating a time series of area-averaged monthly precipitation values for a defined Area of Interest (AOI).
  * Aggregating monthly GeoTIFFs to produce annual total precipitation rasters.
  * Extracting and reporting precipitation values for specific point locations (sites).
  * Calculating long-term average rasters for both annual and monthly time periods.

The scripts are written in R, leveraging powerful geospatial libraries such as `terra` and `sf` for efficient data handling. They are designed to be modular and easy to adapt for different variables or geographic regions.

#### **License**

This project is licensed under the **MIT License**.


#### **How to Use the Scripts**

**1. Setup**

  * **Prerequisites**: Ensure you have R and RStudio installed on your system.
  * **Directory Structure**: Create the following directory structure in your main project folder (e.g., `C:/ONCC_ERA5_postprocessing`):
      * `AOI`: Place your AOI shapefiles here (e.g., `Falcon.shp`).
      * `Input`: Place your raw ERA5 NetCDF file (`TotalPrecipitation.nc`) and any daily/monthly GeoTIFFs here.
      * `Input_sites`: Place your site location Excel file (`Sites.xlsx`) here.
      * `Outcome`: This folder will store the final CSV reports.
      * `Raster_outcome`: This folder will store the aggregated raster files.
      * `Aggregated_outcome`: This folder will store the long-term average rasters.

**2. Running the Scripts**

Run the scripts in the following order:

  * **`1. ERA5_Reanalysis-to-GeoTIFF.R`**: This script is the first step. It converts your raw NetCDF data into individual monthly GeoTIFF files, which are saved in the `Input` directory.
  * **`2. ERA5_Precipitation_Summary.R`**: Run this script to generate a monthly time series of area-averaged precipitation (saved as a CSV in `Outcome`) and to create annual total precipitation rasters (saved in `Raster_outcome`).
  * **`3. ERA5_Site-Report.R`**: This script uses the monthly GeoTIFFs from the `Input` directory and the `Sites.xlsx` file to generate individual site-level CSV reports, which are saved in `Sites_outcome`.
  * **`4. ERA5_RasterAggregator.R`**: This final script uses the annual and monthly rasters to create long-term average rasters for the defined time periods, saving the results in the `Aggregated_outcome` folder.
