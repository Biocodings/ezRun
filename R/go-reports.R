###################################################################
# Functional Genomics Center Zurich
# This code is distributed under the terms of the GNU General
# Public License Version 3, June 2007.
# The terms are available here: http://www.gnu.org/licenses/gpl.html
# www.fgcz.ch


##' @title Gets the GO cluster table
##' @description Gets the GO cluster table 
##' @param param a list of parameters to extract \code{pValThreshFisher} and \code{minCountFisher} from
##' @param clusterResult a list containing the result of the analysis done by \code{goClusterResults()}.
##' @param seqAnno the sequence annotation.
##' @template roxygen-template
##' @seealso \code{\link{goClusterResults}}
##' @return Returns a flex table containing the GO information of the cluster result.
goClusterTable = function(param, clusterResult, seqAnno){
  ontologies = names(clusterResult$GO)
  tables = ezMatrix("", rows=paste("Cluster", 1:clusterResult$nClusters), cols=ontologies)
  linkTable = ezMatrix("", rows = 1:clusterResult$nClusters, cols = ontologies)
  enrichrTable = ezMatrix("", rows = 1:clusterResult$nClusters, cols = "Enrichr")
  for (i in 1:clusterResult$nClusters){
    genesToUse = rownames(seqAnno) %in% names(clusterResult$clusterNumbers)[clusterResult$clusterNumbers==i]
    genesList = paste(seqAnno$gene_name[genesToUse], collapse="\\n")
    jsCall = paste0('enrich({list: "', genesList, '", popup: true});')
    enrichrTable[i, 1] = as.html(pot(paste0("<a href='javascript:void(0)' onClick='", jsCall, "'>Enrichr</a>")))
    for (onto in ontologies){
      x = clusterResult$GO[[onto]][[i]]
      goFrame = .getGoTermsAsTd(x, param$pValThreshFisher, param$minCountFisher, onto=onto)
      if (nrow(goFrame)==0) next
      linkTable[i, onto] = paste0("Cluster-", onto, "-", i, ".html")
      ezInteractiveTable(goFrame, tableLink=linkTable[i, onto], digits=3,
                         title=paste("GO categories of cluster", i, "and ontology", onto))
      linkTable[i, onto] = as.html(ezLink(linkTable[i, onto], target="_blank"))
      goFrame$Term = substr(goFrame$Term, 1, 30)
      if (nrow(goFrame) > 0){
        tables[i, onto] = as.html(ezFlexTable(goFrame, talign="right", header.columns = TRUE))
      }
    }
  }
  nameMap = c("BP"="Biological Proc. (BP)", "MF"="Molecular Func. (MF)", "CC"="Cellular Comp. (CC)")
  colnames(tables) = nameMap[colnames(tables)]
  ft = ezFlexTable(tables, border = 2, header.columns = TRUE, add.rownames=TRUE)
  bgColors = rep(gsub("FF$", "", clusterResult$clusterColors))
  ft = setFlexTableBackgroundColors(ft, j=1, colors=bgColors)
  return(list(ft=ft, linkTable=linkTable, enrichrTable=enrichrTable))
}

goClusterTableRmd = function(param, clusterResult, seqAnno){
  require(ReporteRs)
  ontologies = names(clusterResult$GO)
  ktables = list()
  linkTable = ezMatrix("", rows = 1:clusterResult$nClusters, cols = ontologies)
  enrichrTable = ezMatrix("", rows = 1:clusterResult$nClusters, cols = "Enrichr")
  for (i in 1:clusterResult$nClusters){
    genesToUse = rownames(seqAnno) %in% names(clusterResult$clusterNumbers)[clusterResult$clusterNumbers==i]
    genesList = paste(seqAnno$gene_name[genesToUse], collapse="\\n")
    jsCall = paste0('enrich({list: "', genesList, '", popup: true});')
    enrichrTable[i, 1] = as.html(pot(paste0("<a href='javascript:void(0)' onClick='", jsCall, "'>Enrichr</a>")))
    ## Prepare the table for kable
    ktableCluster <- list()
    for (onto in ontologies){
      x = clusterResult$GO[[onto]][[i]]
      goFrame = .getGoTermsAsTd(x, param$pValThreshFisher, param$minCountFisher, 
                                onto=onto)
      ktableCluster[[onto]] <- goFrame
      if (nrow(goFrame)==0)
        next
      linkTable[i, onto] = paste0("Cluster-", onto, "-", i, ".html")
      ezInteractiveTable(goFrame, tableLink=linkTable[i, onto], digits=3,
                         title=paste("GO categories of cluster", i, "and ontology", onto))
      linkTable[i, onto] = as.html(ezLink(linkTable[i, onto], target="_blank"))
      goFrame$Term = substr(goFrame$Term, 1, 30)
    }
    ## This is some ugly code to append some "" cell, so they can used in kable
    maxNrow <- max(sapply(ktableCluster, nrow))
    ktableCluster <- lapply(ktableCluster, 
                            function(x){rbind(as.matrix(x), 
                                              ezMatrix("", rows=seq_len(maxNrow-nrow(x)), 
                                                       cols=seq_len(ncol(x))))}
                            )
    ktableCluster <- do.call(cbind, ktableCluster)
    if(nrow(ktableCluster) == 0L){
      ## for later grouping in cluster kables, we need empty cells.
      ktableCluster <- ezMatrix("", rows=1, cols=colnames(ktableCluster))
    }
    ktables[[i]] <- ktableCluster
  }
  return(list(ktables=ktables, linkTable=linkTable, enrichrTable=enrichrTable))
}

##' @title Adds the GO up-down results
##' @description Adds the GO up-down results to an html file.
##' @template doc-template
##' @templateVar object result
##' @param param a list of parameters to pass to \code{goUpDownTables()} and extract \code{doZip} from.
##' @param goResult the GO result to get the up-down results from. Can be obtained by \code{twoGroupsGO()}.
##' @seealso \code{\link{twoGroupsGO}}
##' @template roxygen-template
addGoUpDownResult = function(doc, param, goResult){
  udt = goUpDownTables(param, goResult)
  addParagraph(doc, paste("Maximum number of terms displayed:", param$maxNumberGroupsDisplayed))
  
  addFlexTable(doc, ezFlexTable(udt$linkTable, add.rownames=TRUE))
  addTitle(doc, "GO categories that are overrepresented among significantly upregulated genes.", 3)
  addFlexTable(doc, udt$flexTables[["enrichUp"]])
  addTitle(doc, "GO categories that are overrepresented among significantly downregulated genes.", 3)
  addFlexTable(doc, udt$flexTables[["enrichDown"]])
  addTitle(doc, "GO categories that are overrepresented among all significantly regulated genes.", 3)
  addFlexTable(doc, udt$flexTables[["enrichBoth"]])
  
  revigoLinks = ezMatrix("", rows=c('enrichBoth', 'enrichDown', 'enrichUp'), cols=c('BP', 'CC', 'MF'))
  for (col in colnames(revigoLinks)){
    for (row in rownames(revigoLinks)){
      goSubResult = goResult[[col]][[row]]
      if (all(is.na(goSubResult))) next
      goSubResult = goSubResult[which(goSubResult$Pvalue < param$pValThreshFisher),]
      if(nrow(goSubResult) > param$maxNumberGroupsDisplayed) {
        goSubResult = goSubResult[1:param$maxNumberGroupsDisplayed,]
      }
      revigoLinks[row, col] = paste0('http://revigo.irb.hr/?inputGoList=',
                                       paste(rownames(goSubResult), goSubResult[,'Pvalue'], collapse='%0D%0A'))
      revigoLinks[row, col] = as.html(pot("ReViGO", hyperlink = revigoLinks[row, col]))
    }
  }
  revigoTitle = "ReViGO"
  addTitle(doc, revigoTitle, 3, id=revigoTitle)
  addFlexTable(doc, ezFlexTable(revigoLinks, valign="middle", header.columns = TRUE, add.rownames = TRUE))
  addTxtLinksToReport(doc, udt$txtFiles, param$doZip)
  return(revigoTitle)
}

revigoUpDownTables <- function(param, goResult){
  revigoLinks = ezMatrix("", rows=c('enrichUp', 'enrichDown', 'enrichBoth'), 
                         cols=c('BP', 'MF', 'CC'))
  for (col in colnames(revigoLinks)){
    for (row in rownames(revigoLinks)){
      goSubResult = goResult[[col]][[row]]
      if (all(is.na(goSubResult))) next
      goSubResult = goSubResult[which(goSubResult$Pvalue < param$pValThreshFisher),]
      if(nrow(goSubResult) > param$maxNumberGroupsDisplayed) {
        goSubResult = goSubResult[1:param$maxNumberGroupsDisplayed,]
      }
      revigoLinks[row, col] = paste0('http://revigo.irb.hr/?inputGoList=',
                                     paste(rownames(goSubResult), goSubResult[,'Pvalue'], collapse='%0D%0A'))
      revigoLinks[row, col] = as.html(pot("ReViGO", hyperlink = revigoLinks[row, col]))
    }
  }
  return(t(revigoLinks))
}

##' @describeIn addGoUpDownResult Gets the GO up-down tables.
goUpDownTables = function(param, goResult){
  require(ReporteRs)
  #goTable = ezMatrix("", rows="Cats", cols=names(goResult))
  goTable <- list()
  ktables = list("enrichUp"=goTable, "enrichDown"=goTable, "enrichBoth"=goTable)
  txtFiles = character() ## TODO make a list of list; similar to resultList
  ## txtList = list("enrichUp"=list(), "enrichBoth"=list(), "enrichDown"=list())
  linkTable = ezMatrix("", rows = names(goResult), 
                       cols = c("enrichUp", "enrichDown", "enrichBoth"))
  for (onto in names(goResult)){ ## BP, MF , CC
    x = goResult[[onto]]
    for (sub in names(x)){ #c("enrichUp", "enrichDown", "enrichBoth")){
      message("sub: ", sub)
      xSub = x[[sub]]
      if (is.data.frame(xSub)){
        ## We always output the goseq results files
        name = paste0(onto, "-", param$comparison, "-", sub)
        if (!is.null(xSub$Pvalue)){
          xSub = xSub[order(xSub$Pvalue), ]
          xSub = cbind("GO ID"=rownames(xSub), xSub)
        }
        txtFile = ezValidFilename(paste0(name, ".txt"), replace="-")
        txtFiles <- append(txtFiles, txtFile)
        # txtList[[sub]][[onto]] = ezValidFilename(paste0(name, ".txt"), replace="-")
        ezWrite.table(xSub, file=txtFile, row.names=FALSE)
      }
      goFrame = .getGoTermsAsTd(xSub, param$pValThreshFisher,
                                param$minCountFisher, onto=onto,
                                maxNumberOfTerms=param$maxNumberGroupsDisplayed)
      ktables[[sub]][[onto]] = goFrame
      if (nrow(goFrame)==0)
        next
      linkTable[onto, sub] = paste0("Cluster-", onto, "-", sub, ".html")
      ezInteractiveTable(goFrame, tableLink=linkTable[onto, sub], digits=3,
                         title=paste(sub("enrich", "", sub), 
                                     "enriched GO categories of ontology", onto))
      linkTable[onto, sub] = as.html(ezLink(linkTable[onto, sub], 
                                            target = "_blank"))
      #goFrame$Term = substr(goFrame$Term, 1, 30)
    }
  }
  for(sub in names(ktables)){
    ### Add the ""
    maxNrow <- max(sapply(ktables[[sub]], nrow))
    ktables[[sub]] <- lapply(ktables[[sub]],
                             function(x){rbind(as.matrix(x),
                                               ezMatrix("", rows=seq_len(maxNrow-nrow(x)),
                                                        cols=seq_len(ncol(x))))}
                             )
    ktables[[sub]] <- do.call(cbind, ktables[[sub]])
  }
  #nameMap = c("BP"="Biological Proc. (BP)", "MF"="Molecular Func. (MF)", "CC"="Cellular Comp. (CC)")
  return(list(ktables=ktables, txtFiles=txtFiles, linkTable=linkTable))
}

##' @describeIn goClusterTable Gets the GO terms and pastes them into a table.
.getGoTermsAsTd = function(x, pThreshGo, minCount, onto=NA, maxNumberOfTerms=40){
  
  require("GO.db")
  require(AnnotationDbi)
  
  if (!is.data.frame(x)){
    message("got no data frame")
    return(ezFrame("Term"=character(0), "ID"=character(0), 
                   "p"=numeric(0), "N"=integer(0)))
  }
  x = x[x$Count >= minCount & x$Pvalue < pThreshGo, ]
  x = x[order(x$Pvalue), ]
  if (nrow(x) > maxNumberOfTerms){
    x = x[1:maxNumberOfTerms, ]
  }
  if (nrow(x) == 0){
    return(ezFrame("Term"=character(0), "ID"=character(0),
                   "p"=numeric(0), "N"=integer(0)))
  }
  
  if (onto == "CC"){
    ANCESTOR = GOCCANCESTOR
    OFFSPRING = GOCCOFFSPRING
    CHILDREN = GOCCCHILDREN
  }
  if (onto == "BP"){
    ANCESTOR = GOBPANCESTOR
    OFFSPRING = GOBPOFFSPRING
    CHILDREN = GOBPCHILDREN
  }
  if (onto == "MF"){
    ANCESTOR = GOMFANCESTOR
    OFFSPRING = GOMFOFFSPRING
    CHILDREN = GOMFCHILDREN
  }
  
  goIds = rownames(x)
  goAncestorList = AnnotationDbi::as.list(ANCESTOR[goIds]) ## without the explicit choice of AnnotationDbi:: this fails in RnaBamStats ..... no idea why
  
  goRoots = character()
  for (goId in goIds){
    if (length(intersect(goIds, goAncestorList[[goId]])) == 0){
      goRoots[goId] = goId
    }
  }
  goOffsprings = unique(AnnotationDbi::as.list(OFFSPRING[goIds]))[[1]]
  goAncestors = unique(unlist(goAncestorList))
  goRelatives = union(intersect(goAncestors, goOffsprings), goIds)
  
  terms = character()
  ids = character()
  pValues = numeric()
  counts = character()
  for (i in 1:length(goRoots)){
    childTerms = getChildTerms(goRoots[i], goIds, goRelatives, indent="", CHILDREN)
    for (term in childTerms){
      terms = append(terms, names(childTerms)[childTerms==term])
      ids = append(ids, term)
      pValues = append(pValues, x[term, "Pvalue"])
      counts = append(counts, paste(x[term, "Count"], x[term, "Size"], sep="/"))
    }
  }
  return(ezFrame("Term"=terms, "ID"=ids,"p"=pValues, "N"=counts))
}
