###################################################################
# Functional Genomics Center Zurich
# This code is distributed under the terms of the GNU General
# Public License Version 3, June 2007.
# The terms are available here: http://www.gnu.org/licenses/gpl.html
# www.fgcz.ch


ezMethodFeatureCounts = function(input=NA, output=NA, param=NA){
  require(GenomicRanges)
  bamFile = input$getFullPaths("BAM")
  localBamFile = .getBamLocally(bamFile)
  if(localBamFile != bamFile){
    on.exit(file.remove(c(localBamFile, paste0(localBamFile, ".bai"))),
            add=TRUE)
  }
  
  outputFile = basename(output$getColumn("Count"))
  statFile = basename(output$getColumn("Stats"))
  
  if(!is.null(param$aroundTSSCounting) && param$aroundTSSCounting){
    gtf <- rtracklayer::import(param$ezRef@refFeatureFile)
    seqlengthsRef <- fasta.seqlengths(param$ezRef@refFastaFile)
    seqlengths(gtf) <- seqlengthsRef[names(seqlengths(gtf))]
    gtf <- gtf[gtf$type == "gene"]
    if (ezIsSpecified(param$transcriptTypes)){
      seqAnno = ezFeatureAnnotation(param$ezRef@refAnnotationFile,
                                    dataFeatureType="gene")
      genesUse <- rownames(seqAnno)[seqAnno$type %in% param$transcriptTypes]
      gtf <- gtf[gtf$gene_id %in% genesUse]
    }
    
    gtfFile = paste(Sys.getpid(), "genes.gtf", sep="-")
    gtf <- trim(suppressWarnings(promoters(gtf, upstream=param$upstreamFlanking,
                                           downstream=param$downstreamFlanking)))
    rtracklayer::export(gtf, gtfFile)
    on.exit(file.remove(gtfFile), add=TRUE)

    countResult = Rsubread::featureCounts(localBamFile, annot.inbuilt=NULL,
                                          annot.ext=gtfFile, isGTFAnnotationFile=TRUE,
                                          GTF.featureType='gene',
                                          GTF.attrType= 'gene_id',
                                          useMetaFeatures=param$useMetaFeatures,
                                          allowMultiOverlap=param$allowMultiOverlap,
                                          isPairedEnd=param$paired, 
                                          requireBothEndsMapped=FALSE,
                                          checkFragLength=FALSE,minFragLength=50,
                                          maxFragLength=600,
                                          nthreads=param$cores, 
                                          strandSpecific=switch(param$strandMode, "both"=0, "sense"=1, "antisense"=2, stop("unsupported strand mode: ", param$strandMode)),
                                          minMQS=param$minMapQuality,
                                          readExtension5=0,readExtension3=0,
                                          read2pos=NULL,
                                          minOverlap=param$minFeatureOverlap,
                                          ignoreDup=param$ignoreDup,
                                          splitOnly=FALSE,
                                          countMultiMappingReads=param$keepMultiHits,
                                          fraction=param$keepMultiHits & !param$countPrimaryAlignmentsOnly,
                                          primaryOnly=param$countPrimaryAlignmentsOnly,
                                          countChimericFragments=TRUE,
                                          chrAliases=NULL,reportReads=NULL)
  }else{
    ## Count exons by gene
    if (ezIsSpecified(param$transcriptTypes)){
      gtfFile = paste(Sys.getpid(), "genes.gtf", sep="-")
      on.exit(file.remove(gtfFile), add=TRUE)
      seqAnno = ezFeatureAnnotation(param$ezRef@refAnnotationFile,
                                    dataFeatureType="transcript")
      transcriptsUse = rownames(seqAnno)[seqAnno$type %in% param$transcriptTypes]
      require(data.table)
      require(stringr)
      gtf <- ezReadGff(param$ezRef@refFeatureFile)
      transcripts <- ezGffAttributeField(gtf$attributes,
                                         field="transcript_id", 
                                         attrsep="; *", valuesep=" ")
      gtf = gtf[transcripts %in% transcriptsUse, ]
      ## write.table is much faster than write_tsv and export.
      ### write_tsv: 38.270s
      ### export: 347.998s
      ### write.table: 8.787s
      write.table(gtf, gtfFile, quote=FALSE, sep="\t", 
                  row.names=FALSE, col.names=FALSE)
    } else {
      gtfFile = param$ezRef@refFeatureFile
    }
    countResult = Rsubread::featureCounts(localBamFile, annot.inbuilt=NULL,
                              annot.ext=gtfFile, isGTFAnnotationFile=TRUE,
                              GTF.featureType=param$gtfFeatureType,
                              GTF.attrType=switch(param$featureLevel,
                                                  "gene"="gene_id",
                                                  "transcript"="transcript_id",
                                                  "isoform"="transcript_id",
                                                  stop("unsupported feature level: ", param$featureLevel)),
                              useMetaFeatures=param$useMetaFeatures,
                              allowMultiOverlap=param$allowMultiOverlap,
                              isPairedEnd=param$paired, 
                              requireBothEndsMapped=FALSE,
                              checkFragLength=FALSE,minFragLength=50,
                              maxFragLength=600,
                              nthreads=param$cores, 
                              strandSpecific=switch(param$strandMode, "both"=0, "sense"=1, "antisense"=2, stop("unsupported strand mode: ", param$strandMode)),
                              minMQS=param$minMapQuality,
                              readExtension5=0,readExtension3=0,read2pos=NULL,
                              minOverlap=param$minFeatureOverlap,
                              ignoreDup=param$ignoreDup,
                              splitOnly=FALSE,
                              countMultiMappingReads=param$keepMultiHits,
                              fraction=param$keepMultiHits & !param$countPrimaryAlignmentsOnly,
                              primaryOnly=param$countPrimaryAlignmentsOnly,
                              countChimericFragments=TRUE,chrAliases=NULL,
                              reportReads=NULL)
  }
  
  colnames(countResult$counts) = "matchCounts"
  ezWrite.table(countResult$counts, file=outputFile)
  colnames(countResult$stat) = c("Status", "Count")
  ezWrite.table(countResult$stat, file=statFile, row.names=FALSE)
  return("Success")
}

##' @template app-template
##' @templateVar method ezMethodFeatureCounts(input=NA, output=NA, param=NA)
##' @description Use this reference class to run 
EzAppFeatureCounts <-
  setRefClass("EzAppFeatureCounts",
              contains = "EzApp",
              methods = list(
                initialize = function()
                {
                  "Initializes the application using its specific defaults."
                  runMethod <<- ezMethodFeatureCounts
                  name <<- "EzAppFeatureCounts"
                  appDefaults <<- rbind(gtfFeatureType = ezFrame(Type="character",  DefaultValue="exon",  Description="which gtf feature types to use; with Ensembl GTF files; use 'transcript' to count also intronic reads"),
                                        allowMultiOverlap = ezFrame(Type="logical",  DefaultValue="TRUE",  Description="make sure that every read counts only as one"),
                                        countPrimaryAlignmentsOnly = ezFrame(Type="logical",  DefaultValue="TRUE",  Description="count only the primary alignment"),
                                        minFeatureOverlap=ezFrame(Type="integer", DefaultValue="10", Description="the number of bases overlap are need to generate a count"),
                                        useMetaFeatures=ezFrame(Type="logical", DefaultValue="TRUE", Description="should counts be summarized to meta-features"),
                                        ignoreDup=ezFrame(Type="logical", DefaultValue="FALSE", Description="ignore reads marked as duplicates"),
                                        aroundTSSCounting=ezFrame(Type="logical",  DefaultValue="FALSE",  Description="count reads only around TSS of genes"),
                                        downstreamFlanking=ezFrame(Type="integer", DefaultValue="250", Description="the number of bases downstream of TSS"),
                                        upstreamFlanking=ezFrame(Type="integer", DefaultValue="250", Description="the number of bases upstream of TSS"))
                }
              )
  )


### EzAppSingleCellFeatureCounts
EzAppSingleCellFeatureCounts <-
  setRefClass("EzAppSingleCellFeatureCounts",
              contains = "EzApp",
              methods = list(
                initialize = function()
                {
                  "Initializes the application using its specific defaults."
                  runMethod <<- ezMethodSingleCellFeatureCounts
                  name <<- "EzAppSingleCellFeatureCounts"
                  appDefaults <<- 
                    rbind(gtfFeatureType = ezFrame(Type="character",
                                                   DefaultValue="exon",
                                                   Description="which gtf feature types to use; with Ensembl GTF files; use 'transcript' to count also intronic reads"),
                          allowMultiOverlap = ezFrame(Type="logical",
                                                      DefaultValue="TRUE",
                                                      Description="make sure that every read counts only as one"),
                          countPrimaryAlignmentsOnly = ezFrame(Type="logical",
                                                               DefaultValue="TRUE",
                                                               Description="count only the primary alignment"),
                          minFeatureOverlap=ezFrame(Type="integer",
                                                    DefaultValue="10",
                                                    Description="the number of bases overlap are need to generate a count"),
                          useMetaFeatures=ezFrame(Type="logical",
                                                  DefaultValue="TRUE",
                                                  Description="should counts be summarized to meta-features"),
                          ignoreDup=ezFrame(Type="logical",
                                            DefaultValue="FALSE",
                                            Description="ignore reads marked as duplicates"),
                          aroundTSSCounting=ezFrame(Type="logical",
                                                    DefaultValue="FALSE",
                                                    Description="count reads only around TSS of genes"),
                          downstreamFlanking=ezFrame(Type="integer",
                                                     DefaultValue="250",
                                                     Description="the number of bases downstream of TSS"),
                          upstreamFlanking=ezFrame(Type="integer",
                                                   DefaultValue="250",
                                                   Description="the number of bases upstream of TSS"))
                }
              )
  )

ezMethodSingleCellFeatureCounts <- function(input=NA, output=NA, param=NA){
  require(GenomicRanges)
  
  bamFile = input$getFullPaths("BAM")
  localBamFile = .getBamLocally(bamFile)
  if(localBamFile != bamFile){
    on.exit(file.remove(c(localBamFile, paste0(localBamFile, ".bai"))),
            add=TRUE)
  }
  
  outputFile = basename(output$getColumn("CountMatrix"))
  statFile = basename(output$getColumn("Stats"))
  
  require(Rsamtools)
  bamHeaders <- scanBamHeader(localBamFile)
  hasRG <- "@RG" %in% names(bamHeaders[[1]]$text)
  
  if(!is.null(param$aroundTSSCounting) && param$aroundTSSCounting){
    gtf <- rtracklayer::import(param$ezRef@refFeatureFile)
    seqlengthsRef <- fasta.seqlengths(param$ezRef@refFastaFile)
    seqlengths(gtf) <- seqlengthsRef[names(seqlengths(gtf))]
    gtf <- gtf[gtf$type == "gene"]
    if (ezIsSpecified(param$transcriptTypes)){
      seqAnno = ezFeatureAnnotation(param$ezRef@refAnnotationFile,
                                    dataFeatureType="gene")
      genesUse <- rownames(seqAnno)[seqAnno$type %in% param$transcriptTypes]
      gtf <- gtf[gtf$gene_id %in% genesUse]
    }
    
    gtfFile = paste(Sys.getpid(), "genes.gtf", sep="-")
    gtf <- trim(suppressWarnings(promoters(gtf, upstream=param$upstreamFlanking,
                                           downstream=param$downstreamFlanking)))
    rtracklayer::export(gtf, gtfFile)
    on.exit(file.remove(gtfFile), add=TRUE)
    
    countResult = Rsubread::featureCounts(localBamFile, annot.inbuilt=NULL,
                                          annot.ext=gtfFile, isGTFAnnotationFile=TRUE,
                                          GTF.featureType='gene',
                                          GTF.attrType= 'gene_id',
                                          useMetaFeatures=param$useMetaFeatures,
                                          allowMultiOverlap=param$allowMultiOverlap,
                                          isPairedEnd=param$paired, 
                                          requireBothEndsMapped=FALSE,
                                          checkFragLength=FALSE,minFragLength=50,
                                          maxFragLength=600,
                                          nthreads=param$cores, 
                                          strandSpecific=switch(param$strandMode, "both"=0, "sense"=1, "antisense"=2, stop("unsupported strand mode: ", param$strandMode)),
                                          minMQS=param$minMapQuality,
                                          readExtension5=0,readExtension3=0,
                                          read2pos=NULL,
                                          minOverlap=param$minFeatureOverlap,
                                          ignoreDup=param$ignoreDup,
                                          splitOnly=FALSE,
                                          countMultiMappingReads=param$keepMultiHits,
                                          fraction=param$keepMultiHits & !param$countPrimaryAlignmentsOnly,
                                          primaryOnly=param$countPrimaryAlignmentsOnly,
                                          countChimericFragments=TRUE,
                                          chrAliases=NULL,reportReads=NULL,
                                          byReadGroup=ifelse(hasRG, TRUE, FALSE))
  }else{
    if (ezIsSpecified(param$transcriptTypes)){
      gtfFile = paste(Sys.getpid(), "genes.gtf", sep="-")
      on.exit(file.remove(gtfFile), add=TRUE)
      seqAnno = ezFeatureAnnotation(param$ezRef@refAnnotationFile,
                                    dataFeatureType="transcript")
      transcriptsUse = rownames(seqAnno)[seqAnno$type %in% param$transcriptTypes]
      require(data.table)
      require(stringr)
      gtf <- ezReadGff(param$ezRef@refFeatureFile)
      transcripts <- ezGffAttributeField(gtf$attributes,
                                         field="transcript_id", 
                                         attrsep="; *", valuesep=" ")
      gtf = gtf[transcripts %in% transcriptsUse, ]
      write.table(gtf, gtfFile, quote=FALSE, sep="\t", 
                  row.names=FALSE, col.names=FALSE)
    } else {
      gtfFile = param$ezRef@refFeatureFile
    }
    
    countResult = Rsubread::featureCounts(localBamFile, annot.inbuilt=NULL,
                                          annot.ext=gtfFile, isGTFAnnotationFile=TRUE,
                                          GTF.featureType=param$gtfFeatureType,
                                          GTF.attrType=switch(param$featureLevel,
                                                              "gene"="gene_id",
                                                              "transcript"="transcript_id",
                                                              "isoform"="transcript_id",
                                                              stop("unsupported feature level: ", param$featureLevel)),
                                          useMetaFeatures=param$useMetaFeatures,
                                          allowMultiOverlap=param$allowMultiOverlap,
                                          isPairedEnd=param$paired, 
                                          requireBothEndsMapped=FALSE,
                                          checkFragLength=FALSE,minFragLength=50,
                                          maxFragLength=600,
                                          nthreads=param$cores, 
                                          strandSpecific=switch(param$strandMode, "both"=0, "sense"=1, "antisense"=2, stop("unsupported strand mode: ", param$strandMode)),
                                          minMQS=param$minMapQuality,
                                          readExtension5=0,readExtension3=0,read2pos=NULL,
                                          minOverlap=param$minFeatureOverlap,
                                          ignoreDup=param$ignoreDup,
                                          splitOnly=FALSE,
                                          countMultiMappingReads=param$keepMultiHits,
                                          fraction=param$keepMultiHits & !param$countPrimaryAlignmentsOnly,
                                          primaryOnly=param$countPrimaryAlignmentsOnly,
                                          countChimericFragments=TRUE,chrAliases=NULL,
                                          reportReads=NULL,
                                          byReadGroup=ifelse(hasRG, TRUE, FALSE))
  }
  
  ## The count matrix from featurecounts has colnames messed up
  ## recover them here
  countsFixed <- countResult$counts
  colnames(countsFixed) <- sub(paste0(make.names(localBamFile), "."), "", 
                               colnames(countsFixed))
  tagsRG <- sub("ID:", "", 
                sapply(bamHeaders[[1]]$text[names(bamHeaders[[1]]$text) == "@RG"], "[", 1))
  fixNameMapping <- setNames(tagsRG, make.names(tagsRG))
  colnames(countsFixed) <- fixNameMapping[colnames(countsFixed)]
  
  ## wirteMM doesn't hold the colnames and rownames in mtx
  ezWrite.table(countsFixed, head=paste0(param$featureLevel, "_id"),
                file=outputFile)
  ezWrite.table(countResult$stat, file=statFile, row.names=FALSE)
  
  # Determine cell cycle phases. The training data is only available for Hsap and Mmus Ensembl
  trainData = NULL
  if (startsWith(param$refBuild, "Homo_sapiens/Ensembl")) {
    trainData = readRDS(system.file("exdata", "human_cycle_markers.rds", 
                                    package = "scran", mustWork=TRUE))
  } else if (startsWith(param$refBuild, "Mus_musculus/Ensembl")) {
    trainData = readRDS(system.file("exdata", "mouse_cycle_markers.rds", 
                                    package = "scran", mustWork=TRUE))
  }
  if (!is.null(trainData)) {
    cellCycleData = scran::cyclone(countResult$counts, trainData)
    cellPhase = data.frame(Name = colnames(countResult$counts),
                           Phase = cellCycleData$phases)
    write.table(cellPhase, file = basename(output$getColumn('CellCyclePhase')),
                quote = F, sep = "\t", row.names = F)
  }
  
  return("Success")
}
