#	READ.R

#	GAL FILES

readGAL <- function(galfile=NULL,path=NULL,header=TRUE,sep="\t",quote="\"",skip=NULL,as.is=TRUE,...) {
#	Read GenePix Array List (GAL) file
#	Gordon Smyth
#	1 Mar 2003.  Last revised 2 May 2005.

	if(is.null(galfile)) {
		if(is.null(path)) path <- "."
		galfile <- dir(path=path,pattern="\\.gal$")
		nfiles <- length(galfile)
		if(nfiles == 0) stop("Cannot find GAL file")
		if(nfiles > 1) {
			galfile <- galfile[1]
			warning(paste("More than one GAL file found. Reading",galfile))
		}
	}
	if(!is.null(path)) galfile <- file.path(path,galfile)
	if(is.null(skip)) {
		chunk <- readLines(galfile,n=100)
		skip <- intersect(grep("Name",chunk), grep("ID",chunk)) - 1
		n <- length(skip)
		if(n == 0) stop("Cannot find ID and Name columns in GAL file")
		if(n > 1) stop("Multiple lines with ID and Name labels")
	}
	gal <- read.table(galfile,header=header,sep=sep,quote=quote,skip=skip,as.is=as.is,comment.char="",...)
	nblocks <- max(gal$Block,na.rm=TRUE)
	ncolumns <- max(gal$Column,na.rm=TRUE)
	nrows <- max(gal$Row,na.rm=TRUE)
	spotindex <- ((gal$Block-1)*nrows+(gal$Row-1))*ncolumns+gal$Column
	if(any(diff(spotindex)<0)) {
		o <- order(spotindex)
		gal <- gal[o,]
	}
	gal
}

strsplit2 <- function(x, split, ...) {
#	Split vector of composite names into matrix of simple names
#	Gordon Smyth
#	8 May 2003 (originally called splitName).  Last modified 22 October 2009.

	x <- as.character(x)
	n <- length(x)
	s <- strsplit(x,split=split,...)
	nc <- unlist(lapply(s,length))
	out <- matrix("",n,max(nc))
	for (i in 1:n) {
		if(nc[i]) out[i,1:nc[i]] <- s[[i]]
	}
	out
}

getLayout <- function(gal,guessdups=FALSE)
#	Guess print layout from a gene list including Block, Row and Column indices
#	as for a GenePix Allocation List (GAL)
#	Gordon Smyth
#	7 Apr 2003.  Last revised 4 June 2004.
{
	if( !all(c("Block","Row","Column") %in% names(gal)) ) stop("gal needs to have columns Block, Row and Column")
	ngrid.r <- max(gal$Block,na.rm=TRUE)
	if(ngrid.r %% 4 == 0) {
		ngrid.c <- 4
		ngrid.r <- ngrid.r/4
	} else {
		ngrid.c <- 1
	}
	nspot.r <- max(gal$Row,na.rm=TRUE)
	nspot.c <- max(gal$Column,na.rm=TRUE)
	printer <- list(
		ngrid.r=as.integer(ngrid.r),
		ngrid.c=as.integer(ngrid.c),
		nspot.r=as.integer(nspot.r),
		nspot.c=as.integer(nspot.c)
	)
	if(guessdups) {
		ID <- paste(gal$ID,gal$Name)
		printer <- c(printer,getDupSpacing(ID))
	}
	structure(printer,class="PrintLayout")
}

getDupSpacing <- function(ID)
#  Determine ndups and spacing values for a set of IDs.
#  Assumes at least one probe with a unique ID, from which
#  spacing can be determined.
#  Gordon Smyth
#  Created 15 Oct 2008. Last revised 12 Apr 2020.
{
	if(anyNA(ID)) return(list(ndups=NA,spacing=NA))
	ID <- as.factor(ID)
	nspots <- length(ID)

	tab <- table(ID)
	wm <- which.min(tab)
	ndups <- as.vector(tab[wm])
	if(any(tab %% ndups !=0)) ndups <- 1

	if(ndups==1) return(list(ndups=ndups,spacing=1))

	d <- diff(which(ID==names(tab)[wm]))
	if(diff(range(d))==0)
		return(list(ndups=ndups,spacing=d[1]))
	else
		return(list(ndups=1,spacing=1))
}

getLayout2 <- function(galfile)
#	Guess print layout from header of GenePix Allocation List (GAL) file
#	using block position and dimension information
#	James Wettenhall
#	4 June 2004
{
	if(missing(galfile))
		galfile <- dir(pattern="\\.gal$")[1]
	if(is.na(galfile) || length(galfile)==0 || !is.character(galfile) || nchar(galfile)==0)
		stop("Please specify a gal file name.")
	galHeader <- readLines(galfile,n=100)
	blockLines <- galHeader[grep("Block[0-9]",galHeader)]
	if(length(blockLines)==0)
		stop("Invalid or missing header in GAL file.")
	blockLines <- gsub("[ \t]*$","",blockLines) # Removing trailing whitespace (e.g. tabs)
	numBlocks <- length(blockLines)
	if(length(grep(",",blockLines)))
		delimiter <- ","
	else
		delimiter <- "\t" 
	blockCoordinates <- 
		t(matrix(as.numeric(unlist(strsplit(
		gsub("[ \t]*$","",gsub("\\\"","",gsub("Block[0-9]+=[ \t]*","",
		galHeader[grep("Block[0-9]",galHeader)]))),delimiter,fixed=TRUE))),
		ncol=numBlocks))
	ngrid.r	<- length(table(blockCoordinates[,2]))
	ngrid.c <- as.numeric(table(blockCoordinates[,2])[1])
	nspot.r <- blockCoordinates[1,6]
	nspot.c <- blockCoordinates[1,4]

	printer <- list(ngrid.r=ngrid.r,ngrid.c=ngrid.c,nspot.r=nspot.r,nspot.c=nspot.c)
	structure(printer, class = "PrintLayout")
}

readTargets <- function(file="Targets.txt",path=NULL,sep="\t",row.names=NULL,quote="\"",...)
#	Read data frame of target information
#	Gordon Smyth
#	19 Oct 2003.  Last modified 24 Jan 2013.
{
	if(!is.null(path)) file <- file.path(path,file)
	tab <- read.table(file,header=TRUE,stringsAsFactors=FALSE,sep=sep,quote=quote,fill=TRUE,...)
#	if(!all(c("Cy3","Cy5") %in% names(tab))) warning("File should contain columns: Cy3 and Cy5")
	if(is.null(row.names)) {
		rn <- tab[["Label"]]
		if(anyDuplicated(rn)) rn <- NULL
		if(is.null(rn)) rn <- tab[["Labels"]]
		if(anyDuplicated(rn)) rn <- NULL
		if(is.null(rn)) rn <- tab[["FileName"]]
		if(!is.null(rn)) rn <- removeExt(rn)
		if(anyDuplicated(rn)) rn <- NULL
		if(!is.null(rn)) row.names(tab) <- rn
	} else {
		row.names <- as.character(row.names)
		if(row.names %in% names(tab)) row.names(tab) <- tab[[row.names]]
	}
	tab
}

readSpotTypes <- function(file="SpotTypes.txt",path=NULL,sep="\t",check.names=FALSE,...)
#	Read regexp for spot types
#	Gordon Smyth following idea of James Wettenhall
#	19 Oct 2003.  Last modified 16 Feb 2004.
{
	if(!is.null(path)) file <- file.path(path,file)
	tab <- read.table(file,header=TRUE,as.is=TRUE,sep=sep,quote="\"",check.names=check.names,...)
	if(ncol(tab)<2) stop("File should contain at least two columns")
	tab
}

controlStatus <- function(types, genes, spottypecol="SpotType", regexpcol, verbose=TRUE)
#	Set status of each spot (row)
#	Gordon Smyth
#	19 Oct 2003.  Last modified 9 Jun 2020.
{
#	Check types
	if(!is.data.frame(types)) stop("types must be a data.frame")
	cntypes <- colnames(types)
	if(is.null(cntypes)) stop("types must have column names")

#	Check genes
	if (is(genes,"RGList") || is(genes,"MAList") || is(genes,"MArrayLM") || is(genes,"EListRaw") || is(genes,"EList")) genes <- genes$genes
	if(!is.data.frame(genes)) stop("genes must be a data.frame")
	cngenes <- colnames(genes)
	if(is.null(cngenes)) stop("genes must have column names")

#	Check have at least one row
	ntypes <- nrow(types)
	nspots <- nrow(genes)
	if(ntypes==0 || nspots==0) return(NULL)

#	Any undo conversion of types to factors
	for (j in cntypes) {
		x <- types[,j]
		if(is.factor(x) && is.character(levels(x))) types[,j] <- as.character(x)
	}

#	Check spottypecol
	if(is.numeric(spottypecol)) spottypecol <- cntypes[spottypecol[1]]
	if(is.null(spottypecol) || !is.character(spottypecol) || !is.element(spottypecol,cntypes)) stop("spottypecol not valid column of types")

#	Find common columns between types and genes
	if(!missing(regexpcol) && is.numeric(regexpcol)) regexpcol <- cntypes[regexpcol]
	cntypes <- setdiff(cntypes,spottypecol)
	if(missing(regexpcol)) {
		incommon <- (cntypes %in% cngenes)
		if(!length(incommon)) stop("types and genes have no column names in common")
		regexpcol <- cntypes[incommon]
	} else {
		if(!all(is.element(regexpcol,cntypes) & is.element(regexpcol,cngenes)))
			stop("types and genes must both contain regexpcol colums")
	}
	if(verbose) cat("Matching patterns for:",regexpcol,"\n")

#	Simplified regular expressions
	for (j in regexpcol) {
		types[,j] <- paste("^",gsub("\\*","\\.*",types[,j]),"$",sep="")
		genes[,j] <- as.character(genes[,j])
	}

#	Set spot status
	spottype <- as.character(types[,spottypecol])
	if(default <- all(types[1,regexpcol]=="*")) {
		status <- rep_len(spottype[1],nspots)
		if(ntypes==1) return(status)
	} else
		status <- character(nspots)
	nregexp <- length(regexpcol)
	for (i in (1+default):ntypes) {
		sel <- grep(types[i,regexpcol[1]],genes[,regexpcol[1]])
		if(nregexp>1) for (j in regexpcol[-1]) sel <- intersect(sel,grep(types[i,j],genes[,j]))
		status[sel] <- spottype[i]
		if(verbose) cat("Found",length(sel),spottype[i],"\n")
	}

#	Set attributes
	attr(status,"values") <- spottype
	cntypes <- setdiff(cntypes,regexpcol)
	npar <- length(cntypes)
	if(npar) {
		parnames <- sub("^Color$","col",cntypes)
		for (j in 1:npar) attr(status,parnames[j]) <- types[,cntypes[j]]
	}
	if(verbose) cat("Setting attributes: values",cntypes,"\n")
	status
}

removeExt <- function(x, sep=".")
#	Remove any common extension from a vector of file names
#	Gordon Smyth
#	19 July 2002.  Last modified 8 Jan 2016.
{
	x <- as.character(x)
	n <- length(x)
	if(length(grep(sep,x)) < n) return(x)
	sep <- protectMetachar(sep)
	RegExpr <- paste0("(.*)", sep, "(.*)$")
	ext <- sub(RegExpr, "\\2", x)
	if(all(ext[1] == ext))
		return(sub(RegExpr,"\\1",x))
	else
		return(x)
}

trimWhiteSpace <- function(x)
#	Trim white space from start and end of character strings
#	Tim Beissbarth and Gordon Smyth
#	7 June 2004
{
	sub("[ \t\n\r]*$", "", sub("^[ \t\n\r]*", "", x))
}

protectMetachar <- function(x)
#	Insert backslashs before metacharacters (to allow them to be included in search strings)
#	Note that backslashs themselves are not handled
#	Gordon Smyth
#	9 June 2004. Last modified 5 Jan 2007.
{
	x <- gsub("\\.", "\\\\.", x)
	x <- gsub("\\|", "\\\\|", x)
	x <- gsub("\\(", "\\\\(", x)
	x <- gsub("\\)", "\\\\)", x)
	x <- gsub("\\[", "\\\\[", x)
	x <- gsub("\\{", "\\\\{", x)
	x <- gsub("\\^", "\\\\^", x)
	x <- gsub("\\$", "\\\\$", x)
	x <- gsub("\\*", "\\\\*", x)
	x <- gsub("\\+", "\\\\+", x)
	x <- gsub("\\?", "\\\\?", x)
	x
}

#	LAYOUT FUNCTIONS

spotc <- function(layout) {
#	GKS  24 Nov 2002
	rep(1:layout$nspot.c, length=prod(unlist(layout)))
}

spotr <- function(layout) {
#	GKS  24 Nov 2002
	rep(1:layout$nspot.r, times=layout$ngrid.r*layout$ngrid.c, each=layout$nspot.c)
}

gridc <- function(layout) {
#	GKS  24 Nov 2002
	rep(1:layout$ngrid.c, times=layout$ngrid.r, each=layout$nspot.c*layout$nspot.r)
}

gridr <- function(layout) {
#	GKS  24 Nov 2002
	rep(1:layout$ngrid.r, each=layout$nspot.c*layout$nspot.r*layout$ngrid.c)
}

printorder <- function(layout, ndups=1, spacing="columns", npins, start="topleft") {
#	Identify order in which spots were printed and from which 384-well plate
#	Gordon Smyth
#	2 May 2003.  Last revised 28 Dec 2003.

	if(is(layout,"RGList") || is(layout,"MAList")) {
		if(missing(ndups) && !is.null(layout$printer$ndups)) ndups <- layout$printer$ndups
		if(missing(spacing) && !is.null(layout$printer$spacing)) spacing <- layout$printer$spacing
		if(missing(npins) && !is.null(layout$printer$npins)) npins <- layout$printer$npins
		if(missing(start) && !is.null(layout$printer$start)) start <- layout$printer$start
		layout <- layout$printer
	}
	ngrid.r <- layout$ngrid.r
	ngrid.c <- layout$ngrid.c
	nspot.r <- layout$nspot.r
	nspot.c <- layout$nspot.c
	ngrids <- ngrid.r * ngrid.c
	nspots <- nspot.r * nspot.c
	if(is(spacing,"numeric")) {
		if(spacing==1) spacing <- "columns"
		if(spacing==layout$ngrid.c) spacing <- "rows"
		if(spacing==ngrids * nspots %/% 2) spacing <- "topbottom"
		if(is(spacing,"numeric")) stop("spacing not recognized choice")
	}
	spacing <- match.arg(spacing,c("columns","rows","topbottom"))
	start <- match.arg(start,c("topleft","topright"))

#	DNA plates assumed to have 384 wells
	nwell.r <- 16
	nwell.c <- 24
	nwells <- nwell.r * nwell.c

#	FIRST DO ALL FOR NDUPS=1
	if(spacing=="columns") {
		nspot.c <- nspot.c %/% ndups
		nspots <- nspots %/% ndups
	}
	if(spacing=="rows") {
		nspot.r <- nspot.r %/% ndups
		nspots <- nspots/ndups
	}
	if(spacing=="topbottom") {
		ngrid.r <- ngrid.r %/% ndups
		ngrids <- ngrids %/% ndups
	}

#	Pin columns assumed to be same as grid columns
	if(missing(npins)) npins <- ngrid.r * ngrid.c
	npin.c <- ngrid.c
	npin.r <- npins %/% npin.c
	pin.c <- rep(1:npin.c, times = npin.r, each = nspots)
	pin.r <- rep(1:npin.r, each = npin.c * nspots)

#	PRINTORDER FOR NPINS=NGRIDS
	spot.c <- rep(1:nspot.c, times = npins * nspot.r)
	spot.r <- rep(1:nspot.r, times = npins, each = nspot.c)
	po <- switch(start,
		topleft=nspot.c*(spot.r-1)+spot.c,
		topright=nspot.c*(spot.r-1)+nspot.c-spot.c+1
	)

#	PRINTORDER FOR NPINS<NGRIDS
	if(ngrids %% npins != 0) stop("ngrids not a multiple of npins")
	m <- ngrids %/% npins
	if(m > 1) po <- rep(po,m) + nspots * rep(0:(m-1), each = npins * nspots)

#	Plate position
	ndips <- nwells %/% npins
	plate <- 1 + (po-1) %/% ndips
	platedip <- 1 + (po-1) %% ndips
	plateblock.r <- 1 + (platedip-1) %/% (nwell.c %/% npin.r)
	plateblock.c <- 1 + (platedip-1) %% (nwell.c %/% npin.r)
	plate.r <- (plateblock.r-1) * npin.c + npin.c - pin.c + 1
	plate.c <- (plateblock.c-1) * npin.r + pin.r

#	NOW ADJUST FOR NDUPS>1
	if(ndups>1) {
		dupseq <- 1:ndups
		if(start=="topright" && spacing=="columns") dupseq <- rev(dupseq)	
		spacing <- getSpacing(spacing,layout)
		ngenes <- length(po)
		po <- rep(po,each=ndups)
		dim(po) <- c(ndups,spacing,ngenes/spacing)
		po <- po-1+dupseq/ndups
		po <- round(po*ndups)
		po <- as.vector(aperm(po,c(2,1,3)))
		adups <- function(x) {
			x <- rep(x,each=ndups)
			dim(x) <- c(ndups,spacing,ngenes/spacing)
			as.vector(aperm(x,c(2,1,3)))
		}
		plate <- adups(plate)
		plate.r <- adups(plate.r)
		plate.c <- adups(plate.c)
	}

#	Final output
	platedigits <- 1+floor(log(ngrids*nspots/nwells,10))
	platepos <- paste("p",formatC(plate, width=platedigits, flag = "0"), LETTERS[plate.r], formatC(plate.c, width=2, flag = "0"), sep="")
	list(printorder=po, plate=plate, plate.r=plate.r, plate.c=plate.c, plateposition=platepos)
}

getSpacing <- function(spacing, layout)
#	Convert character to integer duplicating spacing
#	Gordon Smyth
#	15 Dec 2003.  Last revised 15 Oct 2008.
{
	if(is(spacing,"numeric")) return(spacing)
	spacing <- match.arg(spacing, c("columns","rows","subarrays","topbottom"))
	switch(spacing,
		columns=1,
		rows=layout$nspot.c,
		subarrays=layout$ngrid.r/layout$ndups*layout$ngrid.c*layout$nspot.r*layout$nspot.c,
		topbottom=layout$ngrid.r/2*layout$ngrid.c*layout$nspot.r*layout$nspot.c
	)
}
