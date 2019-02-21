# egm_r_tools
A simple set of R functions providing a workflow for reviewing EGM machine flux files.

## Usage

    source('EGM_flux_inspection.R')
	
    # This combines a set of .DAT files in a directory into a single dataframe
	data <- egm_file_merge('path/to/directory')
	
	# This opens a graphics window and starts a loop over all of the
	# flux records. Click in the bottom axis margin to set how many initial
	# values get ignored, on individual points to remove them and in the
	# top margin to exit.
	
	# The output is the same dataframe, but with added columns to indicate
	# which records have been scanned and which points are to be omitted.
	# The process is therefore resumable and records the decisions on a point
	# by point basis so they can be saved for reproducibility.
    data <- egm_inspect(data)
	
	# This takes the data frame of inspected records and returns the flux 
	# estimate for each record, omitting the points selected during inspection.
    flux <- egm_flux(data)
    
