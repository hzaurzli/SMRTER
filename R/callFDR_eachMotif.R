#' callFDR_eachMotif
#'
#' callFDR_eachMotif calculates in parallel the motif enrichment scores for all k-mer motifs
#'
#' @param smrt a data frame, taking at least columns: refName, strand, tpl, ipdRatio/score
#' @param split_smrt a list of smrt, which is a split smrt generated by the function splitSmrt()
#' @param genome a DNAStringSet value indicating the reference sequence. Refer to Biostrings:readDNAStringSet() 
#' @param kmer an integer value indicating the motif length of interest
#' @param meth_char a character value indicating the methylated base, by default "A"
#' @param cores an integer value indicating the number of cores for parallel computating
#' @param criterion a character value indicating the criterion for calling motif, either "ipdRatio" or "score", and by default, "ipdRatio" 
#' @param thres a numeric value indicating the threshold for the criterion, by default, 4 for ipdRatio
#'
#' @return a data frame comprising the following columns
#' \itemize{
#'  \item {motif} a character value indicating the methylation motifs
#'  \item {pos} an integer indicating the methylation position in the motif
#'  \item {score} a numeric value indicating the motif enrichment score for the corresponding motif
#' }
#' 
#' @export
#'
#' @examples
#' 
#' @seealso \code{\link{splitSmrt}}; \code{\link{callFDR}}; \code{\link{enumerateMotif}}; 
#' 
callFDR_eachMotif = function(  smrt=NULL , split_smrt=NULL , genome , kmer=4 , meth_char='A' , cores=10 , criterion="ipdRatio" , thres=4 ) 
{
  
  registerDoMC(cores)
  
  if( !is.null(smrt) & is.null(split_smrt) )
  {
    smrt = smrt[ as.character(smrt$base) == meth_char , ]
    background = smrt[,criterion]
    split_smrt = splitSmrt(smrt,sorted=F)
  } else {
    background = do.call(c,lapply(split_smrt,function(x) x[,criterion] ) )
  }
  
  methy_motif = enumerateMotif(kmer , meth_char)
  #methy_motif = subset(methy_motif , pos%in%c(2,3))
  
  fdr = foreach( mi = 1:nrow(methy_motif) )  %dopar%
  {
    motif = as.character(methy_motif[mi,1])
    methy_pos = methy_motif[mi,2]
    cat( '  ' , mi, ': searching for ',motif,' at position ' ,methy_pos,' ...\n')
    motifF = motif
    motifB = as.character(reverseComplement(DNAString(motif)))
    positionF = vmatchPattern(  motifF , genome , fixed=FALSE)
    positionB = vmatchPattern(  motifB , genome , fixed=FALSE)
    
    smrt_chr = list()
    chr_list = unique(gsub( ".[01]$" , "" , names(split_smrt) ))
    for( chr in chr_list )
    {
      posF_chr = start(positionF[[chr]]) + methy_pos - 1
      posB_chr = start(positionB[[chr]]) + nchar(motif) - methy_pos
      #smrt_chr_0 = subset( split_smrt[[chr]][['0']] , tpl %in% posF_chr )
      #smrt_chr_1 = subset( split_smrt[[chr]][['1']] , tpl %in% posB_chr )
      smrt_chr_0 = subset( split_smrt[[ paste0(chr,'.0') ]] , tpl %in% posF_chr )
      smrt_chr_1 = subset( split_smrt[[ paste0(chr,'.1') ]] , tpl %in% posB_chr )
      smrt_chr[[chr]] = rbind(smrt_chr_0 , smrt_chr_1)
    }
    
    smrt_motif = do.call(rbind,smrt_chr)
    
    thresList = sort( unique(c(seq(1,6,.5),thres)) )
    callFDR( foreground=smrt_motif[,criterion] , background=background , thresList=thresList , adjust=F )
    
  }
  
  score = sapply(fdr,function(x) x[fdr[[1]][,1]==thres,2] )
  
  data.frame( methy_motif , score )

}

