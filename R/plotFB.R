plotFB <- function(x,...) UseMethod("plotFB")

plotFB.RGList <- function(x, array=1, lim="separate", pch=16, cex=0.3, xlab="log2 Background", ylab="log2 Foreground", main=colnames(x)[array], ...)
#	Foreground-background plot
#	Gordon Smyth
#	5 March 2006.  Last modified 5 April 2006.
{
	lim <- match.arg(lim,c("separate","common"))
	oldpar <- par(mfrow=c(1,2))
	on.exit(par(oldpar))
	x <- x[,array]
	g1 <- log2(x$Gb)
	g2 <- log2(x$G)
	r1 <- log2(x$Rb)
	r2 <- log2(x$R)
	if(lim=="separate") {
		lim1 <- lim2 <- NULL
	} else {
		lim1 <- range(c(g1,r1))
		lim2 <- range(c(g2,r2))
	}
	plot(g1,g2,xlim=lim1,ylim=lim2,pch=pch,cex=cex,xlab=xlab,ylab=ylab,main=paste(main,"Green"),...)
	abline(0,1,col="blue")
	plot(r1,r2,xlim=lim1,ylim=lim2,pch=pch,cex=cex,xlab=xlab,ylab="",main=paste(main,"Red"),...)
	abline(0,1,col="blue")
	invisible()
}

plotFB.EListRaw <- function(x, array=1, pch=16, cex=0.3, xlab="log2 Background", ylab="log2 Foreground", main=colnames(x)[array], ...)
#	Foreground-background plot
#	Gordon Smyth
#	13 November 2013.  Last modified 1 October 2019.
{
	x <- x[,array]
	b <- log2(x$Eb)
	f <- log2(x$E)
	plot(b,f,pch=pch,cex=cex,xlab=xlab,ylab=ylab,main=main,...)
	abline(0,1,col="blue")
	invisible()
}

plotFB.default <- function(x, ...)
{
	stop("No plotFB method defined for class ", class(x))
}