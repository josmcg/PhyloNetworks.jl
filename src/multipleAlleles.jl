# functions to extend snaq to multiple alleles case
# Claudia November 2015

global repeatAlleleSuffix = "__2"


"""
`mapAllelesCFtable(mapping file, CF file; filename, columns)`

Create a new DataFrame containing the same concordance factors as in the input CF file,
but with modified taxon names. Each allele name in the input CF table is replaced by the
species name that the allele maps onto, based on the mapping file.

Optional arguments:

- file name to write/save resulting CF table. If not specified, then the output
  data frame is not saved to a file.
- column numbers for the taxon names. 1-4 by default.
"""
function mapAllelesCFtable(alleleDF::AbstractString, cfDF::AbstractString; filename=""::AbstractString, columns=Int[]::Vector{Int})
    d = readtable(alleleDF)
    d2 = readtable(cfDF)
    if(filename=="")
        mapAllelesCFtable!(d,d2,columns,false,filename)
    else
        mapAllelesCFtable!(d,d2,columns,true,filename)
    end
end

# function to read a table of allele-species matchs (dataframe with 2 columns)
# and a table of CF in the allele names, and replace all the allele names
# to the species names
# this will create a new CF table, will not rewrite on the original one
# filename is the name to give to the new table, if write=true
function mapAllelesCFtable!(alleleDF::DataFrame, cfDF::DataFrame, co::Vector{Int},write::Bool,filename::AbstractString)
    size(cfDF,2) >= 7 || error("CF DataFrame should have 7+ columns: 4taxa, 3CF, and possibly ngenes")
    if length(co)==0 co=[1,2,3,4]; end
    compareTaxaNames(alleleDF,cfDF,co)
    for j in 1:4
      for ia in 1:size(alleleDF,1) # for all alleles
        cfDF[co[j]] = map(x->replace(string(x),
                                     Regex("^$(string(alleleDF[ia,:allele]))\$"),
                                     alleleDF[ia,:species]),
                          cfDF[co[j]])
      end
    end
    if(write)
        filename != "" || error("want to write table of CF with alleles mapped but filename is empty")
        writetable(filename, cfDF)
    end
    return cfDF
end

# function to clean a df after changing allele names to species names
# inside mapAllelesCFtable
# by deleting rows that are not informative like sp1 sp1 sp1 sp2
function cleanAlleleDF!(newdf::DataFrame, cols::Vector{Int})
    global DEBUG
    withngenes = (length(cols)==8)
    delrows = Int[] # indices of rows to delete
    repSpecies = String[]
    if(isa(newdf[1,cols[1]],Integer)) #taxon names as integers: we need this to be able to add __2
        newdf[cols[1]] = map(x->string(x),newdf[cols[1]])
        newdf[cols[2]] = map(x->string(x),newdf[cols[2]])
        newdf[cols[3]] = map(x->string(x),newdf[cols[3]])
        newdf[cols[4]] = map(x->string(x),newdf[cols[4]])
    end
    for i in 1:size(newdf,1) #check all rows
        DEBUG && println("row number: $i")
        row = convert(Array,DataArray(newdf[i,cols[1:4]]))
        DEBUG && println("row $(row)")
        uniq = unique(row)
        DEBUG && println("unique $(uniq)")

        keep = false # default: used if 1 unique name, or 2 in some cases
        if(length(uniq) == 4)
            keep = true
        elseif(length(uniq) == 3) #sp1 sp1 sp2 sp3
            keep = true
            for u in uniq
                DEBUG && println("u $(u), typeof $(typeof(u))")
                ind = row .== u #taxon names matching u
                DEBUG && println("taxon names matching u $(ind)")
                if(sum(ind) == 2)
                    push!(repSpecies,string(u))
                    found = false
                    for k in 1:4
                        if(ind[k])
                            if(found)
                                DEBUG && println("found the second one in k $(k), will change newdf[i,cols[k]] $(newdf[i,cols[k]]), typeof $(typeof(newdf[i,cols[k]]))")
                                newdf[i,cols[k]] = string(u, repeatAlleleSuffix)
                                break
                            else
                                found = true
                            end
                        end
                    end
                    break
                end
            end
        elseif(length(uniq) == 2)
            # keep was initialized to false
            for u in uniq
                DEBUG && println("length uniq is 2, u $(u)")
                ind = row .== u
                if(sum(ind) == 1 || sum(ind) == 3)
                    DEBUG && println("ind $(ind) is 1 or 3, should not keep")
                    break
                elseif(sum(ind) == 2)
                    DEBUG && println("ind $(ind) is 2, should keep")
                    keep = true
                    found = false
                    push!(repSpecies,string(u))
                    for k in 1:4
                        if(ind[k])
                            if(found)
                                newdf[i,cols[k]] = string(u, repeatAlleleSuffix)
                                break
                            else
                                found = true
                            end
                        end
                    end
                end
            end
            DEBUG && println("after if, keep is $(keep)")
        end
        keep || push!(delrows, i)
        DEBUG && (@show keep)
    end
    DEBUG && (@show delrows)
    DEBUG && (@show repSpecies)
    nrows = size(newdf,1)
    nkeep = nrows - length(delrows)
    if(nkeep < nrows)
        print("""found $(length(delrows)) 4-taxon sets uninformative about between-species relationships, out of $(nrows).
              These 4-taxon sets will be deleted from the data frame. $nkeep informative 4-taxon sets will be used.
              """)
        nkeep > 0 || warn("All 4-taxon subsets are uninformative, so the dataframe will be left empty")
        deleterows!(newdf, delrows)
    end
    # @show size(newdf)
    return unique(repSpecies)
end


# function to merge rows that have repeated taxon names by using the weigthed average of CF
# (if info on number of genes is provided) or simple average
function mergeRows!(df::DataFrame, cols::Vector{Int})
    sorttaxa!(df, cols)
    n4tax  = size(df,1) # total number of 4-taxon sets
    delrows = Int[] # indices of rows to delete
    nrows  =  ones(Int ,n4tax) # total # of rows that row i combines. 0 if row i is to be deleted.
    for i in 1:n4tax # for each row / 4-taxon set
        if nrows[i]>0
            for j in (i+1):n4tax # rows with larger index
                nrows[j]>0 || continue # skip j if it matched a 4-taxon set earlier
                rowmatch = true
                for k in 1:4
                    rowmatch *= (df[j,cols[k]] == df[i,cols[k]])
                end
                rowmatch || continue   # skip j if doesn't match i^th taxon set
                nrows[j]=0
                push!(delrows, j)
                for k in 5:length(cols)
                    df[i,cols[k]] += df[j,cols[k]]
                end
                nrows[i] += 1
            end
        end
    end
    # @show head(df); @show delrows[1:10]; @show length(delrows); @show sum(nrows); println("number with nrows>0: $(sum(map(x -> x>0, nrows)))")
    for ir in delrows
        if nrows[ir]>0
            println("problem: ir=$ir, nrows=$(nrows[ir])")
            @show df[ir,:]
        end
    end
    length(delrows)>0 || return df
    sort!(delrows)
    for i in 1:size(df,2)
        deleteat!(df[i], delrows) # more efficient than deleterows!(df, delrows)
    end
    deleteat!(nrows, delrows)
    n4tax = size(df,1) # re-defined
    print("$n4tax unique 4-taxon sets were found. CF values of repeated 4-taxon sets will be averaged")
    println((length(cols)>7 ? " (ngenes too)." : "."))
    if length(cols)>7 && eltype(df[cols[8]])<: Integer # ngenes is present: integer. Need to convert to float
        df[cols[8]] = convert(Array{Float64},df[cols[8]])
    end
    for i in 1:n4tax
        nrows[i]>0 || error("Original $(delrows[i])) was retained (now row $i) but has nrows=0")
        for k in 5:length(cols)
            df[i,cols[k]] /= nrows[i]
        end
    end
    return df
end


# function to expand leaves in tree to two individuals
# based on cf table with alleles mapped to species names
function expandLeaves!(repSpecies::Union{Vector{String},Vector{Int}},tree::HybridNetwork)
    for sp in repSpecies
        for n in tree.node
            if(n.name == sp) #found leaf with sp name
                n.leaf || error("name $(sp) should correspond to a leaf, but it corresponds to an internal node")
                length(n.edge) == 1 || error("leaf $(sp) should have only one edge attached and it has $(length(n.edge))")
                if(n.edge[1].length == -1.0)
                    setLength!(n.edge[1],1.0)
                end
                removeLeaf!(tree,n)
                n.leaf = false
                n.edge[1].istIdentifiable = true
                n.name = ""
                max_node = maximum([e.number for e in tree.node]);
                max_edge = maximum([e.number for e in tree.edge]);
                e1 = Edge(max_edge+1,0.0)
                e2 = Edge(max_edge+2,0.0)
                n1 = Node(max_node+1,true,false,[e1])
                n2 = Node(max_node+2,true,false,[e2])
                setNode!(e1,n1)
                setNode!(e1,n)
                setNode!(e2,n2)
                setNode!(e2,n)
                setEdge!(n,e1)
                setEdge!(n,e2)
                pushNode!(tree,n1)
                pushNode!(tree,n2)
                pushEdge!(tree,e1)
                pushEdge!(tree,e2)
                n1.name = string(sp)
                n2.name = string(sp,repeatAlleleSuffix)
                push!(tree.names,n2.name)
                break
            end
        end
    end
end


# function to compare the taxon names in the allele-species matching table
# and the CF table
function compareTaxaNames(alleleDF::DataFrame, cfDF::DataFrame, co::Vector{Int})
    checkMapDF(alleleDF)
    println("Allele map: found $(length(alleleDF[1])) allele-species matches")
    CFtaxa = convert(Array, unique(stack(cfDF[co[1:4]], 1:4)[:value]))
    CFtaxa = map(x->string(x),CFtaxa) #treat as string
    alleleTaxa = map(x->string(x),alleleDF[:allele]) #treat as string
    sizeCF = length(CFtaxa)
    sizeAllele = length(alleleTaxa)
    if(sizeAllele > sizeCF)
        println("Allele map: more alleles in the mapping file: $(sizeAllele) than in the CF table: $(sizeCF). Extra allele names will be ignored")
        alleleTaxa = intersect(alleleTaxa,CFtaxa)
    elseif(sizeAllele < sizeCF)
        println("Allele map: fewer alleles in the mapping file: $(sizeAllele) than in the CF table: $(sizeCF). Some names in the CF table will remain unchanged")
    end
    unchanged = setdiff(CFtaxa,alleleTaxa)
    if(length(unchanged) == length(CFtaxa))
        warn("None of the taxon names in CF table match with allele names in the mapping file")
    end
    if(isempty(unchanged))
        println("All allele names in the CF table were found in the allele-species mapping file.")
    else
        warn("not all alleles were mapped")
        println("The following taxa in the CF table were not found in the allele-species mapping file:\n$(unchanged)")
    end
    return nothing
end

# function to check that the allele df has one column labelled alleles and one column labelled species
function checkMapDF(alleleDF::DataFrame)
    size(alleleDF,2) <= 2 || error("Allele-Species matching Dataframe should have at least 2 columns")
    size(alleleDF,2) >= 2 || warn("allele mapping file contains more than two columns: will ignore all columns not labelled allele or species")
    try
        alleleDF[:allele]
    catch
        error("In allele mapping file there is no column named allele")
    end
    try
        alleleDF[:species]
    catch
        error("In allele mapping file there is no column named species")
    end
end



## function to check if a new proposed topology satisfies the condition for
## multiple alleles: no gene flow to either allele, and both alleles as sister
## returns false if the network is not ok
function checkTop4multAllele(net::HybridNetwork)
    for n in net.leaf
        if(endswith(n.name, repeatAlleleSuffix))
            n.leaf || error("weird node $(n.number) not leaf in net.leaf list")
            length(n.edge) == 1 || error("weird leaf with $(length(n.edge)) edges")
            par = getOtherNode(n.edge[1],n)
            if(par.hybrid) ## there is gene flow into n
                return false
            end
            nameOther = replace(n.name,repeatAlleleSuffix,"")
            foundOther = false
            for i in 1:3
                other = getOtherNode(par.edge[i],par)
                if(other.leaf && other.name == nameOther)
                    foundOther = true
                end
            end
            foundOther || return false
        end
    end
    return true
end



## function to merge the two alleles into one
function mergeLeaves!(net::HybridNetwork)
    leaves = copy(net.leaf) # bc we change this list
    for n in leaves
        if(endswith(n.name, repeatAlleleSuffix))
            n.leaf || error("weird node $(n.number) not leaf in net.leaf list")
            length(n.edge) == 1 || error("weird leaf with $(length(n.edge)) edges")
            par = getOtherNode(n.edge[1],n)
            foundOther = false
            other = Node()
            nameOther = replace(n.name,repeatAlleleSuffix,"")
            for i in 1:3
                other = getOtherNode(par.edge[i],par)
                if(other.leaf && other.name == nameOther)
                    foundOther = true
                    break
                end
            end
            if(!foundOther)
                checkTop4multAllele(net) || error("current network does not comply with multiple allele condition")
                error("strange network that passes checkTop4multAllele, but cannot find the other allele for $(n.name)")
            end
            removeEdge!(par,n.edge[1])
            removeEdge!(par,other.edge[1])
            deleteNode!(net,n)
            deleteNode!(net,other)
            deleteEdge!(net,n.edge[1])
            deleteEdge!(net,other.edge[1])
            par.name = other.name
            par.leaf = true
            push!(net.leaf,par)
            net.numTaxa += 1
        end
    end
end
