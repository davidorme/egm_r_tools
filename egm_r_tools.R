library(MASS)
library(fields)

# Functions to import and merge a directory EGM DAT files, 
# manually inspect the values used to calculate flux for each record,
# and then produce a data frame of flux values from inspected records
#
# Example usage:
# data <- egm_file_merge('/path/to/directory')
# data <- egm_inspect(data)
# fluxes <- egm_flux(data)

egm_file_merge <- function(dir){
	
	# get the file paths and names
	files <- dir(path=dir, full.names=TRUE)
	srcfile <- basename(files)
	
	# load all the file contents, which includes two initial lines and 
	# a trailing record count that need to be deleted
	data <- lapply(files, scan, what='character', sep='\n')
	
	# trim that data
	data <- lapply(data, function(x) x[-c(1, 2, length(x))])
	
	# strip semi-colons (there is only one, in the header row)
	data <- lapply(data, function(x) sub(';', '', x))
	
	# run read.delim() over the trimmed contents to convert the text to a data frame
	data <- lapply(data, function(x) read.delim(text=x))
	
	# add the source file to each file
	data <- mapply(function(df, src) {df$Source <- src; return(df)},
				   data, srcfile, SIMPLIFY=FALSE)
	
	# stack them into a single dataframe
	data <- do.call(rbind, data)
	
	return(data)
}


egm_inspect <- function(data, start_time=9, CO2_min=300, CO2_max=1000){
	
	# internal function to plot the data for a particular record
	# and display the slope of the current set of points
	
	plot_record <- function(rec, idx, n_idx, start){
		
		par(mar=c(4,3,3,1), mgp=c(1.3, 0.4, 0))

		plot(CO2.Ref ~ Input.E, data=rec, 
			 col = ifelse(ignore, 'red', 'black'), 
			 pch = ifelse(ignore, 3, 1), 
			 xlab='Time', ylab=expression(CO[2]))
			 
		mod <- lm(CO2.Ref ~ Input.E, subset=! ignore, data=rec)
		abline(mod)
		abline(v=start, col='red', lty=2)
		
		# display information
		legend('topleft', sprintf('slope = %0.3f', coef(mod)[2]), bty='n')
		mtext(sprintf('Source: %s\nPlot: %i', rec$Source[1], rec$Plot[1]),
			  side=1, line=3, cex=0.8)
		mtext(sprintf('Inspecting %i of %i', idx, n_idx), side=3, line=2)
		mtext(paste0('Click in Time margin to adjust start time filter, ',
				     'click on point to ignore individual points,\n',
				     'press Escape to move to next record or ',
				     'click here to exit inspection'), side=3, line=0, cex=0.8)
			  
	}

	# Add two new columns to the data frame (ignore and scanned)
	# unless they already exist and someone is resuming an inspection
	ignore_found <- 'ignore' %in% names(data)
	scanned_found <- 'scanned' %in% names(data)
	
	if(xor(ignore_found, scanned_found)){
		stop('Data contains only one of scanned and ignore columns')
	} else if(!ignore_found & ! scanned_found){
		# insert the basic filter for all records
		data$ignore <- with(data, (Input.E < start_time) | 
								  (CO2.Ref < CO2_min) | 
								  (CO2.Ref > CO2_max))
		data$scanned <- FALSE		
	}
	
	# Identify the different recordings by using the unique combination
	# of the plot number and the source file, retaining the scanned status
	recs <- unique(subset(data, select=c(Plot, Source, scanned)))
	
	# remove already scanned records
	recs <- subset(recs, ! scanned)
	n_recs <- nrow(recs)
	
	if(n_recs == 0){
		stop('Records all scanned')
	}
	
	# setup a monitor variable that tracks if the user has clicked
	# in the top margin to exit from the record loop and start the
	# record counter
	exit <- FALSE
	idx <- 1
	
	while(! exit & idx <= n_recs){
		
		# identify which rows belong to this record and extract
		this_rec_rows <- which(data$Plot == recs$Plot[idx] &
							   data$Source == recs$Source[idx])
		
		this_rec <- data[this_rec_rows,]
		
		# track the local value of start_time
		this_start_time <- start_time
		
		# now provide a loop allowing the user to kill more points
		# which can be terminated by pressing escape to break out
		# from the locator() calls (returning a null pointxy)
		plot_record(this_rec, idx, n_recs, this_start_time)				   
		pointxy <-  locator(1)

		while(! is.null(pointxy)){
			
			# Three options:
			if(pointxy$y > par('usr')[4]){
				# i) user clicked in top margin so set flags to exit inspection				
				exit <- TRUE
				pointxy <- NULL
			} else if(pointxy$y < par('usr')[3]){ 
				# ii) user clicked in bottom margin, which updates the start_time
				#     filter of the initial values to ignore
				
				# clear existing start filter
				this_rec$ignore[this_rec$Input.E < this_start_time] <- FALSE
				# implement new start filter
				this_rec$ignore[this_rec$Input.E < pointxy$x] <- TRUE
				this_start_time <- pointxy$x
				
				# replot the data and wait for the next point
				plot_record(this_rec, idx, n_recs, this_start_time)				   
				pointxy <-  locator(1)
			} else {
				# iii) otherwise find the closest point to the mouse click
				distxy <- rdist(t(pointxy), this_rec[, c('Input.E', 'CO2.Ref')])
				
				# invert the ignore status for this point
		 		this_rec$ignore[which.min(distxy)] <- ! this_rec$ignore[which.min(distxy)]
				
				# replot the data and wait for the next point
				plot_record(this_rec, idx, n_recs, this_start_time)				   
				pointxy <-  locator(1)
			}
		}

		# now overwrite the ignore values in the rows in the full data
		# with the set created by the user and set the scanned rows to TRUE
		data$ignore[this_rec_rows] <- this_rec$ignore
		data$scanned[this_rec_rows] <- TRUE
		
		# move to next record
		idx <- idx + 1	
	}
	
	return(data)

}


egm_flux <- function(data){
	
	if(! all(data$scanned)){
		stop('Not all records have been scanned')
	}
	
	# Extract up a dataframe of the individual records and add the fields to populate
	recs <- subset(data, RecNo == 1, select=c(Source, Plot, Month, Day, Hour, Min))
	recs$slope <- NA
	recs$n_points <- NA
	recs$n_used <- NA
	
	# Populate the fields
	for(idx in seq_len(nrow(recs))){
		
		rec <- data[data$Plot == recs$Plot[idx] &
					data$Source == recs$Source[idx], ]
		
		mod <- lm(CO2.Ref ~ Input.E, subset=! ignore, data=rec)
		
		recs$slope[idx] <- coef(mod)[2]
		recs$n_points[idx] <- nrow(rec)
		recs$n_used[idx] <- length(resid(mod))

	}
	
	return(recs)
}
