###################################################################
# Functional Genomics Center Zurich
# This code is distributed under the terms of the GNU General
# Public License Version 3, June 2007.
# The terms are available here: http://www.gnu.org/licenses/gpl.html
# www.fgcz.ch


ezMethodFastQC = function(input=NA, output=NA, param=NA, htmlFile="00index.html"){
  setwdNew(basename(output$getColumn("Report")))
  dataset = input$meta
  samples = rownames(dataset)
  files = c()
  for (sm in samples){
    files[paste0(sm, "_R1")] = input$getFullPaths("Read1")[sm]
    if (!is.null(dataset$Read2)){
      files[paste0(sm, "_R2")] = input$getFullPaths("Read2")[sm]    
    }
  }
  nFiles = length(files)
  
  ## guess the names of the report directories that will be creatd by fastqc
  reportDirs = sub(".fastq.gz", "_fastqc", basename(files))
  reportDirs = sub(".fq.gz", ".fq_fastqc", reportDirs)
  stopifnot(!duplicated(reportDirs))
  filesUse = files[!file.exists(reportDirs)]
  if (length(filesUse) > 0){
    cmd = paste("fastqc", "--extract -o . -t", min(ezThreads(), 8), param$cmdOptions,
                paste(filesUse, collapse=" "),
                "> fastqc.out", "2> fastqc.err")
    result = ezSystem(cmd)
  }
  statusToPng = c(PASS="tick.png", WARN="warning.png", FAIL="error.png")
  
  ## collect the overview table
  plots = c("Per base sequence quality"="per_base_quality.png",
            "Per sequence quality scores"="per_sequence_quality.png",
            "Per tile sequence quality"="per_tile_quality.png",
            "Per base sequence content"="per_base_sequence_content.png",
            "Per sequence GC content"="per_sequence_gc_content.png",
            "Per base N content"="per_base_n_content.png",
            "Sequence Length Distribution"="sequence_length_distribution.png",
            "Sequence Duplication Levels"="duplication_levels.png",
            "Adapter Content"="adapter_content.png",
            "Kmer Content"="kmer_profiles.png")
  
  ## make for each plot type an html report with all samples
  plotPages = sub(".png", ".html", plots)
  for (i in 1:length(plots)){
    plotDoc = openBsdocReport(title=paste("FASTQC:", plotPages[i]))
    png = paste0("<img src=", reportDirs, "/Images/", plots[i], ">")
    tbl = ezFlexTable(ezMatrix(png, rows=names(files), cols=names(plots)[i]), 
                      header.columns=TRUE, add.rownames=TRUE, valign="middle")
    addFlexTable(plotDoc, tbl)
    closeBsdocReport(plotDoc, plotPages[i])
  }
  
  ## establish the main report
  titles = list()
  titles[["FastQC"]] = paste("FASTQC:", param$name)
  doc = openBsdocReport(title=titles[[length(titles)]])
  
  addDataset(doc, dataset, param)
  
  titles[["Read Counts"]] = "Read Counts"
  addTitle(doc, titles[[length(titles)]], 2, id=titles[[length(titles)]])
  if (!is.null(dataset$"Read Count")){
    readCount = signif(dataset$"Read Count" / 1e6, digits=3)
    names(readCount) = rownames(dataset)
  } else {
    readCount = integer()
    for (i in 1:nFiles){
      x = ezRead.table(file.path(reportDirs[i], "fastqc_data.txt"), header=FALSE, nrows=7, fill=TRUE)
      readCount[names(files)[i]] = signif(as.integer(x["Total Sequences", 1]) / 1e6, digits=3)
    }
  }
  
  plotCmd = expression({
    par(mar=c(10.1, 4.1, 4.1, 2.1))
    bp = barplot(readCount, ylab="Counts [Mio]", main="total reads", names.arg = rep('',length(readCount)))
    text(x = bp, y = par("usr")[3]-0.2, srt = 45, adj = 1, labels = names(readCount), xpd = TRUE)
  })
  readCountsLink = ezImageFileLink(plotCmd, file="readCounts.png", width=min(600 + (nFiles-10)* 30, 2000)) # nSamples dependent width
  addParagraph(doc, readCountsLink)
  
  titles[["Fastqc quality measures"]] = "Fastqc quality measures"
  addTitle(doc, titles[[length(titles)]], 2, id=titles[[length(titles)]])
  statusToPng = c(PASS="tick.png", WARN="warning.png", FAIL="error.png")
  for (i in 1:nFiles){
    smy = ezRead.table(file.path(reportDirs[i], "summary.txt"), row.names=NULL, header=FALSE)
    if (i == 1){
      rowNames = paste0("<a href=", reportDirs, "/fastqc_report.html>", names(files), "</a>")
      colNames = ifelse(smy[[2]] %in% names(plotPages),
                        paste0("<a href=", plotPages[smy[[2]]], ">", smy[[2]], "</a>"),
                        smy[[2]])
      tbl = ezMatrix("", rows=rowNames, cols=colNames)
    }
    href = paste0(reportDirs[i], "/fastqc_report.html#M", 0:(ncol(tbl)-1))
    img = paste0(reportDirs[i], 	"/Icons/", statusToPng[smy[[1]]])
    tbl[i, ] = paste0("<a href=", href, "><img src=", img, "></a>")
  }
  addFlexTable(doc, ezFlexTable(tbl, header.columns=TRUE, add.rownames=TRUE, valign="middle"))
  
  titles[["Per Base Read Quality"]] = "Per Base Read Quality"
  addTitle(doc, titles[[length(titles)]], 2, id=titles[[length(titles)]])
  qualMatrixList = ezMclapply(files, getQualityMatrix, mc.cores=ezThreads())
  pngMatrix = plotQualityMatrixAsHeatmap(qualMatrixList, 
                                         isR2=grepl("_R2", names(qualMatrixList)))
  addFlexTable(doc, ezGrid(pngMatrix))
  if(nrow(dataset) > 1){
    pngLibCons = list()
    pngLibCons[["qPCR"]] = plotReadCountToLibConc(dataset, colname='LibConc_qPCR [Characteristic]')
    pngLibCons[["100_800bp"]] = plotReadCountToLibConc(dataset, colname='LibConc_100_800bp [Characteristic]')
    if(length(pngLibCons) > 0){
      titles[["Correlation"]] = "Correlation between Library concentration measurements and ReadCounts"
      addTitle(doc, titles[[length(titles)]], 3, id=titles[[length(titles)]])
      addFlexTable(doc, ezGrid(pngLibCons))
    }
  }
  closeBsdocReport(doc, htmlFile, titles)
  ezSystem(paste("rm -rf ", paste0(reportDirs, ".zip", collapse=" ")))
  return("Success")
}

plotReadCountToLibConc = function(dataset, colname){
  if(colname %in% colnames(dataset) && nrow(dataset) > 1){
    if(!all(dataset[[colname]]==0)){
      dataset = dataset[order(dataset$'Read Count',decreasing = T),]
      dataset$'Read Count' = dataset$'Read Count'/10^6
      corResult = cor.test(dataset$'Read Count',dataset[[colname]],method = 'spearman')
      regressionResult = lm(dataset[[colname]]~dataset$'Read Count')
      label = sub(' \\[.*','',colname)
      plotCmd = expression({
        plot(dataset$'Read Count', dataset[[colname]], pch=c(18), cex=1.5, main=label,
             xlab='ReadCount in Mio', ylab=sub('\\[.*','', colname), xlim=c(0, max(dataset$'Read Count', na.rm=TRUE)*1.2), #min(dataset$'Read Count')*0.8
             ylim=c(min(dataset[[colname]], na.rm = TRUE) * 0.8, max(dataset[[colname]], na.rm=TRUE) * 1.2))
        legend("topright", paste('r=', round(corResult$estimate, 2)), bty="n") 
        abline(regressionResult, col='red',lty=c(2))
        text(dataset$'Read Count', dataset[[colname]], pos=2,
             labels=rownames(dataset), cex=0.7, col='darkcyan')
      })
      link = ezImageFileLink(plotCmd, file=paste0('ReadCount_', label, '.png'))
      return(link)
    }
  }
  return(NULL)
}

plotQualityMatrixAsHeatmap = function(qualMatrixList, isR2=FALSE, xScale=1, yScale=1){
  pngFileNames = NULL
  colorsGray = gray((30:256)/256)
  minPercent = 0
  maxPercent = sqrt(40)
  minDiff = -5
  maxDiff = 5
  ## test if R2 exists
  index=list("R1"=which(!isR2))
  pngTable = data.frame(R1=character(0), stringsAsFactors=FALSE)
  if(any(isR2)){
    stopifnot(sum(isR2) == sum(!isR2))
    index[["R2"]]= which(isR2)
    pngTable[["R2"]] = character(0)
  }
  for(nm in names(index)){
    idx = index[[nm]]
    ## Plot the color key for the average quality heatmap R1_1
    colorKeyFile = paste0("averageReadsQuality-Key_", nm, ".png")
    by.label = 1
    at=seq(from=minPercent, to=maxPercent, by=by.label)
    plotCmd = expression({
      ezColorLegend(colorRange=c(minPercent, maxPercent), 
                    colors=colorsGray, vertical=FALSE, by.label=by.label,
                    at=at, labels=as.character(at^2))
    })
    colorKeyLink = ezImageFileLink(plotCmd, file=colorKeyFile, addPdfLink=FALSE, width=400*yScale, height=200*xScale)
    pngTable["Avg Qual Colors", nm] = colorKeyLink
    
    result = ezMatrix(0, dim=dim(qualMatrixList[[idx[1]]]))
    resultCount = result
    for(i in idx){
      qm = qualMatrixList[[i]]
      if (any(dim(qm) > dim(result))){
        oldResult = result
        result = ezMatrix(0, dim=dim(qm))
        result[1:nrow(oldResult), 1:ncol(oldResult)] = oldResult
        oldResultCount = resultCount
        resultCount = ezMatrix(0, dim=dim(qm))
        resultCount[1:nrow(oldResultCount), 1:ncol(oldResultCount)] = oldResultCount
      }
      result[1:nrow(qm), 1:ncol(qm)] = result[1:nrow(qm), 1:ncol(qm)] + qm
      resultCount[1:nrow(qm), 1:ncol(qm)] = resultCount[1:nrow(qm), 1:ncol(qm)] + 1
    }
    result = result / resultCount
    avgQual = signif(prop.table(result,2) * 100, digits=3)
    pngFileLink = plotQualityHeatmap(sqrt(avgQual), colorRange=c(minPercent, maxPercent), 
                                     pngFileName=paste0("averageReadsQuality-heatmap_", nm, ".png"),
                                     colors=colorsGray, main=paste("averageReadsQuality", nm, sep="_"), 
                                     xScale=xScale, yScale=yScale)
    pngTable["Average", nm] = pngFileLink
    
    ## plot the difference quality heatmap for R1_1
    colorKeyFile = paste0("diffReadsQuality-Key_", nm, ".png")
    at=seq(from=minDiff, to=maxDiff, by=by.label)
    plotCmd = expression({
      ezColorLegend(colorRange=c(minDiff, maxDiff), colors=getBlueRedScale(),
                    vertical=FALSE, by.label=by.label, at=at, labels=as.character(at))
    })
    colorKeyLink = ezImageFileLink(plotCmd, file=colorKeyFile, addPdfLink=FALSE, width=400*yScale, height=200*xScale)
    pngTable["Diff Qual Colors", nm] = colorKeyLink
    
    for(sampleName in names(qualMatrixList[idx])){
      qm = qualMatrixList[[sampleName]]
      diffResult = signif(prop.table(qm,2)*100, digits=3) - avgQual[1:nrow(qm), 1:ncol(qm)]
      pngFileLink = plotQualityHeatmap(diffResult, colorRange=c(minDiff, maxDiff), 
                                       pngFileName=paste0("diffReadsQuality-heatmap_", sampleName, ".png"),
                                       colors=getBlueRedScale(), main=paste("diffReadsQuality", sampleName, sep="_"),
                                       xScale=xScale, yScale=yScale)
      pngTable[sampleName, nm] = pngFileLink
    }
  }
  if(any(isR2)){
    pngTable = data.frame("R1"=na.omit(pngTable[,"R1"]), "R2"=na.omit(pngTable[,"R2"]), stringsAsFactors=FALSE)
  }
  
  return(pngTable)
}

plotQualityHeatmap = function(result, name=NULL, colorRange=c(0,sqrt(40)), colors=gray((1:256)/256), main=NULL, pngFileName=NULL, xScale=1, yScale=1){
  ## some ugly controls of labels
  labCol = seq(0, ncol(result), by=10)
  labCol[1] = 1
  labRow = seq(0, nrow(result)-1, by=5)
  
  result[result > colorRange[2]] = colorRange[2]
  result[result < colorRange[1]] = colorRange[1]
  
  plotCmd = expression({
    image(1:ncol(result), 1:nrow(result), t(result), zlim=colorRange, col=colors, xlab="Read Position", ylab="Read Quality", main=main, axes=FALSE)
    axis(1, at=labCol, labels=labCol)
    axis(2, at=seq(1, nrow(result),by=5), labels=labRow)
  })
  pngFileLink = ezImageFileLink(plotCmd, file=pngFileName, height=480*yScale, width=670*xScale)
  return(pngFileLink)
}
