# see readme file in tests/ for description of tests
# Claudia July 2015
# modified to using PhyloNetworks always, all test files have commented out
# the include(...) or the using PhyloNetworks part
# Claudia May 2016

using Base.Test

if !isdefined(:localtests) localtests = false; end

localtests = true

if(!localtests)
    using PhyloNetworks
    using DataFrames
    PhyloNetworks.setCHECKNET(true)

    ## readTopology
    getIndexEdge = PhyloNetworks.getIndexEdge
    getIndexNode = PhyloNetworks.getIndexNode
    Edge = PhyloNetworks.Edge
    Node = PhyloNetworks.Node
    setNode! = PhyloNetworks.setNode!
    ## calculateExpCF
    approxEq = PhyloNetworks.approxEq
    Quartet = PhyloNetworks.Quartet
    extractQuartet! = PhyloNetworks.extractQuartet!
    identifyQuartet! = PhyloNetworks.identifyQuartet!
    eliminateHybridization! = PhyloNetworks.eliminateHybridization!
    updateSplit! = PhyloNetworks.updateSplit!
    updateFormula! = PhyloNetworks.updateFormula!
    calculateExpCF! = PhyloNetworks.calculateExpCF!
    parameters! = PhyloNetworks.parameters!
    searchHybridNode = PhyloNetworks.searchHybridNode
    updateInCycle! = PhyloNetworks.updateInCycle!
    updateContainRoot! = PhyloNetworks.updateContainRoot!
    updateGammaz! = PhyloNetworks.updateGammaz!
    ## correctLik
    calculateExpCFAll! = PhyloNetworks.calculateExpCFAll!
    logPseudoLik = PhyloNetworks.logPseudoLik
    optTopRun1! = PhyloNetworks.optTopRun1!
    ## partition
    addHybridizationUpdate! = PhyloNetworks.addHybridizationUpdate!
    deleteHybridizationUpdate! = PhyloNetworks.deleteHybridizationUpdate!
    ## partition2
    writeTopologyLevel1 = PhyloNetworks.writeTopologyLevel1
    printPartitions = PhyloNetworks.printPartitions
    cleanBL! = PhyloNetworks.cleanBL!
    cleanAfterRead! = PhyloNetworks.cleanAfterRead!
    identifyInCycle = PhyloNetworks.identifyInCycle
    updatePartition! = PhyloNetworks.updatePartition!
    ## deleteHybridizationUpdate
    checkNet = PhyloNetworks.checkNet
    ## add2hyb
    hybridEdges = PhyloNetworks.hybridEdges
    ## optBLparts
    update! = PhyloNetworks.update!
    ## orderings_plot
    RootMismatch = PhyloNetworks.RootMismatch
    fuseedgesat! = PhyloNetworks.fuseedgesat!
    ## compareNetworks
    deleteHybridEdge! = PhyloNetworks.deleteHybridEdge!
    displayedNetworks! = PhyloNetworks.displayedNetworks!
    ## perfect data
    writeExpCF = PhyloNetworks.writeExpCF
    optBL! = PhyloNetworks.optBL!
else
    const CHECKNET = true #for debugging only
	include("../src/types.jl")
  include("../src/functions.jl")
end
