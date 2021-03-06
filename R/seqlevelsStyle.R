### =========================================================================
### seqlevelsStyle() and related low-level utilities
### -------------------------------------------------------------------------


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Helper functions
###

.getDatadir <-
    function()
{
    system.file(package = "GenomeInfoDb","extdata","dataFiles")
}

.getNamedFiles <-
    function()
{
    filePath <- .getDatadir()
    files <- dir(filePath, full.names=TRUE, pattern =".txt$")
    setNames(files, sub(".txt$", "", basename(files)))
}

.normalize_organism <- function(organism)
{
    parts <- CharacterList(strsplit(organism, "_| "))
    parts_eltNROWS <- elementNROWS(parts)
    ## If 3 parts or more (e.g. "Canis_lupus_familiaris") then remove part 2.
    idx3 <- which(parts_eltNROWS >= 3L)
    if (length(idx3) != 0L)
        parts[idx3] <- parts[idx3][rep.int(list(-2L), length(idx3))]
    unstrsplit(parts, sep="_")
}

.getDataInFile <- function(organism)
{
    organism2 <- .normalize_organism(organism)
    filename <- paste0(.getDatadir(), "/", organism2, ".txt")
    if (file.exists(filename)) {
        read.table(filename, header=TRUE, sep="\t", stringsAsFactors=FALSE)
    } else {
        stop("Organism ", organism, " is not supported by GenomeInfoDb")
    }

}

.isTRUEorFALSE <- 
    function (x)
{
    is.logical(x) && length(x) == 1L && !is.na(x)
}


.supportedSeqlevelsStyles <-
    function()
{
    dom <- lapply(.getNamedFiles(), scan, nlines=1, what=character(),
                  quiet=TRUE)
    lapply(dom, function(x) {x[!(x %in% c("circular","auto","sex"))] })
}


.isSupportedSeqnamesStyle <-
    function(organism, style)
{
    organism <- .normalize_organism(organism)
    possible <- lapply(.getNamedFiles(), scan, nlines=1, what=character(),
                       quiet=TRUE)
    availStyles <- possible[[organism]]
    style %in% availStyles[-which(availStyles %in% c("circular","auto","sex"))]
}

.supportedSeqnameMappings <-
    function()
{
    dom <-  lapply(.getNamedFiles(), read.table, header=TRUE, sep="\t",
                   stringsAsFactors=FALSE)
    lapply(dom, function(x) {x[,-c(1:3)] })
}

.guessSpeciesStyle <-
    function(seqnames)
{
    zz <- .supportedSeqnameMappings()
    got2 <- lapply(zz ,function(y) lapply(y, function(z)
        sum(z %in% seqnames)) )
    unlistgot2 <- unlist(got2, recursive=TRUE,use.names=TRUE)

    if (max(unlistgot2) == 0) {
       ans <- NA
    }else{
        ##vec is in format "Homo_sapiens.UCSC"
        vec <- names(which(unlistgot2==max(unlistgot2)))
        organism <- .normalize_organism(sub("(.*?)[.].*", "\\1", vec))
        style <- gsub("^[^.]+.","", vec)
        ans <- list(species=organism, style=style) 
    }
    ans
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### seqlevelsStyle() getter and setter
###

setGeneric("seqlevelsStyle", 
    function(x) standardGeneric("seqlevelsStyle"))

setGeneric("seqlevelsStyle<-", signature="x",
    function(x, value) standardGeneric("seqlevelsStyle<-")
)

setMethod("seqlevelsStyle", "character",
    function(x) 
{
    ## implement seqlevelsStyle,character-method
    if(length(x)==0)
        stop("No seqlevels present in this object.")
    
    seqnames <- unique(x)      
    ans <- .guessSpeciesStyle(seqnames)

    ## 3 cases -
    ## 1. if no style found - ans is na - stop with message 
    ## 2. if multiple styles returned then print message saying that it could be 
    ## any of these styles
    ## 3. if one style returned - hurray!

    if(length(ans)==1){
        if(is.na(ans)){
            txt <- "The style does not have a compatible entry for the
            species supported by Seqname. Please see
            genomeStyles() for supported species/style"
            stop(paste(strwrap(txt, exdent=2), collapse="\n"))
        }
    }
    unique(ans$style)
})

### The default methods work on any object 'x' with working "seqlevels"
### and "seqlevels<-" methods.

setMethod("seqlevelsStyle", "ANY", function(x) seqlevelsStyle(seqlevels(x)))

.replace_seqlevels_style <- function(x_seqlevels, value)
{
    renaming_maps <- mapSeqlevels(x_seqlevels, value, drop=FALSE)
    if (nrow(renaming_maps) == 0L) {
        msg <- c("found no sequence renaming map compatible ",
                 "with seqname style \"", value, "\" for this object")
        stop(msg)
    }
    ## Use 1st best renaming map.
    if (nrow(renaming_maps) != 1L) {
        msg <- c("found more than one best sequence renaming map ",
                 "compatible with seqname style \"", value, "\" for ",
                 "this object, using the first one")
        warning(msg)
        renaming_maps <- renaming_maps[1L, , drop=FALSE]
    }
    new_seqlevels <- as.vector(renaming_maps)
    na_idx <- which(is.na(new_seqlevels))
    new_seqlevels[na_idx] <- x_seqlevels[na_idx]
    new_seqlevels
}

setReplaceMethod("seqlevelsStyle", "character",
    function (x, value)
    {
        x_seqlevels <- unique(x)
        if (!(is.character(value) && length(value) >= 1L))
            stop("the supplied seqlevels style must be a single string")
        if (length(value) > 1L) {
            warning(wmsg("more than one seqlevels style supplied, ",
                         "using the 1st one only"))
            value <- value[[1L]]
        }
        new_seqlevels <- .replace_seqlevels_style(x_seqlevels, value)
        new_seqlevels[match(x, x_seqlevels)]
     }
)

setReplaceMethod("seqlevelsStyle", "ANY",
     function (x, value)
     {
         seqlevelsStyle(seqlevels(x)) <- value 
         x
     }
)

### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Related low-level utilities
###

genomeStyles <-
    function(species)
{
    if (missing(species))
        lapply(.getNamedFiles(), read.table, header=TRUE, sep="\t",
           stringsAsFactors=FALSE)
    else 
        .getDataInFile(species)
}

extractSeqlevels <- 
    function(species, style)
{
    if (missing(species) || missing(style))
        stop("'species' or 'style' missing")    
    
    if(.isSupportedSeqnamesStyle(species, style))
    {
        data <- .getDataInFile(species)
        result <- as.vector(data[,which( names(data) %in% style)])
        
    }else{
        stop("The style specified by '",style,
             "' does not have a compatible entry for the species ",species)}   
    result
}

extractSeqlevelsByGroup <- 
    function(species, style, group)
{
    if (missing(species) || missing(style) || missing(group))
        stop("'species', 'style', and / or 'group' missing")   
    
    logic <-sapply(species, function(x) .isSupportedSeqnamesStyle(x, style))
        
    if(all(logic))
    {
        data <- .getDataInFile(species)
        if (group!="all"){
            colInd <- which(names(data)%in% group)
            Ind <- which(data[,colInd]==1)
            result <- as.vector(data[Ind,which( names(data) %in% style)])
        }
        else{
            result <- as.vector(data[,which( names(data) %in% style)])
        }
    }else{
        stop("The style specified by '",style,
             "' does not have a compatible entry for the species ",species)}   
    result
}

mapSeqlevels <- 
    function(seqnames, style, best.only=TRUE, drop=TRUE)
{
    if (!is.character(seqnames))
        stop("'seqnames' must be a character vector")
    if (!isSingleString(style))
        stop("the supplied seqlevels style must be a single string")
    if (!.isTRUEorFALSE(best.only))
        stop("'best.only' must be TRUE or FALSE")
    if (!.isTRUEorFALSE(drop))
        stop("'drop' must be TRUE or FALSE")
    supported_styles <- .supportedSeqlevelsStyles()
    tmp <- unlist(supported_styles, use.names = FALSE)
    compatible_species <- rep.int(names(supported_styles),
                                  sapply(supported_styles,NROW))
    compatible_species <- compatible_species[tolower(tmp) ==
                                                 tolower(style)]
    if (length(compatible_species) == 0L)
        stop("supplied seqname style \"", style, "\" is not supported")
    seqname_mappings <- .supportedSeqnameMappings()
    ans <- lapply(compatible_species, function(species) {
        mapping <- seqname_mappings[[species]]
        names(mapping) <- tolower(names(mapping))
        to_seqnames <- as.character(mapping[[tolower(style)]])
        lapply(mapping, function(from_seqnames) 
            to_seqnames[match(seqnames, from_seqnames)])
    })
    ans_ncol <- length(seqnames)
    ans <- matrix(unlist(ans, use.names = FALSE), ncol = ans_ncol, byrow = TRUE)
    colnames(ans) <- seqnames
    score <- rowSums(!is.na(ans))
    idx <- score != 0L
    if (best.only)
        idx <- idx & (score == max(score))
    ans <- ans[idx, , drop = FALSE]
    ans <- as.matrix(unique(as.data.frame(ans, stringsAsFactors = FALSE)))
    if (nrow(ans) == 1L && drop)
        ans <- drop(ans)
    else rownames(ans) <- NULL
    ans        
}

seqlevelsInGroup <- 
    function(seqnames, group=c("all", "auto", "sex", "circular"),
             species, style)
{
    group <- match.arg(group)
    if (missing(species) && missing(style)) {
        ## guess the species and / or style for the object
        ans <- .guessSpeciesStyle(seqnames)
        species<- ans$species
        style <- unique(unlist(ans$style))
    }
    
    logic <-sapply(species, function(x) .isSupportedSeqnamesStyle(x, style))
    
    if (all(logic)) {
        seqvec <- sapply(unlist(species), function(x) 
            extractSeqlevelsByGroup( x, style, group))
        unique(unlist(seqvec))[na.omit(match(seqnames, unique(unlist(seqvec))))]
    } else {
        txt <- paste0( "The style specified by ", sQuote(style),
                       " does not have a compatible entry for the species ",
                       sQuote(species))
        stop(paste(strwrap(txt, exdent=2), collapse="\n"))
    }        
}

