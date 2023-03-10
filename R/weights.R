#  Quality weights

wtarea <- function(ideal=c(160,170))
#	Quality weight function based on spot area from SPOT output
#	Gordon Smyth
#	9 March 2003.  Last revised 17 May 2019.

function(spot) {
	e <- range(ideal)
	if(e[1] <= 0) {
		warning("ideal areas should be positive")
		e <- pmax(e,1)
	}
	x <- c(-Inf,0,e,sum(e),Inf)
	y <- c(0,0,1,1,0,0)
	approx(x,y,xout=spot[,"area"],ties=list("ordered",mean))$y
}

wtflags <- function(weight=0,cutoff=0)
#	Quality weight function based on Flags from GenePix output
#	Gordon Smyth
#	9 March 2003.  Last revised 29 July 2006.

function(gpr) {
	flagged <- (gpr[,"Flags"] < cutoff)
	weight*flagged + !flagged
}

wtIgnore.Filter <- function(qta)
#	Quality weights based on Ignore Filter from QuantArray output
#	Gordon Smyth
#	23 May 2003.  Last modified 27 Sep 2003.
{
	qta[,"Ignore Filter"]
}

modifyWeights <- function(weights=rep(1,length(status)), status, values, multipliers)
#	Modify weights for given status values
#	Gordon Smyth
#	29 Dec 2003. Last modified 9 June 2020.
{
	status <- as.character(status)
	weights <- as.matrix(weights)
	values <- as.character(values)
	multipliers <- as.numeric(multipliers)
	if(length(status)!=nrow(weights)) stop("nrows of weights must equal length of status")
	nvalues <- length(values)
	if(length(multipliers)==1) multipliers <- rep_len(multipliers,nvalues)
	if(nvalues!=length(multipliers)) stop("no. values doesn't match no. multipliers")
	for (i in 1:nvalues) {
		g <- status==values[i]
		weights[g,] <- multipliers[i]*weights[g,]
	}
	weights
}

asMatrixWeights <- function(weights,dim=NULL)
#	Convert probe-weights or array-weights to weight matrix
#	Gordon Smyth
#	22 Jan 2006.  Last modified 10 July 2008.
{
	weights <- as.matrix(weights)
	if(is.null(dim)) return(weights)
	if(length(dim)<2) stop("dim must be numeric vector of length 2")
	dim <- round(dim[1:2])
	if(any(dim<1)) stop("zero or negative dimensions not allowed")
	dw <- dim(weights)
#	Full matrix already
	if(all(dw==dim)) return(weights)
	if(min(dw)!=1) stop("weights is of unexpected shape")
#	Row matrix of array weights
	if(dw[2]>1 && dw[2]==dim[2]) {
		weights <- matrix(weights,dim[1],dim[2],byrow=TRUE)
		attr(weights,"arrayweights") <- TRUE
		return(weights)
	}
	lw <- prod(dw)
#	Probe weights
	if(lw==1 || lw==dim[1]) return(matrix(weights,dim[1],dim[2]))
#	Array weights
	if(lw==dim[2]) {
		weights <- matrix(weights,dim[1],dim[2],byrow=TRUE)
		attr(weights,"arrayweights") <- TRUE
		return(weights)
	}
#	All other cases
	stop("weights is of unexpected size")
}

