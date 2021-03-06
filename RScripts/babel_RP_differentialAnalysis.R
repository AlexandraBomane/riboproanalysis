#!/usr/bin/env Rscript

## Setting this variable, we get arguments (groups/conditions names) in the command line
args <- commandArgs(T)

## Storing groups/conditions names in a vector
groups <- args

## Import Babel package
library(babel)

## Import FactomineR library
library(FactoMineR)

## RColorBrewer (for colors in plots)
library(RColorBrewer)

###############################################################################
# -----------------------------------------------------------------------------
# buildColorVector
#
#   This function aims to prepare a vector of colors, one for each unique
#   condition
#
#   input: CondSampleDf -> dataframe with sample and corresponding group/condition
#   output: coLors -> vector (the vector of colors)
#
# -----------------------------------------------------------------------------


buildColorVector <- function(CondSampleDf){
    # for a 2 conditions analysis
    if(length(unique(CondSampleDf$Condition)) == 2){
        uniqueColors <- c("#A6CEE3","#1F78B4")
        test <- lapply(CondSampleDf$Condition ,function(x){x == unique(CondSampleDf$Condition)})
        coLors <- c()
        for (result in test){
            coLors <- c(coLors, uniqueColors[result])
        }

    # for a 3-12 conditions analysis, using of a paired set of colors
    }else if(2 < length(unique(CondSampleDf$Condition)) &&  length(unique(CondSampleDf$Condition))<= 12){
        # download of the "Paired" set of colors from the RColorBrewer library
        uniqueColors <- brewer.pal(length(unique(CondSampleDf$Condition)), "Paired")
        # selection of the good number of colors for the analysis
        test <- lapply(CondSampleDf$Condition ,function(x){x == unique(CondSampleDf$Condition)})
        coLors <- c()
        for (result in test){
            coLors <- c(coLors, uniqueColors[result])
        }
    # for an analysis with more than 12 conditions
    }else{
        uniqueColors <- rainbow(length(unique(CondSampleDf$Condition)))
        # selection of the good number of colors for the analysis
        test <- lapply(CondSampleDf$Condition ,function(x){x == unique(CondSampleDf$Condition)})
        coLors <- c()
        for (result in test){
            coLors <- c(coLors, uniqueColors[result])
        }
    }
    return(coLors)
}


########################################################################################
#---------------------------------------------------------------------------------------
#  splitVector
#       This function aims at split vector x into groups with a specified number n 
#       of elements per group. If length(x) %% n is not 0, the final group will 
#       have fewer than n elements
# 
#       input : x -> the vector to split
#--------------------------------------------------------------------------------------

splitVector <- function(x, n) 
        {
                split(x, gl(ceiling(length(x)/n), n, length(x)))
        }


###########################################################################################
#------------------------------------------------------------------------------------------
# samplesPerConditionVector
#       This function aims at shuffle given samples
#
#       input : samples -> vector contaning samples, conds -> vector containing samples's 
#       conditions
#       output : shuffleSamplesVector -> vector with mixed samples
#------------------------------------------------------------------------------------------

samplesPerConditionVector <- function(samples, conds)
        {
                # Storing number of samples, conditions and samples/condition

                nbSamples <- length(samples)

                nbConds <- length(conds)

                nbSamplesPerConds <- nbSamples/nbConds

                # Putting samlples in their respective vector (corresponding to the condition)
                subSample <- splitVector(samples, nbSamplesPerConds)

		return(subSample)
	}


## Reading counts tables (RNA and RP)
data.rna <- read.table("mRNAmainMatrix.txt", row.names = 1, stringsAsFactors = F, header = T)
data.rp <- read.table("RPmainMatrix.txt", row.names = 1, stringsAsFactors = F, header = T)

## Storing samples and conditions names in respective vector
Samples <- colnames(data.rna)
Conds <- unique(groups)

#testsamplesPerConditionVector <- samplesPerConditionVector(Samples, Conds)

#data.rna.fusion <- data.frame(NA)
#data.rna.fusion.colnames <- vector()

#for (i in 1:length(Conds))
#	{
#		assign(Conds[i], testsamplesPerConditionVector[[i]])
#		assign(paste("columnName", Conds[i], sep = ""), paste(get(Conds[i]), collapse='+'))
#		data.rna.fusion.colnames <- c(data.rna.fusion.colnames, get(paste("columnName", Conds[i], sep = "")))
#		assign(paste('sample.index', Conds[i], sep = ''), which(get(Conds[i]) == Samples))
#		data.rna.fusion <- data.frame(data.rna.fusion, rowSums(data.rna[, get(paste('sample.index', Conds[i], sep = ''))]))
#	}

## data frame per cond avec des colnames (MB1 + MB2) for ex
#data.rna.fusion$NA. <- NULL
#names(data.rna.fusion) <- data.rna.fusion.colnames
#print(head(data.rna.fusion))

#stop("test samplesPerConditionVector")
## Keeping common genes to our two counts tables
data.rna <- data.rna[rownames(data.rp),]
data.rp <- data.rp[rownames(data.rna),]

## Handling missing values
data.rna[is.na(data.rna)] <- 0
data.rp[is.na(data.rp)] <- 0

## Dataframe making relation between samples and their respective condition
CondSample.df <- data.frame(sample = Samples, Condition = groups, stringsAsFactors = F)
coLors <- buildColorVector(CondSample.df)
CondSample.df <- data.frame(CondSample.df, coLors, stringsAsFactors = F)

#print(CondSample.df)

## Storing experiments 'RNAseq' and 'Ribosome Profiling' in a vector
experiments <- c('rna','rp')

for (i in 1:length(experiments))
	{
		## Producing normalized reads counts tables (cf : http://www.bioconductor.org/packages/release/bioc/vignettes/edgeR/inst/doc/edgeRUsersGuide.pdf, "Quick start")

		x <- get(paste('data.', experiments[i], sep = ""))

		group.factor <- factor(groups)

		libSize <- colSums(x, na.rm = T)

		x[is.na(x)] <- 0

		y <- DGEList(counts = x, group = group.factor, lib.size = libSize)
		
		normalized.counts.table <- cpm(y, normalized.lib.sizes = FALSE)

		normalized.counts.table.name <- paste(experiments[i], "_normalized_count_table.txt", sep = "")

		normalized.counts.table.to.write <- cbind(rownames(normalized.counts.table), normalized.counts.table)

		colnames(normalized.counts.table.to.write) <- c("geneIds", colnames(normalized.counts.table))

		write.table(normalized.counts.table.to.write, file = normalized.counts.table.name, sep = "\t", na = "", row.names = F, col.names = T, quote = F)

## PCA for normalized reads counts for Ribosome Profiling and RNAseq

               pcaCount <- PCA(t(x), graph = FALSE)
                       png(paste("PCA_on_unnormalized_", experiments[i], "_counts.png",sep=""),width=1000, height=600)
                               par(mar = c(5,5,5,20))
                               plot.PCA(pcaCount, choix = "ind", col.ind = as.character(CondSample.df$coLors), title = paste("Unnormalized PCA - ", experiments[i], sep = ""))
                               cor <- par('usr')
                               par(xpd = NA)
                               # add of legends
                               legend(cor[2] * 1.01,cor[4], title = "Legend", legend = unique(CondSample.df$Condition), col = unique(as.character(CondSample.df$coLors)), pch = 15, pt.cex = 3, cex = 1.2)
                       dev.off()

## PCA for unnormalized reads counts for Ribosome Profiling and RNAseq

		pcaCount <- PCA(t(normalized.counts.table), graph = FALSE)
                       png(paste("PCA_on_normalized_", experiments[i], "_counts.png",sep=""),width=1000, height=600)
                               par(mar = c(5,5,5,20))
                               plot.PCA(pcaCount, choix = "ind", col.ind = as.character(CondSample.df$coLors), title = paste("Normalized PCA - ", experiments[i], sep = ""))
                               cor <- par('usr')
                               par(xpd = NA)
                               # add of legends
                               legend(cor[2] * 1.01,cor[4], title = "Legend", legend = unique(CondSample.df$Condition), col = unique(as.character(CondSample.df$coLors)), pch = 15, pt.cex = 3, cex = 1.2)
                       dev.off()

		# preparation of 2 data frame with the same number of column than the dds count matrix
		maxCounts <- normalized.counts.table[1,]
		genesNames <- normalized.counts.table[1,]

		# for each sample (column)
		for(j in 1:ncol(normalized.counts.table))
			{
				# selection of the maximum number of count
				maxCounts[j] <- max(normalized.counts.table[,j])/sum(normalized.counts.table[,j]) * 100

				# selection of the name of the features this the maximum of count
				genesNames[j] <- row.names(subset(normalized.counts.table, normalized.counts.table[,j] == max(normalized.counts.table[,j])))
    			}

		png(paste(experiments[i], "_data_most_expressed_genes.png", sep = ""), width = 1000, height = 600)
			par(mar=c(5,15,5,20))
			x <- barplot(t(maxCounts), main = paste("Most expressed genes - ", experiments[i], sep = ""), col = as.character(CondSample.df$coLors), horiz = TRUE, names.arg = CondSample.df$sample, las = 1,cex.lab = 2, xlab = "Proportion of reads (%)")
			# add names of the features on the plot bars
			text(0, x, labels = genesNames, srt = 0, adj = 0)
			cor <- par('usr')
			par(xpd = NA)
			# add legends
			legend(cor[2] * 1.01, cor[4], title = "Legend", legend = unique(CondSample.df$Condition), col = unique(as.character(CondSample.df$coLors)), pch = 15, pt.cex = 3, cex = 1.2)
		dev.off()
	}


## Running Babel analysis : argument = counts tables, conditions, nb of permutations and threshold for RNA count.
diff.ana.babel <- babel(data.rna, data.rp, group = groups, nreps = 100000, min.rna = 10)

## Saving the Babel analysis as an RDS object
saveRDS(diff.ana.babel,"diff.ana.babel.rds")

## Getting the 3 Babel analyses : 1) Within a given sample. 2) For combined samples of same condition. 3) Between all conditions.
within.babel <- diff.ana.babel$within
combined.babel <- diff.ana.babel$combined
between.babel <- diff.ana.babel$between

#print(colnames(between.babel))
#stop("test samplesPerConditionVector")

## For each sample : 1) Writting the matrix given by Babel for the "Within" analysis. 2) Scatterplot of "RPF count = f(mRNA counts)" for all genes
## underlying genes from the "Within" analysis with "P-value (one-sided)" < 0.025 (RPF greater than mRNA) and "P-value (one-sided)" > 0.975 (vice-versa) on the log scale
for (i in 1:length(Samples))
	{
		filename <- paste(Samples[i], "_Within_BabelAnalysisMatrix.txt", sep = "")
		write.table(within.babel[[i]], file = filename, sep = "\t", na = "", row.names = F, col.names = T, quote = F)
		
		png(paste(Samples[i], "_Within_", groups[i], "_Condition.png", sep = ""), height = 600, width = 1000)
			par(mar = c(6,6,5,20), xpd = T)
			# selection of genes with p-values < 0.025 and > 0.975
			which.025 <- which(within.babel[[i]]$"P-value (one-sided)" < 0.025)
			which.975 <- which(within.babel[[i]]$"P-value (one-sided)" > 0.975)
			# scatterplots
			plot(data.rna[,i] + 1, data.rp[,i] + 1, xlab = "mRNA counts", ylab = "RPF counts", pch = 16, log = "xy", xlim = c(1,100000), ylim = c(1,100000), font.lab = 2, cex.lab = 2, main = paste(Samples[i], " Within ", groups[i], " Condition", sep=""))
			# underlying genes p-values < 0.025 and > 0.975
			points(data.rna[which.025,i] + 1, data.rp[which.025,i] + 1, pch = 16, col = 2)
			points(data.rna[which.975,i] + 1,data.rp[which.975,i] + 1, pch = 16, col = 3)
			# add legends
			legend("topright", inset = c(-0.4,0), title = "Legend", legend = c("P-value (one-sided) < 0.025", "P-value (one-sided) > 0.975"), col = c(2,3), pch = 15, pt.cex = 3, cex = 1.2)
			cor <- par('usr')
			par(xpd = NA)
		dev.off()
	}

## For each condition : writting the matrix given by Babel for the "Combined" analysis.
## For each sample : scatterplot of "RPF count = f(mRNA counts)" for all genes underlying genes from the "Combined" analysis with "P-value (one-sided)" < 0.025 (RPF greater than mRNA) on the log scale
for (i in 1:length(Conds))
	{
		current.cond <- Conds[i]
		filename <- paste(current.cond, "_Combined_BabelAnalysisMatrix.txt", sep = "")
		write.table(combined.babel[[i]], file = filename, sep = "\t", na = "", row.names = F, col.names = T, quote = F)

		s <- which(CondSample.df$Condition == current.cond)

		for (j in s)
			{
				current.sample.index <- j
				current.sample <- CondSample.df$sample[j]

				png(paste("Sample_", current.sample, "_InCombined_", current.cond, "_Condition.png",sep = ""), height = 600, width = 1000)
					par(mar = c(6,6,5,20), xpd = T)
					# selection of genes with "P-value" < 0.025
					which.025 <- which(combined.babel[[i]]$"P-value" < 0.025)
					# scatterplots
					plot(data.rna[,current.sample.index] + 1, data.rp[,current.sample.index] + 1, xlab = "mRNA counts", ylab = "RPF counts", pch = 16, log = "xy", xlim = c(1,100000),ylim = c(1,100000),font.lab = 2, main = paste("Sample ", current.sample, " in Combined ", current.cond, " Condition",sep = ""))
					# underlying genes with "P-value" < 0.025
					points(data.rna[which.025,current.sample.index] + 1,data.rp[which.025,current.sample.index] + 1, pch = 16, col = 2)
					# add legends
					legend("topright", inset = c(-0.4,0), title = "Legend", legend = "P-value (one-sided) < 0.025", col = 2, pch = 15, pt.cex = 3, cex = 1.2)
					cor <- par('usr')
					par(xpd = NA)
				dev.off()
			}
	}

## Compute the number of all possible associations between groups/conditions
nbPossible.permutations <- factorial(length(Conds))

## Retrive the reciprocity of comparisons
nbCombinaisons.to.compare <- nbPossible.permutations/2

## For each conditions comparison : 1) Writting a matrix from "Between" Babel analysis. 2) Writting a matrix with significant genes (FDR < 5%)
## 3) Histograms : - distribution of p-values for all genes. - distribution of p-values for significant genes.
for (i in 1:nbCombinaisons.to.compare)
	{                              
		write.table(between.babel[[i]], paste("Between_Babel_Analysis_Matrix", names(between.babel)[i], ".txt", sep = "") , sep = "\t", na = " ", row.names = F, col.names = T)
		
		which.low.fdr <- which(between.babel[[i]]$"FDR" < 0.05)
		write.table(between.babel[[i]][which.low.fdr,], paste("SignificantGenesIn_", names(between.babel)[i], "_Comparison.txt", sep = ""), sep = "\t", na = "", row.names = F, col.names = T, quote = F)

		png(paste("P-valuesDistributionOf_", names(between.babel)[i], "_Comparison.png", sep = ""), width = 600, height = 600)

			raw.pvalues <- between.babel[[i]]$"P-value"
                        res <- try(hist(raw.pvalues, main = paste("Distribution of p-values for all genes in ", names(between.babel)[i], " comparison", sep = ""), xlab = "P-value", ylab = "Frequency", col = 'deepskyblue4', freq = T), silent = T)
			if (class(res) == "try-error")
				{
					print(paste("Impossible to draw P-valuesDistributionOf_", names(between.babel)[i], "_Comparison.png", sep = ""))
				}
		dev.off()

		png(paste("P-valuesDistributionOf_", names(between.babel)[i], "_ComparisonSignificantGenes.png", sep = ""), width = 600, height = 600)
	
			selected.pvalues <- between.babel[[i]][which.low.fdr,]$"P-value"
                        res <- try(hist(selected.pvalues, main = paste("Distribution of p-values for significant genes in ", names(between.babel)[i], " comparison", sep = ""), xlab = "P-value", ylab = "Frequency", col = 'chocolate1', freq = T), silent = T)
			if (class(res) == "try-error")
				{
					print(paste("Impossible to draw P-valuesDistributionOf_", names(between.babel)[i], "_ComparisonSignificantGenes.png", sep = ""))
				}
                dev.off()
	}
