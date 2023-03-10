plotWithHighlights <- function(x, y, status=NULL, values=NULL, hl.pch=16, hl.col=NULL, hl.cex=1, legend="topright", bg.pch=16, bg.col="black", bg.cex=0.3, pch=NULL, col=NULL, cex=NULL, ...)
#	Scatterplot with color and size highlighting for special groups of points.

#	Replaces the earlier function .plotMAxy, which in turn was based on the original plotMA
#	that was created by Gordon Smyth 7 April 2003 and modified by James Wettenhall 27 June 2003.

#	Gordon Smyth
#	Created 18 Sep 2014. Last modified 12 June 2020.
{
#	If no status information, just plot all points normally
	if(is.null(status) || all(is.na(status))) {
		plot(x,y,pch=bg.pch,col=bg.col,cex=bg.cex,...)
		return(invisible())
	}
#	From here, status is not NULL and not all NA

#	If values are not set as an argument, then create an appropriate vector.
#	There are three possibilities:
#	(a) values and plotting parameters can be passed as attributes of status;
#	(b) status may be a TestResults object;
#	(c) otherwise, the most frequent status value is used as background and all other values are highlighted.
	if(is.null(values)) {
		if(is.null(attr(status,"values"))) {
			if(is(status,"TestResults")) {
				if(ncol(status) > 1L) stop("status has more than one column")
				Values <- c(-1L,0L,1L)
				Labels <- c("Down","NotSig","Up")
				f <- factor(status@.Data,levels=Values)
				levels(f) <- Labels
				status <- as.character(f)
				values <- c("Up","Down")
				if(is.null(hl.col)) hl.col <- c("red","blue")
			} else {
#				Default is to set the most frequent status value as background,
#				and to highlight other status values in decreasing order of frequency
				status.values <- names(sort(table(status),decreasing=TRUE))
				values <- status.values[-1]
			}
		} else {
#			Use values and graphics parameters set as attributes by controlStatus()
			values <- attr(status,"values")
			if(!is.null(attr(status,"pch"))) hl.pch <- attr(status,"pch")
			if(!is.null(attr(status,"col"))) hl.col <- attr(status,"col")
			if(!is.null(attr(status,"cex"))) hl.cex <- attr(status,"cex")
		}
	}

	status <- as.character(status)
	values <- as.character(values)

#	If values has zero length, then just plot all points normally
	nvalues <- length(values)
	if(nvalues==0L) {
		plot(x,y,pch=bg.pch,col=bg.col,cex=bg.cex,...)
		return(invisible())
	}
#	From here, values has positive length

#	Allow legacy names 'pch', 'col' and 'cex' as alternatives to 'hl.pch', 'hl.col' and 'hl.cex'
	if(missing(hl.pch) && !is.null(pch)) hl.pch <- pch
	if(is.null(hl.col) && !is.null(col)) hl.col <- col
	if(missing(hl.cex) && !is.null(cex)) hl.cex <- cex

#	Setup plot axes
	plot(x,y,type="n",...)

#	Plot background (non-highlighted) points
	bg <- !(status %in% values)
	bg[is.na(bg)] <- TRUE
	nonhi <- any(bg)
	if(nonhi) points(x[bg],y[bg],pch=bg.pch[1],col=bg.col[1],cex=bg.cex[1])

#	Check graphical parameters for highlighted points
	hl.pch <- rep_len(unlist(hl.pch),length.out=nvalues)
	hl.cex <- rep_len(unlist(hl.cex),length.out=nvalues)
	if(is.null(hl.col)) hl.col <- nonhi + 1L:nvalues
	hl.col <- rep_len(unlist(hl.col),length.out=nvalues)

#	Plot highlighted points
	for (i in 1:nvalues) {
		sel <- status==values[i]
		points(x[sel],y[sel],pch=hl.pch[i],cex=hl.cex[i],col=hl.col[i])
	}

#	Check legend
	if(is.logical(legend)) {
		legend.position <- "topleft"
	} else {
		legend.position <- as.character(legend)
		legend <- TRUE
	}
	legend.position <- match.arg(legend.position,c("bottomright","bottom","bottomleft","left","topleft","top","topright","right","center"))

#	Plot legend
	if(legend) {
		if(nonhi) {
#			Include background value in legend
			bg.value <- unique(status[bg])
			if(length(bg.value) > 1) bg.value <- "Other"
			values <- c(bg.value,values)
			pch <- c(bg.pch,hl.pch)
			col <- c(bg.col,hl.col)
			cex <- c(bg.cex,hl.cex)
		} else {
			pch <- hl.pch
			col <- hl.col
			cex <- hl.cex
		}
		h <- cex>0.5
		cex[h] <- 0.5+0.8*(cex[h]-0.5)
		legend(legend.position,legend=values,pch=pch,,col=col,cex=0.9,pt.cex=cex)
	}

	invisible()
}
