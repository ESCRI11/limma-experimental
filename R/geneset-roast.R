##  ROAST.R

setClass("Roast",
#  rotation gene set test
representation("list")
)

setMethod("show","Roast",
#  Di Wu, Gordon Smyth
#  14 May 2010.  Last modified 19 May 2010.
function(object) print(object$p.value)
)

roast <- function(y,...) UseMethod("roast")

roast.default <- function(y,index=NULL,design=NULL,contrast=ncol(design),geneid=NULL,set.statistic="mean",gene.weights=NULL,var.prior=NULL,df.prior=NULL,nrot=1999,approx.zscore=TRUE,legacy=FALSE,...)
# Rotation gene set testing for linear models
# Gordon Smyth and Di Wu
# Created 24 Apr 2008.  Last modified 22 July 2019.
{
#	Check index
	if(is.list(index)) return(mroast(y=y,index=index,design=design,contrast=contrast,set.statistic=set.statistic,gene.weights=gene.weights,var.prior=var.prior,df.prior=df.prior,nrot=nrot,approx.zscore=approx.zscore,legacy=legacy,...))

#	Partial matching of extra arguments
#	array.weights and trend.var included for (undocumented) backward compatibility with code before 9 May 2016.
	Dots <- list(...)
	PossibleArgs <- c("array.weights","weights","block","correlation","trend.var","robust","winsor.tail.p")
	if(!is.null(names(Dots))) {
		i <- pmatch(names(Dots),PossibleArgs)
		names(Dots) <- PossibleArgs[i]
	}

#	Defaults for extra arguments
	if(is.null(Dots$trend.var)) {
		Dots$trend <- FALSE
	} else {
		Dots$trend <- Dots$trend.var
		Dots$trend.var <- NULL
	}
	if(is.null(Dots$robust)) Dots$robust <- FALSE
	if(Dots$robust & is.null(Dots$winsor.tail.p)) Dots$winsor.tail.p <- c(0.05,0.1)
	if(!is.null(Dots$block) & is.null(Dots$correlation)) stop("Intra-block correlation must be specified")

#	Covariate for trended eBayes
	covariate <- NULL
	if(Dots$trend) covariate <- rowMeans(as.matrix(y))

#	Compute effects matrix (with df.residual+1 columns)
	Effects <- .lmEffects(y=y,design=design,contrast=contrast,
		array.weights=Dots$array.weights,
		weights=Dots$weights,
		block=Dots$block,
		correlation=Dots$correlation)
	ngenes <- nrow(Effects)

#	Empirical Bayes posterior variances
	s2 <- rowMeans(Effects[,-1L,drop=FALSE]^2)
	df.residual <- ncol(Effects)-1L
	if(is.null(var.prior) || is.null(df.prior)) {
		sv <- squeezeVar(s2,df=df.residual,covariate=covariate,robust=Dots$robust,winsor.tail.p=Dots$winsor.tail.p)
		var.prior <- sv$var.prior
		df.prior <- sv$df.prior
		var.post <- sv$var.post
	} else {
		var.post <- .squeezeVar(var=s2,df=df.residual,var.prior=var.prior,df.prior=df.prior)
	}

#	Check geneid (can be a vector of gene IDs or an annotation column name)
	if(is.null(geneid)) {
		geneid <- rownames(Effects)
	} else {
		geneid <- as.character(geneid)
		if(length(geneid)==1) 
			geneid <- as.character(y$genes[,geneid])
		else
			if(length(geneid) != ngenes) stop("geneid vector should be of length nrow(y)")
	}

#	Subset to gene set
	if(!is.null(index)) {
		if(is.factor(index)) index <- as.character(index)
		if(is.character(index)) index <- which(geneid %in% index)
		Effects <- Effects[index,,drop=FALSE]
		if(length(var.prior)>1) var.prior <- var.prior[index]
		if(length(df.prior)>1) df.prior <- df.prior[index]
		var.post <- var.post[index]
	}
	NGenesInSet <- nrow(Effects)

#	length(gene.weights) can nrow(y) or NGenesInSet
	lgw <- length(gene.weights)
	if(!(lgw %in% c(0L,NGenesInSet,ngenes))) stop("length of gene.weights doesn't agree with number of genes or size of set")
	if(lgw > NGenesInSet) gene.weights <- gene.weights[index]

	.roastEffects(Effects,gene.weights=gene.weights,set.statistic=set.statistic,var.prior=var.prior,df.prior=df.prior,var.post=var.post,nrot=nrot,approx.zscore=approx.zscore,legacy=legacy)
}


mroast <- function(y,...) UseMethod("mroast")

mroast.default <- function(y,index=NULL,design=NULL,contrast=ncol(design),geneid=NULL,set.statistic="mean",gene.weights=NULL,var.prior=NULL,df.prior=NULL,nrot=1999,approx.zscore=TRUE,legacy=FALSE,adjust.method="BH",midp=TRUE,sort="directional",...)
#  Rotation gene set testing with multiple sets
#  Gordon Smyth and Di Wu
#  Created 28 Jan 2010. Last revised 9 Jun 2020.
{
#	Partial matching of extra arguments
	Dots <- list(...)
	PossibleArgs <- c("array.weights","weights","block","correlation","trend","robust","winsor.tail.p")
	if(!is.null(names(Dots))) {
		i <- pmatch(names(Dots),PossibleArgs)
		names(Dots) <- PossibleArgs[i]
	}

#	Defaults for extra arguments
	if(is.null(Dots$trend)) Dots$trend <- FALSE
	if(is.null(Dots$robust)) Dots$robust <- FALSE
	if(Dots$robust & is.null(Dots$winsor.tail.p)) Dots$winsor.tail.p <- c(0.05,0.1)
	if(!is.null(Dots$block) & is.null(Dots$correlation)) stop("correlation must be set")

#	Covariate for trended eBayes
	covariate <- NULL
	if(Dots$trend) covariate <- rowMeans(as.matrix(y))

#	Compute effects matrix (with df.residual+1 columns)
	Effects <- .lmEffects(y=y,design=design,contrast=contrast,
		array.weights=Dots$array.weights,
		weights=Dots$weights,
		block=Dots$block,
		correlation=Dots$correlation)
	ngenes <- nrow(Effects)
	df.residual <- ncol(Effects)-1L

#	Empirical Bayes posterior variances
	s2 <- rowMeans(Effects[,-1L,drop=FALSE]^2)
	df.residual <- ncol(Effects)-1L
	if(is.null(var.prior) || is.null(df.prior)) {
		sv <- squeezeVar(s2,df=df.residual,covariate=covariate,robust=Dots$robust,winsor.tail.p=Dots$winsor.tail.p)
		var.prior <- sv$var.prior
		df.prior <- sv$df.prior
		var.post <- sv$var.post
	} else {
		var.post <- .squeezeVar(var=s2,df=df.residual,var.prior=var.prior,df.prior=df.prior)
	}

#	Check index
	if(is.null(index)) index <- list(set1=1L:ngenes)
	if(is.data.frame(index) || !is.list(index)) index <- list(set1=index)
	nsets <- length(index)
	if(nsets==0L) stop("index is empty")
	if(is.null(names(index)))
		names(index) <- paste0("set",formatC(1L:nsets,width=1L+floor(log10(nsets)),flag="0"))
	else
		if(anyDuplicated(names(index))) stop("Gene sets don't have unique names",call. =FALSE)

#	Check gene.weights
	lgw <- length(gene.weights)
	if(lgw > 0L && lgw != ngenes) stop("gene.weights vector should be of length nrow(y)")

#	Check geneid (can be a vector of gene IDs or an annotation column name)
	if(is.null(geneid)) {
		geneid <- rownames(Effects)
	} else {
		geneid <- as.character(geneid)
		if(length(geneid)==1) 
			geneid <- as.character(y$genes[,geneid])
		else
			if(length(geneid) != ngenes) stop("geneid vector should be of length nrow(y)")
	}

#	Containers for genewise results
	pv <- adjpv <- active <- array(0,c(nsets,4),dimnames=list(names(index),c("Down","Up","UpOrDown","Mixed")))
	if(nsets<1L) return(pv)
	NGenes <- rep_len(0L,length.out=nsets)

#	Call roast for each set
	s20 <- var.prior
	d0 <- df.prior
	for(i in 1:nsets) {
		g <- index[[i]]
		if(is.data.frame(g)) {
			if(ncol(g)>1 && is.numeric(g[,2])) {
				gw <- g[,2]
				g <- g[,1]
				if(is.factor(g)) g <- as.character(g)
				if(is.character(g)) {
					if(anyDuplicated(g)) stop("Duplicate gene ids in set: ",names(index[i]))
					j <- match(geneid,g)
					g <- which(!is.na(j))
					gw <- gw[j[g]]
				}
			} else {
				stop("index ",names(index[i])," is a data.frame but doesn't contain gene weights")
			}
		} else {
			if(is.factor(g)) g <- as.character(g)
			if(is.character(g)) g <- which(geneid %in% g)
			gw <- gene.weights[g]
		}
		E <- Effects[g,,drop=FALSE]
		if(length(var.prior)>1) s20 <- var.prior[g]
		if(length(df.prior)>1) d0 <- df.prior[g]
		s2post <- var.post[g]
		out <- .roastEffects(E,gene.weights=gw,set.statistic=set.statistic,var.prior=s20,df.prior=d0,var.post=s2post,nrot=nrot,approx.zscore=approx.zscore,legacy=legacy)
		pv[i,] <- out$p.value$P.Value
		active[i,] <- out$p.value$Active.Prop
		NGenes[i] <- out$ngenes.in.set
	}

#	P-values
	Up <- pv[,"Up"] < pv[,"Down"]
	Direction <- rep_len("Down",length.out=nsets)
	Direction[Up] <- "Up"
	TwoSidedP2 <- pv[,"UpOrDown"]
	MixedP2 <- pv[,"Mixed"]
	if(midp) {
		TwoSidedP2 <- TwoSidedP2 - 1/2/(nrot+1)
		MixedP2 <- MixedP2 - 1/2/(nrot+1)
	}

#	Output data.frame
	tab <- data.frame(
		NGenes=NGenes,
		PropDown=active[,"Down"],
		PropUp=active[,"Up"],
		Direction=Direction,
		PValue=pv[,"UpOrDown"],
		FDR=p.adjust(TwoSidedP2,method="BH"),
		PValue.Mixed=pv[,"Mixed"],
		FDR.Mixed=p.adjust(MixedP2,method="BH"),
		row.names=names(index),
		stringsAsFactors=FALSE
	)

#	Mid p-values
	if(midp) {
		tab$FDR <- pmax(tab$FDR, pv[,"UpOrDown"])
		tab$FDR.Mixed <- pmax(tab$FDR.Mixed, pv[,"Mixed"])
	}

#	Sort results
	if(is.logical(sort)) if(sort) sort <- "directional" else sort <- "none"
	sort <- match.arg(sort,c("directional","mixed","none"))
	if(sort=="none") return(tab)
	if(sort=="directional") {
		Prop <- pmax(tab$PropUp,tab$PropDown)
		o <- order(tab$PValue,-Prop,-tab$NGenes,tab$PValue.Mixed)
	} else {
		Prop <- tab$PropUp+tab$PropDown
		o <- order(tab$PValue.Mixed,-Prop,-tab$NGenes,tab$PValue)
	}
	tab[o,,drop=FALSE]
}


.roastEffects <- function(effects,gene.weights=NULL,set.statistic="mean",var.prior,df.prior,var.post,nrot=1999L,approx.zscore=TRUE,chunk=1000L,legacy=FALSE)
#	Rotation gene set testing, given the effects matrix for one set.
#	Rows are genes.  First column is primary effect.  Other columns are residual effects.
#	Gordon Smyth and Di Wu
#	Created 24 Apr 2008.  Last modified 22 July 2019.
{
	if(legacy) chunk <- nrot

	nset <- nrow(effects)
	neffects <- ncol(effects)
	df.residual <- neffects-1
	df.total <- df.prior+df.residual

#	Observed z-statistics
	modt <- effects[,1]/sqrt(var.post)
	if(approx.zscore && !legacy) {
		df.total.winsor <- pmin(df.total,10000)
		modt <- .zscoreTBailey(modt,df.total.winsor)
	} else {
		modt <- zscoreT(modt,df=df.total,approx=approx.zscore,method="hill")
	}

#	Estimate active proportions
	if(is.null(gene.weights)) {
		a1 <- mean(modt > sqrt(2))
		a2 <- mean(modt < -sqrt(2))
	} else {
		s <- sign(gene.weights)
		ss <- sum(abs(s))
		a1 <- sum(s*modt > sqrt(2)) / ss
		a2 <- sum(s*modt < -sqrt(2)) / ss
	}

#	Compute observed set statistics
	statobs <- rep_len(0,length.out=4)
	names(statobs) <- c("down","up","upordown","mixed")
	set.statistic <- match.arg(set.statistic,c("mean","floormean","mean50","msq"))
	switch(set.statistic,
	"mean" = { 
		if(!is.null(gene.weights)) modt <- gene.weights*modt
		m <- mean(modt)
		statobs["down"] <- -m
		statobs["up"] <- m
		statobs["mixed"] <- mean(abs(modt))
	},
	"floormean" = { 
		chimed <- qnorm(0.25,lower.tail=FALSE)
		amodt <- pmax(abs(modt),chimed)
		if(!is.null(gene.weights)) {
			amodt <- gene.weights*amodt
			modt <- gene.weights*modt
		}
		statobs["down"] <- mean(pmax(-modt,0))
		statobs["up"] <- mean(pmax(modt,0))
		statobs["upordown"] <- max(statobs[c("down","up")])
		statobs["mixed"] <- mean(amodt)
	},
	"mean50" = { 
		if(nset%%2L == 0L) {
			half1 <- nset %/% 2L
			half2 <- half1 + 1L
		} else {
			half1 <- half2 <- nset %/% 2L + 1L
		}
		if(!is.null(gene.weights)) modt <- gene.weights*modt
		s <- sort(modt,partial=half2)
		statobs["down"] <- -mean(s[1:half1])
		statobs["up"] <- mean(s[half2:nset])
		statobs["upordown"] <- max(statobs[c("down","up")])
		s <- sort(abs(modt),partial=half2)
		statobs["mixed"] <- mean(s[half2:nset])
	},
	"msq" = {
		modt2 <- modt^2
		if(!is.null(gene.weights)) {
			modt2 <- abs(gene.weights)*modt2
			modt <- gene.weights*modt
		}
		statobs["down"] <- sum(modt2[modt < 0])/nset
		statobs["up"] <- sum(modt2[modt > 0])/nset
		statobs["upordown"] <- max(statobs[c("down","up")])
		statobs["mixed"] <- mean(modt2)
	})

#	Conserve memory by conducting rotations in chunks
#	Start by computing number of chunks
	nchunk <- ceiling(nrot/chunk)
	nroti <- ceiling(nrot/nchunk)
	overshoot <- nchunk*nroti-nrot

#	Setup matrices to hold rotated statistics and output counts
	count <- rep_len(0L,length.out=4)
	statrot <- matrix(0,nroti,4)
	names(count) <- colnames(statrot) <- names(statobs)
	FinDf <- is.finite(df.prior)

#	Loop through chunks
	for(chunki in seq(from=1L,length.out=nchunk)) {

		if(chunki == nchunk) {
			nroti <- nroti - overshoot
			statrot <- statrot[1:nroti,,drop=FALSE]
		}

	#	Rotated primary effects (neffects by nroti)
		modtr <- matrix(rnorm(nroti*neffects),nroti,neffects)
		modtr <- modtr/sqrt(rowSums(modtr^2))
		modtr <- tcrossprod(effects,modtr)
	
	#	Moderated rotated variances
		if(all(FinDf)) {
			s2r <- (rowSums(effects^2)-modtr^2) / df.residual
			s2r <- (df.prior*var.prior+df.residual*s2r) / df.total
		} else {
			if(any(FinDf)) {
				s2r <- (rowSums(effects^2)-modtr^2) / df.residual
				if(length(var.prior)>1L) s20 <- var.prior[FinDf] else s20 <- var.prior
				s2r[FinDf,] <- (df.prior[FinDf]*s20+df.residual*s2r[FinDf,]) / df.total[FinDf]
			} else {
				s2r <- var.prior
			}
		}
	
	#	Rotated z-statistics
		modtr <- modtr/sqrt(s2r)
		if(approx.zscore && !legacy) {
			modtr <- .zscoreTBailey(modtr,df.total.winsor)
		} else {
			modtr <- zscoreT(modtr,df=df.total,approx=approx.zscore,method="hill")
		}
	
	#	Rotated set statistics and counts
		switch(set.statistic,
	
		"mean" = { 
			if(!is.null(gene.weights)) modtr <- gene.weights*modtr
			m <- colMeans(modtr)
			statrot[,"down"] <- -m
			statrot[,"up"] <- m
			statrot[,"mixed"] <- colMeans(abs(modtr))
			count["down"] <- count["down"] + sum(statrot[,c("down","up")] > statobs["down"])
			count["up"] <- count["up"] + sum(statrot[,c("down","up")] > statobs["up"])
			count["mixed"] <- count["mixed"] + sum(statrot[,c("mixed")] > statobs["mixed"])
		},
	
		"floormean" = { 
			amodtr <- pmax(abs(modtr),chimed)
			if(!is.null(gene.weights)) {
				amodtr <- gene.weights*amodtr
				modtr <- gene.weights*modtr
			}
			statrot[,"down"] <- colMeans(pmax(-modtr,0))
			statrot[,"up"] <- colMeans(pmax(modtr,0))
			i <- statrot[,"up"] > statrot[,"down"]
			statrot[i,"upordown"] <- statrot[i,"up"]
			statrot[!i,"upordown"] <- statrot[!i,"down"]
			statrot[,"mixed"] <- colMeans(amodtr)
			count["down"] <- count["down"] + sum(statrot[,c("down","up")] > statobs["down"])
			count["up"] <- count["up"] + sum(statrot[,c("down","up")] > statobs["up"])
			count["upordown"] <- count["upordown"] + sum(statrot[,c("upordown")] > statobs["upordown"])
			count["mixed"] <- count["mixed"] + sum(statrot[,c("mixed")] > statobs["mixed"])
		},
	
		"mean50" = { 
			if(!is.null(gene.weights)) modtr <- gene.weights*modtr
			for (r in 1L:nroti) {
				s <- sort(modtr[,r],partial=half2)
				statrot[r,"down"] <- -mean(s[1:half1])
				statrot[r,"up"] <- mean(s[half2:nset])
				statrot[r,"upordown"] <- max(statrot[r,c("down","up")])
				s <- sort(abs(modtr[,r]),partial=half2)
				statrot[r,"mixed"] <- mean(s[half2:nset])
			}
			count["down"] <- count["down"] + sum(statrot[,c("down","up")] > statobs["down"])
			count["up"] <- count["up"] + sum(statrot[,c("down","up")] > statobs["up"])
			count["upordown"] <- count["upordown"] + sum(statrot[,c("upordown")] > statobs["upordown"])
			count["mixed"] <- count["mixed"] + sum(statrot[,c("mixed")] > statobs["mixed"])
		},
	
		"msq" = {
			if(!is.null(gene.weights)) {
				gene.weights <- sqrt(abs(gene.weights))
				modtr <- gene.weights*modtr
			}
			statrot[,"down"] <- colMeans(pmax(-modtr,0)^2)
			statrot[,"up"] <- colMeans(pmax(modtr,0)^2)
			i <- statrot[,"up"] > statrot[,"down"]
			statrot[i,"upordown"] <- statrot[i,"up"]
			statrot[!i,"upordown"] <- statrot[!i,"down"]
			statrot[,"mixed"] <- colMeans(modtr^2)
			count["down"] <- count["down"] + sum(statrot[,c("down","up")] > statobs["down"])
			count["up"] <- count["up"] + sum(statrot[,c("down","up")] > statobs["up"])
			count["upordown"] <- count["upordown"] + sum(statrot[,c("upordown")] > statobs["upordown"])
			count["mixed"] <- count["mixed"] + sum(statrot[,c("mixed")] > statobs["mixed"])
		})
	}

#	P-values
	if(set.statistic=="mean") count["upordown"] <- min(count[c("down","up")])
	p <- (count+1L) / (c(2L,2L,1L,1L)*nrot + 1L)

#	Output
	out <- data.frame(c(a2,a1,max(a1,a2),a1+a2),p)
	dimnames(out) <- list(c("Down","Up","UpOrDown","Mixed"),c("Active.Prop","P.Value"))
	new("Roast",list(p.value=out,ngenes.in.set=nset))
}
