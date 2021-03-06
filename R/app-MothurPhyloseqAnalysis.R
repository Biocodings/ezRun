###################################################################
# Functional Genomics Center Zurich
# This code is distributed under the terms of the GNU General
# Public License Version 3, June 2007.
# The terms are available here: http://www.gnu.org/licenses/gpl.html
# www.fgcz.ch


ezMethodMothurPhyloSeqAnalysis = function(input=NA, output=NA, param=NA, 
                          htmlFile="00index.html"){
  require(rmarkdown)
  require(ShortRead)
  require(phyloseq)
  require(plyr)
  require(ape)
  require(ggplot2)
  dataset = input$meta

### analyze results with phyloseq
### load OTUs, taxa and sample file 
#IlluminaOtuFileName = "Illumina.good.unique.good.filter.unique.precluster.pick.pick.pick.opti_mcc.shared"
#PacbioOtuFileName = "PacBio.good.unique.good.filter.unique.precluster.pick.pick.opti_mcc.shared"

#IlluminaTaxaFileName = "Illumina.good.unique.good.filter.unique.precluster.pick.pick.pick.opti_mcc.0.03.cons.taxonomy"
#PacBioTaxaFileName = "PacBio.good.unique.good.filter.unique.precluster.pick.pick.opti_mcc.0.03.cons.taxonomy"

#sampleFileNamePacBio = ""


### OTUs
otuObjectPacBio <- phyloSeqOTU(input$OTU_pacbio)
otuObjectIllumina <- phyloSeqOTU(input$OTU_Illumina)
### taxonomy
taxaObjectPacBio <- phyloSeqTaxa(input$Taxonomy_pacbio)
taxaObjectIllumina <- phyloSeqTaxa(input$Taxonomy_Illumina)
### Samples
designMatrix <- param$designMatrix 
sampleObjectIllumina <- designMatrix[designMatrix$`Technology [Factor]` == "Illumina",]
sampleObjectIllumina <- phyloSeqSample(sampleObjectIllumina)
sampleObjectPacbio <- designMatrix[designMatrix$`Technology [Factor]` == "PacBio",]
sampleObjectPacbio <- phyloSeqSample(sampleObjectPacbio)



### create, add trees and preprocess phyloseq object 
physeqIllNoTree = phyloseq(otuObjectIllumina, taxaObjectIllumina,sampleObjectIllumina)
treeObjectIll = rtree(ntaxa(physeqIllNoTree), rooted=TRUE, tip.label=taxa_names(physeqIllNoTree))
physeqIll <- merge_phyloseq(physeqIllNoTree,treeObjectIll)
physeqIll <- phyloSeqPreprocess(physeqIll)

physeqPacBioNoTree = phyloseq(otuObjectPacBio, taxaObjectPacBio, sampleObjectPacbio)
treeObjectPacbio = rtree(ntaxa(physeqPacBioNoTree), rooted=TRUE, tip.label=taxa_names(physeqPacBioNoTree))
physeqPacBio <-  merge_phyloseq(physeqPacBioNoTree,treeObjectPacbio)
physeqPacBio <- phyloSeqPreprocess(physeqPacBio)

### create plots: 1. abundance
illAbPlot <- plot_bar(physeqIll, "Group", "Abundance", "Phylum")
+ geom_bar(aes(color=Phylum, fill=Phylum), stat="identity", position="stack")
pbAbPlot <- plot_bar(pbAbPlot, "Group", "Abundance", "Phylum")
+ geom_bar(aes(color=Phylum, fill=Phylum), stat="identity", position="stack")

### create plots: 2. ordination
pbOrd <- ordinate(physeqPacBio, "NMDS", "bray")
plotOrdTaxaPB = plot_ordination(physeqPacBio, pbOrd, type="taxa", color="Phylum", title="Taxa") + facet_wrap(~Phylum, 3)
plotOrdSamplesPB = plot_ordination(GP1, GP.ord, type="samples", color="Group") 
plotOrdSamplesPB = plotOrdSamplesPB + geom_polygon(aes(fill=Group)) + geom_point(size=5) + ggtitle("Samples")

illOrd <- ordinate(physeqIll, "NMDS", "bray")
plotOrdTaxaIll = plot_ordination(physeqIll, illOrd, type="taxa", color="Phylum", title="Taxa") + facet_wrap(~Phylum, 3)
plotOrdSamplesIll = plot_ordination(GP1, GP.ord, type="samples", color="Group") 
plotOrdSamplesIll = pplotOrdSamplesIll + geom_polygon(aes(fill=Group)) + geom_point(size=5) + ggtitle("samples")

### create plots: 3. richness 
plotRichIll <- plot_richness(physeqIll, x="Group", measures=c("Chao1", "Shannon"))
plotRichPB <- plot_richness(physeqPB, x="Group", measures=c("Chao1", "Shannon"))

### create plots: 4. tree
pruned_physeqIll <- 
plotTreeIll <- plot_tree(physeqIll , ladderize="left", color="Group")
plotTreePB<- plot_tree(plotRichPB , ladderize="left", color="Group")

### create plots: 3. heatmap
plot_heatmap(physeq2, taxa.label="Phylum")

  ## Copy the style files and templates
  styleFiles <- file.path(system.file("templates", package="ezRun"),
                          c("fgcz.css", "FastQC.Rmd", "FastQC_overview.Rmd",
                            "fgcz_header.html", "banner.png"))
  file.copy(from=styleFiles, to=".", overwrite=TRUE)
  
  plots = c("Summary of sequences in each sample.png",
            "Per sequence quality scores"="per_sequence_quality.png",
            "Per tile sequence quality"="per_tile_quality.png",
            "Per base sequence content"="per_base_sequence_content.png",
            "Per sequence GC content"="per_sequence_gc_content.png",
            "Per base N content"="per_base_n_content.png",
            "Sequence Length Distribution"="sequence_length_distribution.png",
            "Sequence Duplication Levels"="duplication_levels.png",
            "Adapter Content"="adapter_content.png",
            "Kmer Content"="kmer_profiles.png")
}
 
##' @template app-template
##' @templateVar method ezMethodMothurPhyloSeqAnalysis()
##' @templateVar htmlArg )
##' @description Use this reference class to run 
EzAppMothurPhyloSeqAnalysis <-
  setRefClass("EzAppMothurPhyloSeqAnalysis",
              contains = "EzApp",
              methods = list(
                initialize = function()
                {
                  "Initializes the application using its specific defaults."
                  runMethod <<- ezMethodMothurPhyloSeqAnalysis
                  name <<- "EzAppMothurPhyloSeqAnalysis"
                  appDefaults <<- rbind(cutOff = ezFrame(Type="numeric",  DefaultValue="0,03",Description="Cut-off for OTU clustering.")
                  )
                }
              )
  )
