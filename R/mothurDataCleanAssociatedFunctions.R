###################################################################
# Functional Genomics Center Zurich
# This code is distributed under the terms of the GNU General
# Public License Version 3, June 2007.
# The terms are available here: http://www.gnu.org/licenses/gpl.html
# www.fgcz.ch


##' @title Mothur Summary Table
##' @description Create summary table from mothur summary files.
##' @param  summary, mothur summary files.
##' @return Returns a data.frame.

createSummaryTable <- function(summary){
part2 <- vector()
part1 <- apply(subset(summary,select=start:polymer),2,function(x)quantile(x, probs = c(0, 0.025,0.25, 0.5, 0.75, 0.975,1)))
k=1
part2[k] = 1
for (i in c(2.5,25,50,75,97.5,100)) {
  k=k+1
  part2[k] <- nrow(summary)*i/100
}
part2 <- data.frame(numSeqs=part2)
rawDataSummaryTable <- round(cbind(part1,data.frame(part2)), digits = 0)
rownames(rawDataSummaryTable) <- c("Mininmun","2.5%-tile","25%-tile","Median","75%-tile","97.5%-tile","Maximum")
return(rawDataSummaryTable)
}

###################################################################
# Functional Genomics Center Zurich
# This code is distributed under the terms of the GNU General
# Public License Version 3, June 2007.
# The terms are available here: http://www.gnu.org/licenses/gpl.html
# www.fgcz.ch


##' @title Creates Mothur input files from  Sushi dataset.
##' @description Converts Sushi dataset into Mothur input.
##' @param  taxaFileName, mothur taxonomy file.
##' @return Returns the .groups and .fasta files
datasetToMothur <- function(sushiInputDataset, param){
for (i in (1:nrow(sushiInputDataset))) {
filePathInDatset <- paste0(param$dataRoot,"/",sushiInputDataset$`Read1 [File]`[i])
techID <- sushiInputDataset$`Technology [Factor]`[i]
groupID <- rownames(sushiInputDataset)[i]
fastqFile <- readFastq(filePathInDatset)
x=data.frame(fastqFile@id)
readID <- data.frame(apply(x,1,function(y) unlist(strsplit(y," "))[[1]]))
groupFile <- data.frame(apply(readID,1,function(y) gsub(":","_",y)))
groupFile$group <- groupID
if (techID == "Illumina"){
write.table(groupFile, 'Illumina.groups', row.names = FALSE, quote = FALSE, col.names = FALSE, append = TRUE)
writeFasta(fastqFile,'Illumina.fasta', mode = 'a')
}else{
  write.table(groupFile, 'PacBio.groups', row.names = FALSE, quote = FALSE, col.names = FALSE, append = TRUE)
  writeFasta(fastqFile,'PacBio.fasta', mode = 'a')
}
}
}

 