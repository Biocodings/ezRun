context("Mapping apps with example data")

## this tests do take long therefore we only run them if the environment variable RUN_LONG_TEST is set to TRUE
# Sys.setenv(RUN_LONG_TEST=TRUE)

cwd = getwd()

skipLong = function(){
  if (Sys.getenv("RUN_LONG_TEST") == "TRUE"){
    return()
  } else {
    skip("not running lengthy tests")
  }
}

yeastCommonMapParam = function(){
  param = list()
  param[['cores']] = '8'
  param[['ram']] = '20'
  param[['scratch']] = '100'
  param[['node']] = ''
  param[['process_mode']] = 'SAMPLE'
  param[['refBuild']] = 'Schizosaccharomyces_pombe/Ensembl/EF2/Annotation/Version-2013-03-07'
  param[['paired']] = 'true'
  param[['cmdOptions']] = ''
  param[['strandMode']] = 'sense'
  param[['refFeatureFile']] = 'genes.gtf'
  param[['trimAdapter']] = 'false'
  param[['trimLeft']] = '0'
  param[['trimRight']] = '0'
  param[['minTailQuality']] = '0'
  param[['specialOptions']] = ''
  param[['mail']] = ''
  param[['dataRoot']] = system.file(package="ezRun", mustWork = TRUE)
  param[['resultDir']] = 'p1001/Map_Result'
  return(param)
}

test_that("Tophat", {
  skipLong()
  ezSystem("rm -fr /scratch/test_tophat/*")
  setwdNew("/scratch/test_tophat")
  param = yeastCommonMapParam()
  input = EzDataset$new(file=system.file("extdata/yeast_10k/dataset.tsv", package="ezRun", mustWork = TRUE), dataRoot=param$dataRoot)
  output = list()
  output[['Name']] = 'wt_1'
  output[['BAM [File]']] = 'p1001/Map_Tophat_5750_2015-10-07--09-46-36/wt_1.bam'
  output[['BAI [File]']] = 'p1001/Map_Tophat_5750_2015-10-07--09-46-36/wt_1.bam.bai'
  output[['IGV Starter [Link]']] = 'p1001/Map_Tophat_5750_2015-10-07--09-46-36/wt_1-igv.jnlp'
  output[['Species']] = 'S. cerevisiae'
  output[['refBuild']] = 'Saccharomyces_cerevisiae/Ensembl/EF4/Annotation/Version-2013-03-18'
  output[['paired']] = 'true'
  output[['refFeatureFile']] = 'genes.gtf'
  output[['strandMode']] = 'sense'
  output[['Read Count']] = '9794'
  output[['IGV Starter [File]']] = 'p1001/Map_Tophat_5750_2015-10-07--09-46-36/wt_1-igv.jnlp'
  output[['IGV Session [File]']] = 'p1001/Map_Tophat_5750_2015-10-07--09-46-36/wt_1-igv.xml'
  output[['Genotype [Factor]']] = 'wt'
  myApp = EzAppTophat$new()
  myApp$run(input=input$copy()$subset(1), output=output, param=param)
  setwd(cwd)
})

test_that("Map_Star", {
  skipLong()
  ezSystem("rm -fr /scratch/test_star/*")
  setwdNew("/scratch/test_star")
  param = yeastCommonMapParam()
  input = EzDataset$new(file=system.file("extdata/yeast_10k/dataset.tsv", package="ezRun", mustWork = TRUE),dataRoot=param$dataRoot)
  output = EzDataset$new(file=system.file("extdata/yeast_10k_STAR/dataset.tsv", package="ezRun", mustWork = TRUE), dataRoot=param$dataRoot)
  param[['cmdOptions']] = '--outFilterType BySJout --outFilterMatchNmin 30 --outFilterMismatchNmax 10 --outFilterMismatchNoverLmax 0.05 --alignSJDBoverhangMin 1 --alignSJoverhangMin 8 --alignIntronMax 1000000 --alignMatesGapMax 1000000 --outFilterMultimapNmax 50 --chimSegmentMin 15 --chimJunctionOverhangMin 15 --chimScoreMin 15 --chimScoreSeparation 10 --outSAMstrandField intronMotif'
  param[['getChimericJunctions']] = 'false'
  myApp = EzAppSTAR$new()
  myApp$run(input=input$copy()$subset(1), output=output$copy()$subset(1), param=param)
  setwd(cwd)
})

test_that("Map_Bowtie", {
  skipLong()
  ezSystem("rm -fr /scratch/test_bowtie/*")
  setwdNew("/scratch/test_bowtie")
  param = yeastCommonMapParam()
  input = EzDataset$new(file=system.file("extdata/yeast_10k/dataset.tsv", package="ezRun", mustWork = TRUE), dataRoot=param$dataRoot)
  output = EzDataset$new(file=system.file("extdata/yeast_10k_STAR/dataset.tsv", package="ezRun", mustWork = TRUE), dataRoot=param$dataRoot)
  myApp = EzAppBowtie$new()
  myApp$run(input=input$copy()$subset(1), output=output$copy()$subset(1), param=param)
  setwd(cwd)
})

test_that("Map_Bowtie2", {
  skipLong()
  ezSystem("rm -fr /scratch/test_bowtie2/*")
  setwdNew("/scratch/test_bowtie2")
  param = yeastCommonMapParam()
  input = EzDataset$new(file=system.file("extdata/yeast_10k/dataset.tsv", package="ezRun", mustWork = TRUE), dataRoot=param$dataRoot)
  output = EzDataset$new(file=system.file("extdata/yeast_10k_STAR/dataset.tsv", package="ezRun", mustWork = TRUE), dataRoot=param$dataRoot)
  param[['cmdOptions']] = '--no-unal'
  myApp = EzAppBowtie2$new()
  myApp$run(input=input$copy()$subset(1), output=output$copy()$subset(1), param=param)
  setwd(cwd)
})

test_that("Map_Bwa", {
  skipLong()
  ezSystem("rm -fr /scratch/test_bwa/*")
  setwdNew("/scratch/test_bwa")
  param = yeastCommonMapParam()
  input = EzDataset$new(file=system.file("extdata/yeast_10k/dataset.tsv", package="ezRun", mustWork = TRUE), dataRoot=param$dataRoot)
  output = EzDataset$new(file=system.file("extdata/yeast_10k_STAR/dataset.tsv", package="ezRun", mustWork = TRUE),dataRoot=param$dataRoot)
  param[['algorithm']] = 'aln'
  myApp = EzAppBWA$new()
  myApp$run(input=input$copy()$subset(1), output=output$copy()$subset(1), param=param)
  setwd(cwd)
})

# system command fails
# test_that("Map_Bismark", {
#   skipLong()
#   ezSystem("rm -fr /scratch/test_bismark/*")
#   setwdNew("/scratch/test_bismark")
#   input = EzDataset$new(file=system.file("extdata/yeast_10k/dataset.tsv", package="ezRun", mustWork = TRUE))
#   output = EzDataset$new(file=system.file("extdata/yeast_10k_STAR/dataset.tsv", package="ezRun", mustWork = TRUE))
#   param = yeastCommonMapParam()
#   param[['cmdOptions']] = '-bowtie2 --maxins 800'
#   param[['mail']] = ''
#   myApp = EzAppBismark$new()
#   myApp$run(input=input$copy()$subset(1), output=output$copy()$subset(1), param=param)
#   setwd(cwd)
# })

test_that("FastQC", {
  skipLong()
  ezSystem("rm -fr /scratch/test_fastqc/*")
  setwdNew("/scratch/test_fastqc")
  param = yeastCommonMapParam()
  input = EzDataset$new(file=system.file("extdata/yeast_10k/dataset.tsv", package="ezRun", mustWork = TRUE),dataRoot=param$dataRoot)
  output = list()
  output[['Name']] = 'FastQC_Result'
  output[['Report [File]']] = 'p1001/FastQC_Result'
  output[['Html [Link]']] = 'p1001/FastQC_Result/00index.html'
  param[['process_mode']] = 'DATASET'
  param[['ram']] = '50'
  param[['name']] = 'FastQC_Result'
  myApp = EzAppFastqc$new()
  myApp$run(input=input, output=output, param=param)
  setwd(cwd)
})

test_that("FastqScreen", {
  skipLong()
  ezSystem("rm -fr /scratch/test_fastqscreen/*")
  setwdNew("/scratch/test_fastqscreen")
  param = yeastCommonMapParam()
  input = EzDataset$new(file=system.file("extdata/yeast_10k/dataset.tsv", package="ezRun", mustWork = TRUE),dataRoot=param$dataRoot)
  output = list()
  output[['Name']] = 'FastqScreen_Result'
  output[['Report [File]']] = 'p1001/FastqScreen_Result'
  output[['Html [Link]']] = 'p1001/FastqScreen_Result/00index.html'
  param[['process_mode']] = 'DATASET'
  param[['name']] = 'FastqScreen_Result'
  param[['ram']] = '40'
  param[['nReads']] = '5000'
  param[['nTopSpecies']] = '5'
  param[['minAlignmentScore']] = '-20'
  param[['confFile']] = 'variousSpecies_rRNA_20140901_silva119.conf'
  param[['cmdOptions']] = '-k 10 --trim5 1 --trim3 4'
  myApp = EzAppFastqScreen$new()
  myApp$run(input=input$copy()$subset(1:2), output=output, param=param)
  setwd(cwd)
})

test_that("BampreviewStar", {
  skipLong()
  ezSystem("rm -fr /scratch/test_bampreview_star/*")
  setwdNew("/scratch/test_bampreview_star")
  param = yeastCommonMapParam()
  input = EzDataset$new(file=system.file("extdata/yeast_10k/dataset.tsv", package="ezRun", mustWork = TRUE),dataRoot=param$dataRoot)
  output = list()
  output[['Name']] = 'BAM_Preview'
  output[['Report [File]']] = 'p1001/BAM_Preview'
  output[['Html [Link]']] = 'p1001/BAM_Preview/00index.html'
  output[['Species']] = ''
  output[['refBuild']] = 'Schizosaccharomyces_pombe/Ensembl/EF2/Annotation/Version-2013-03-07'
  output[['refFeatureFile']] = 'genes.gtf'
  param[['process_mode']] = 'DATASET'
  param[['name']] = 'BAM_Preview'
  param[['strandMode']] = 'both'
  param[['subsampleReads']] = 2
  param[['mapMethod']] = 'STAR'
  param[['mapOptions']] = ''
  param[['trimAdapter']] = 'true'
  param[['trimLeft']] = '1'
  myApp = EzAppBamPreview$new()
  myApp$run(input=input, output=output, param=param)
  setwd(cwd)
})

## trinity fails with the small training data set
# test_that("Assemble_Trinity", {
#   skipLong()
#   setwdNew("/scratch/test_trinity")
#   input = EzDataset$new(file=system.file("extdata/yeast_10k/dataset.tsv", package="ezRun", mustWork = TRUE))
#   output = list()
#   output[['Name']] = 'Trinity_Assembly'
#   output[['Fasta [File]']] = 'p1001/Trinity_Assembly.fasta'
#   param = yeastCommonMapParam()
#   param[['process_mode']] = 'DATASET'
#   param[['name']] = 'Trinity_Assembly'
#   param[['trimAdapter']] = 'true'
#   param[['minAvgQuality']] = '0'
#   param[['minReadLength']] = '10'
#   param[['trinityOpt']] = '--min_kmer_cov 2'
#   myApp = EzAppTrinity$new()
#   myApp$run(input=input, output=output, param=param)
#   setwd(cwd)
# })
