###################################################################
# Functional Genomics Center Zurich
# This code is distributed under the terms of the GNU General
# Public License Version 3, June 2007.
# The terms are available here: http://www.gnu.org/licenses/gpl.html
# www.fgcz.ch


ezMethodFastqScreen = function(input=NA, output=NA, param=NA,
                               htmlFile="00index.html"){
  inputRaw <- input$copy()
  # Preprocessing
  if(input$readType() == "bam"){
    fastqInput <- ezMethodBam2Fastq(input = input, param = param)
    input <- ezMethodTrim(input = fastqInput, param = param)
    inputRaw <- fastqInput
  }else{
    input <- ezMethodTrim(input = input, param = param)
  }
  dataset = inputRaw$meta
  # fastqscreen part
  
  ## get Adapter contamination from raw data
  confFile = FASTQSCREEN_ADAPTER_CONF
  files_rawData = inputRaw$getFullPaths("Read1")
  resultFiles_rawData = executeFastqscreenCMD(param, confFile = confFile,
                                              files_rawData)
  fastqData_rawData = collectFastqscreenOutput(files_rawData, 
                                               resultFiles_rawData)
  tempFns <- list.files(".",
                        pattern=".*(tagged\\.fastq|tagged_filter\\.fastq)$")
  file.remove(tempFns)
  tempFns <- list.files(".", 
                        pattern=".*(screen\\.html|screen\\.png)$")
  file.remove(tempFns)
  if(exists("fastqInput")){
    ## Then files_rawData is bam converted fastq locally.
    file.remove(files_rawData)
  }
  file.remove(resultFiles_rawData)
  
  ## PreprocessedData
  confFile = FASTQSCREEN_GENOMICDNA_RIBORNA_CONF
  files_ppData = input$getFullPaths("Read1")
  resultFiles_ppData = executeFastqscreenCMD(param, confFile = confFile, 
                                             files_ppData)
  fastqData_ppData = collectFastqscreenOutput(files_ppData, resultFiles_ppData)
  noHit_files = gsub('.fastq$', '.tagged_filter.fastq', files_ppData)
  readCount = ezFrame(totalReadCount = integer(length(files_ppData)), 
                      unmappedReadCount = integer(length(files_ppData)),
                      row.names=names(files_ppData))
  readCount[ , "totalReadCount"] <- countReadsInFastq(files_ppData)
  readCount[ , "unmappedReadCount"] <- countReadsInFastq(noHit_files)
  file.remove(resultFiles_ppData)
  tempFns <- list.files(".", pattern=".*tagged\\.fastq$")
  file.remove(tempFns)
  tempFns <- list.files(".", 
                        pattern=".*(screen\\.html|screen\\.png)$")
  file.remove(tempFns)
  
  # bowtie2 reference part
  countFiles = executeBowtie2CMD(param, input)
  speciesPercentageTop = collectBowtie2Output(param, countFiles, 
                                              readCount, virusResult=F)
  
  #Always check human data for viruses
  if(grepl('^Human|^Homo',dataset$Species[1])){
    param[['virusCheck']] = T
  }
  
  if(param[['virusCheck']]){
    countFiles = executeBowtie2CMD_Virus(param, noHit_files)
    speciesPercentageTopVirus = collectBowtie2Output(param, countFiles, 
                                                     readCount, virusResult = T)
  } else {
    speciesPercentageTopVirus = NULL
  }
  
  file.remove(noHit_files)
  
  rRNA_strandInfo = get_rRNA_Strandness(param, input)
  file.remove(input$getFullPaths("Read1"))
  if(param$paired)
    file.remove(input$getFullPaths("Read2"))
  
  #create report
  setwdNew(basename(output$getColumn("Report")))
  
  ## Copy the style files and templates
  styleFiles <- file.path(system.file("templates", package="ezRun"),
                          c("fgcz.css", "FastqScreen.Rmd",
                            "fgcz_header.html", "banner.png"))
  file.copy(from=styleFiles, to=".", overwrite=TRUE)
  
  ## generate the main reports
  rmarkdown::render(input="FastqScreen.Rmd", envir = new.env(),
                    output_dir=".", output_file=htmlFile, quiet=TRUE)
  return("Success")
}

##' @template app-template
##' @templateVar method ezMethodFastqScreen(input=NA, output=NA, param=NA, htmlFile="00index.html")
##' @description Use this reference class to run 
##' @section Functions:
##' \itemize{
##'   \item{\code{executeFastqscreenCMD(param, files): }}
##'   {Executes the fastqscreen command with given parameters on the input files.}
##'   \item{\code{collectFastqscreenOutput(dataset, files, resultFiles): }}
##'   {Collects the fastqscreen output after the result files have been obtained by \code{executeFastqscreenCMD()}.}
##'   \item{\code{executeBowtie2CMD(param, input): }}
##'   {Executes the bowtie2 command with given parameters on the input files.}
##'   \item{\code{collectBowtie2Output(param, dataset, countFiles): }}
##'   {Collects the bowtie2 output after the count files have been obtained by \code{executeBowtie2CMD()}.}
##'   \item{\code{fastqscreenReport(dataset, param, htmlFile="00index.html", fastqData, speciesPercentageTop): }}
##'   {Generates a report with plots and other information about the outcome of the run.}
##' }
EzAppFastqScreen <-
  setRefClass("EzAppFastqScreen",
              contains = "EzApp",
              methods = list(
                initialize = function()
                {
                  "Initializes the application using its specific defaults."
                  runMethod <<- ezMethodFastqScreen
                  name <<- "EzAppFastqScreen"
                  appDefaults <<- rbind(nTopSpecies=ezFrame(Type="integer",  DefaultValue=10,  Description="number of species to show in the plots"),
                                        confFile=ezFrame(Type="character",  DefaultValue="",  Description="the configuration file for fastq screen"),
                                        virusCheck=ezFrame(Type="logical",  DefaultValue=FALSE,  Description="check for viruses in unmapped data"),
                                        minAlignmentScore=ezFrame(Type="integer",  DefaultValue="-20",  Description="the min alignment score for bowtie2"),
                                        trimAdapter=ezFrame(Type="logical",  DefaultValue=TRUE,  Description="whether to search for the adapters and trim them"),
                                        copyReadsLocally=ezFrame(Type="logical",  DefaultValue=TRUE,  Description="copy reads to scratch first"))
                }
              )
  )

executeFastqscreenCMD = function(param, confFile = NULL, files){
  opt = ""
  if (param$nReads > 0){
    opt = paste(opt, "--subset", ezIntString(param$nReads))
  }
  cmd = paste("fastq_screen", opt, " --threads", param$cores, " --conf ", confFile,
              paste(files, collapse=" "), "--outdir . --nohits --aligner bowtie2",
              "> fastqscreen.out", "2> fastqscreen.err")
  ezSystem(cmd)
  resultFiles = paste0(sub(".fastq$", "", sub(".gz$", "", basename(files))), "_screen.txt") ## remove the suffix .fastq[.gz] with _screen.txt
  names(resultFiles) = names(files)
  return(resultFiles)
}

collectFastqscreenOutput = function(files, resultFiles){
  fastqData = list()
  fastqData$MappingRate = numeric()
  fastqData$Reads = integer()
  fastqData$CommonResults = list()
  for(nm in names(files)){
    cat('Process ',files[nm], " - ", resultFiles[nm], ' :')
    x = ezRead.table(resultFiles[nm], skip=1, stringsAsFactors=F, 
                     blank.lines.skip=T, fill=T, row.names=NULL)
    fastqData$Reads[nm] = x$"#Reads_processed"[1]
    if (nrow(x) > 0){
      UnmappedReads = as.numeric(unlist(strsplit(x$Genome[nrow(x)], split = " "))[2])
      fastqData$MappingRate[nm] = round((100 - UnmappedReads), digits = 2)
    } else {
      fastqData$MappingRate[nm] = 0
    }
    rownames(x) = x$Genome
    x = x[-nrow(x), grep('%.*hit',colnames(x))]
    fastqData$CommonResults[[nm]] = x ## can be a data.frame with 0 rows
  }
  return(fastqData)
}

executeBowtie2CMD = function(param, input){
  r1Files = input$getFullPaths("Read1")
  if (param$paired){
    r2Files = input$getFullPaths("Read2")
  }
  countFiles = character()
  for (nm in names(r1Files)){
    countFiles[nm] = paste0(nm, "-counts.txt")
    bowtie2options = param$cmdOptions
    writeLines("ReadID\tRefSeqID\tAlignmentScore", countFiles[nm])
    if(!param$paired){
      cmd = paste('bowtie2',"-x",REFSEQ_mRNA_REF, 
                  " -U ", r1Files[nm], bowtie2options ,"-p",param$cores,
                  "--no-unal --no-hd --mm", "2> ", paste0(nm, "_bowtie2.err"),
                  "| cut -f1,3,12", " |sed s/AS:i://g", ">>", countFiles[nm])
    } else {
      cmd = paste('bowtie2',"-x",REFSEQ_mRNA_REF, 
                  " -1 ", r1Files[nm]," -2 ", r2Files[nm], bowtie2options, "-p",param$cores,
                  "--no-discordant --no-mixed --no-unal --no-hd --mm",
                  "2> ", paste0(nm, "_bowtie2.err"),
                  "| cut -f1,3,12", " |sed s/AS:i://g", ">>", countFiles[nm])
    }
    ezSystem(cmd)
  }
  return(countFiles)
}

executeBowtie2CMD_Virus = function(param, files){
  r1Files = files
  countFiles = character()
  for (nm in names(r1Files)){
    countFiles[nm] = paste0(nm, "-counts.txt")
    bowtie2options = param$cmdOptions
    writeLines("ReadID\tRefSeqID\tAlignmentScore", countFiles[nm])
    cmd = paste('bowtie2',"-x",REFSEQ_pathogenicHumanViruses_REF, 
                  " -U ", r1Files[nm], bowtie2options ,"-p",param$cores,
                  "--no-unal --no-hd", "2> ", paste0(nm, "_bowtie2.err"),
                  "| cut -f1,3,12", " |sed s/AS:i://g", ">>", countFiles[nm])
    ezSystem(cmd)
  }
  return(countFiles)
}

get_rRNA_Strandness = function(param, input){
  rRNA_REF = '/srv/GT/reference/Silva/silva/release_123_1/SILVA_123.1_LSU_SSU'
  r1Files = input$getFullPaths("Read1")
  
  countFiles = character()
  for (nm in names(r1Files)){
    countFiles[nm] = paste0(nm, "-counts.txt")
    bowtie2options = param$cmdOptions
    writeLines("ReadID\tFlag\tID\tAlignmentScore", countFiles[nm])
    
      cmd = paste('bowtie2',"-x",rRNA_REF, 
                  " -U ", r1Files[nm], bowtie2options ,"-p",param$cores,
                  "--no-unal --no-hd --mm", "2> ", paste0(nm, "_bowtie2.err"),
                  "| cut -f1,2,3,12", " |sed s/AS:i://g", ">>", countFiles[nm])
    ezSystem(cmd)
  }

  rRNA_strandInfo = matrix(0, nrow = length(countFiles), ncol = 2)
  colnames(rRNA_strandInfo) = c('Sense', 'Antisense')
  rownames(rRNA_strandInfo) = names(r1Files)
  k = 1
  for (nm in names(countFiles)){
    countData = ezRead.table(countFiles[nm], row.names = NULL)
    bestScores = tapply(countData$AlignmentScore, countData$ReadID, max)
    countData = countData[countData$AlignmentScore == bestScores[countData$ReadID], , drop=FALSE]
    countData = countData[countData$AlignmentScore >= param$minAlignmentScore, , drop=FALSE]
    rRNA_strandInfo[k, 1] = length(which(countData$Flag == 0))
    rRNA_strandInfo[k, 2] = length(which(countData$Flag == 16))
    k = k + 1
  }
  ezWrite.table(rRNA_strandInfo, 'rRNA_strandInfo.txt')
  return(rRNA_strandInfo)
}

collectBowtie2Output = function(param, countFiles, readCount, virusResult = F){
  tax2name = read.table('/srv/GT/reference/RefSeq/mRNA/20150301/Annotation/tax2name.txt',
                        header=F, stringsAsFactors=F, sep='\t', 
                        colClasses="character", quote='', comment.char="")
  tax2name <- setNames(tax2name[ ,3], tax2name[ ,1])
  speciesPercentageTop = list()
  for (nm in names(countFiles)){
    countData = ezRead.table(countFiles[nm], row.names = NULL)
    bestScores = tapply(countData$AlignmentScore, countData$ReadID, max)
    countData = countData[countData$AlignmentScore == bestScores[countData$ReadID], , drop=FALSE]
    countData = countData[countData$AlignmentScore >= param$minAlignmentScore, , drop=FALSE]
    if (nrow(countData) > 0){
      if(virusResult){
        countData$species = substr(sub("_NC_[0-9].*", "", countData$RefSeqID), 1, 30)
      } else {
        countData$species = sub("_.*", "", countData$RefSeqID)
      }
      speciesHitsPerRead = tapply(countData$species, countData$ReadID, unique)
      uniqSpeciesHitsPerRead = names(speciesHitsPerRead)[lengths(speciesHitsPerRead) == 1]
      ###Result UniqHits:
      uniqSpeciesHits = sort(table(unlist(speciesHitsPerRead[uniqSpeciesHitsPerRead])), 
                             decreasing = T)
      ###Results MultipleHits:
      multipleSpeciesHitsPerRead = countData[!(countData$ReadID %in% uniqSpeciesHitsPerRead), ]
      by = paste(multipleSpeciesHitsPerRead$ReadID, 
                 multipleSpeciesHitsPerRead$species, sep='_')
      ##multipleSpeciesHits = sort(table(multipleSpeciesHitsPerRead$species[!duplicated(by)]), decreasing=T) # is equivalent to the row below
      multipleSpeciesHits = sort(table(tapply(multipleSpeciesHitsPerRead$species,by,unique)),
                                 decreasing = T)
      
      if (length(uniqSpeciesHits) > param$nTopSpecies){
        topSpeciesUniq = uniqSpeciesHits[1:param$nTopSpecies]
      } else {
        topSpeciesUniq = uniqSpeciesHits
      }
      ## Special case where all hits are multi hits --- in that case we sort according to the multi-hits
      if (length(uniqSpeciesHits) == 0){
        topSpeciesUniq = integer(min(param$nTopSpecies, length(multipleSpeciesHits)))
        names(topSpeciesUniq) = names(multipleSpeciesHits)[1:min(param$nTopSpecies, 
                                                                 length(multipleSpeciesHits))]
      }

      multipleSpeciesHits[setdiff(names(topSpeciesUniq), names(multipleSpeciesHits))] = 0
      topSpeciesMultiple = multipleSpeciesHits[names(topSpeciesUniq)]
      
      taxIds = names(topSpeciesUniq)
      taxNames = tax2name[taxIds]
      hasNoName = is.na(taxNames)
      taxNames[hasNoName] = taxIds[hasNoName]
      if(!virusResult){
        x = ezFrame(UniqueSpeciesHits=signif(100 * as.matrix(topSpeciesUniq)/readCount[nm,'totalReadCount'], digits=4),
                  MultipleSpeciesHits=signif(100 * as.matrix(topSpeciesMultiple)/readCount[nm,'totalReadCount'], digits=4),
                  row.names = taxNames)
      } else {
        x = ezFrame(UniqueSpeciesHits=signif(100 * as.matrix(topSpeciesUniq)/readCount[nm,'unmappedReadCount'], digits=4),
                    MultipleSpeciesHits=signif(100 * as.matrix(topSpeciesMultiple)/readCount[nm,'unmappedReadCount'], digits=4),
                    row.names = taxNames)  
      }
      speciesPercentageTop[[nm]] = x
    } else {
      speciesPercentageTop[[nm]] = NULL
    }
  }
  return(speciesPercentageTop)
}
