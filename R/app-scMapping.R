###################################################################
# Functional Genomics Center Zurich
# This code is distributed under the terms of the GNU General
# Public License Version 3, June 2007.
# The terms are available here: http://www.gnu.org/licenses/gpl.html
# www.fgcz.ch

### EzAppSingleCellSTAR
EzAppSingleCellSTAR <- 
  setRefClass("EzAppSingleCellSTAR",
              contains = "EzApp",
              methods = list(
                initialize = function()
                {
                  "Initializes the application using its specific defaults."
                  runMethod <<- ezMethodSingleCellSTAR
                  name <<- "EzAppSingleCellSTAR"
                  appDefaults <<- rbind(getJunctions=ezFrame(Type="logical",  DefaultValue="FALSE",	Description="should junctions be returned"),
                                        writeIgvSessionLink=ezFrame(Type="logical", DefaultValue="TRUE", Description="should an IGV link be generated"),
                                        markDuplicates=ezFrame(Type="logical", DefaultValue="FALSE", Description="should duplicates be marked with picard"),
                                        checkStrandness=ezFrame(Type="logical", DefaultValue="TRUE", Description="should strandness be checked"),
                                        randomSleep=ezFrame(Type="logical",  DefaultValue="FALSE",  Description="should there be a random sleep to avoid to much network traffic when loading the STAR index"),
                                        twopassMode=ezFrame(Type="logical", DefaultValue="FALSE", Description="1-pass mapping or basic 2-pass mapping")
                  )
                }
              )
  )
### STAR for single cell data: reads in a unmapped bam
###
ezMethodSingleCellSTAR = function(input=NA, output=NA, param=NA){
  
  refDir = getSTARReference(param)
  bamFile = output$getColumn("BAM")
  if(!is.null(param$randomSleep)){
    if(param$randomSleep){
      randomNumber = runif(1, min = 0, max = 1)
      if(randomNumber <= 1/3) {
        cat('Wait 15m \n')
        Sys.sleep( 900) 
      } else if(randomNumber > 1/3 & randomNumber <= 2/3) {
        cat('Wait 30m \n')
        Sys.sleep( 1800)
      }
    }
  }
  
  if(input$readType() == "bam"){
    fastqInput <- ezMethodBam2Fastq(input = input, param = param)
    trimmedInput <- ezMethodTrim(input = fastqInput, param = param)
    ## BAM to fastq, fastq is local. 
    ## Better not to do the cleaning in ezMethodTrim 
    file.remove(fastqInput$getFullPaths("Read1"))
    if (param$paired){
      file.remove(fastqInput$getFullPaths("Read2"))
    }
  }else{
    trimmedInput <- ezMethodTrim(input = input, param = param)
  }
  if(param$cmdOptions == "")
    param$cmdOptions <- "--outFilterType BySJout --outFilterMatchNmin 30 --outFilterMismatchNmax 10 --outFilterMismatchNoverLmax 0.05 --alignSJDBoverhangMin 1 --alignSJoverhangMin 8 --alignIntronMax 1000000 --alignMatesGapMax 1000000  --outFilterMultimapNmax 50 --chimSegmentMin 15 --chimJunctionOverhangMin 15 --chimScoreMin 15 --chimScoreSeparation 10 --outSAMstrandField intronMotif --outSAMattributes All"
  
  if (!grepl("outSAMattributes", param$cmdOptions)){
    param$cmdOptions = paste(param$cmdOptions, "--outSAMattributes All")
  }
  cmd = paste("STAR", " --genomeDir", refDir,  "--sjdbOverhang 150", 
              "--readFilesIn", trimmedInput$getColumn("Read1"), 
              if(param$paired) trimmedInput$getColumn("Read2"),
              "--twopassMode", ifelse(param$twopassMode, "Basic", "None"),
              "--runThreadN", ezThreads(), param$cmdOptions, 
              "--outStd BAM_Unsorted --outSAMtype BAM Unsorted",
              ">  Aligned.out.bam")## writes the output file Aligned.out.bam
  ##"|", "samtools", "view -S -b -", " >", "Aligned.out.bam")
  ezSystem(cmd)
  file.remove(trimmedInput$getColumn("Read1"))
  if(param$paired)
    file.remove(trimmedInput$getColumn("Read2"))
  
  on.exit(file.remove(c("Log.progress.out", "Log.out", 
                        "Log.std.out")), add=TRUE) ## clean star log files
  on.exit(unlink(c("_STARgenome", "_STARpass1"),
                 recursive = TRUE, force = TRUE), add=TRUE)
  
  ## Merge unmapped and mapped bam to recover the tags
  if(input$readType() == "bam"){
    mergeBamAlignments(alignedBamFn="Aligned.out.bam",
                       unmappedBamFn=input$getFullPaths("Read1"),
                       outputBamFn="Aligned.out.merged.bam",
                       fastaFn=param$ezRef@refFastaFile)
    file.remove("Aligned.out.bam")
    file.rename(from="Aligned.out.merged.bam", to="Aligned.out.bam")
  }
  
  nSortThreads = min(ezThreads(), 8)
  ## if the index is loaded in shared memory we have to use only 10% of the scheduled RAM
  if (grepl("--genomeLoad LoadAndKeep", param$cmdOptions)){
    sortRam = param$ram / 10
  } else {
    sortRam = param$ram
  }
  
  file.rename('Log.final.out', to = basename(output$getColumn("STARLog")))
  
  if (!is.null(param$markDuplicates) && param$markDuplicates){
    ezSortIndexBam("Aligned.out.bam", "sorted.bam", ram=sortRam, removeBam=TRUE, 
                   cores=nSortThreads)
    javaCall = paste0("java", " -Djava.io.tmpdir=. -Xmx", 
                      min(floor(param$ram), 10), "g")
    cmd = paste0(javaCall, " -jar ", "$Picard_jar", " MarkDuplicates ",
                 " TMP_DIR=. MAX_RECORDS_IN_RAM=2000000", " I=", "sorted.bam",
                 " O=", basename(bamFile),
                 " REMOVE_DUPLICATES=false", ## do not remove, do only mark
                 " ASSUME_SORTED=true",
                 " VALIDATION_STRINGENCY=SILENT",
                 " METRICS_FILE=" ,"dupmetrics.txt",
                 " VERBOSITY=WARNING",
                 " >markdup.stdout 2> markdup.stderr")
    on.exit(file.remove(c("markdup.stdout", "markdup.stderr")), add=TRUE)
    
    ezSystem(cmd)
    ezSystem(paste("samtools", "index", basename(bamFile)))
  } else {
    ezSortIndexBam("Aligned.out.bam", basename(bamFile), ram=sortRam, 
                   removeBam=TRUE, cores=nSortThreads)
  }
  
  if (param$getJunctions){
    ezSystem(paste("mv SJ.out.tab", basename(output$getColumn("Junctions"))))
    ezSystem(paste("mv Chimeric.out.junction", 
                   basename(output$getColumn("Chimerics"))))
  }else{
    on.exit(file.remove(c("SJ.out.tab", "Chimeric.out.junction",
                          "Chimeric.out.sam")), add=TRUE)
  }
  
  ## check the strandedness
  if (!is.null(param$checkStrandness) && param$checkStrandness){
    cat(Sys.getenv("PATH"), "\n")
    bedFile = getReferenceFeaturesBed(param)
    ezSystem(paste("infer_experiment.py", "-r", bedFile,
                   "-i", basename(bamFile), "-s 1000000"))
  }
  
  ## write an igv link
  if (param$writeIgvSessionLink){ 
    writeIgvSession(genome = getIgvGenome(param), 
                    refBuild=param$ezRef["refBuild"], 
                    file=basename(output$getColumn("IGV Session")),
                    bamUrls = paste(PROJECT_BASE_URL, bamFile, sep="/") )
    writeIgvJnlp(jnlpFile=basename(output$getColumn("IGV Starter")), 
                 projectId = sub("\\/.*", "", bamFile),
                 sessionUrl = paste(PROJECT_BASE_URL, 
                                    output$getColumn("IGV Session"), sep="/"))
  }
  return("Success")
}
