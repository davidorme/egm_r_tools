# egm_r_tools
A simple set of R functions providing a workflow for reviewing EGM machine flux files.

## Usage

First, use `source` to load the functions.

    source('Desktop/EGM_flux_inspection.R')

The `egm_file_merge` function takes a directory of EGM DAT files and loads
them all into a single dataframe, cropping the header and footer data.

	data <- egm_file_merge('Desktop/TFE_Carbon_Project/CO2')

The `egm_inspect` function takes the resulting data frame and displays
each EGM record in sequence. The plot window shows the initial slope,
along with the source file, the plot number of the record and a progress
counter across the total number of records.

    data <- egm_inspect(data, start_time=9, CO2_min=300, CO2_max=1000

The three other arguments set automatical exclusion filters: points up
to `start_time` to exclude short transient effects and extreme CO2 values.
Within the plot window, you can adjust which points are excluded. Click
in the Time axis to adjust the start time filter and click on individual
points to toggle whether they are excluded or not. When you have finished
with a particular record, press Escape to advance to the next.

Click on the three options at the top to go back to a previous record, 
skip a record without marking it as scanned or to quit from the function.

The output is the same dataframe, but with added columns to indicate
which records have been scanned and which points are to be omitted.
The process is therefore resumable and records the decisions on a point
by point basis so they can be saved for reproducibility.

Finally, the `egm_flux` function takes a data frame of inspected records
and returns the flux estimate for each record, given the points omitted 
during inspection.

    flux <- egm_flux(data)
   