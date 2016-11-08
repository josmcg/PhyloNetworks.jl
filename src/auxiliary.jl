# auxiliary functions for all the other methods
# originally in functions.jl
# Claudia February 2015
#####################
function setCHECKNET(b::Bool)
    global CHECKNET
    CHECKNET = b
    CHECKNET && warn("PhyloNetworks.CHECKNET is true: will slow snaq! down.")
    b || println("PhyloNetworks.CHECKNET set to false")
end

# ----- aux general functions ---------------

#based in coupon's collector: E+sqrt(V)
function coupon(n::Number)
    return n*log(n) + n
end

function binom(n::Number,k::Number)
    n >= k || return 0
    n == 1 && return 1
    k == 0 && return 1
    binom(n-1,k-1) + binom(n-1,k) #recursive call
end

 function approxEq(a::Number,b::Number,absTol::Number,relTol::Number)
    if(a<eps() || b<eps())
        abs(a-b) < absTol
    else
        abs(a-b) < relTol*eps(abs(a)+abs(b))
    end
end

 approxEq(a::Number,b::Number) = approxEq(a,b,1e-5,100)

# isEqual functions: to test if 2 edges (or 2 nodes etc.) "look" alike.
#                    Useful after a deepcopy of a network.
# For nodes (or edges etc.) in the same network, use instead n1 == n2 or n1 != n2.
 function isEqual(n1::Node,n2::Node)
    return (n1.number == n2.number && approxEq(n1.gammaz,n2.gammaz) && n1.inCycle == n2.inCycle)
end

 function isEqual(n1::Edge,n2::Edge)
    return (n1.number == n2.number && approxEq(n1.length,n2.length))
end

 function isEqual(net1::HybridNetwork, net2::HybridNetwork)
    result = true
    result &= (net1.numTaxa == net2.numTaxa)
    result &= (net1.numNodes == net2.numNodes)
    result &= (net1.numEdges == net2.numEdges)
    ## result &= (net1.node == net2.node)
    ## result &= (net1.edge == net2.edge)
    result &= (net1.root == net2.root)
    result &= (net1.names == net2.names)
##    result &= (net1.hybrid == net2.hybrid)
    result &= (net1.numHybrids == net2.numHybrids)
##    result &= (net1.leaf == net2.leaf)
    result &= (net1.ht == net2.ht)
    result &= (net1.numht == net2.numht)
    result &= (net1.numBad == net2.numBad)
    result &= (net1.hasVeryBadTriangle == net2.hasVeryBadTriangle)
    result &= (net1.index == net2.index)
    result &= (net1.loglik == net2.loglik)
    return result
end


#------------- functions to allow for ------------#
#              missing values (lengths or gammas) #

# adds x+y but interprets -1.0 as missing: so -1.0 + x = -1.0 here.
function addBL(x::Number,y::Number)
    (x==-1.0 || y==-1.0) ? -1.0 : x+y
end

#------------- EDGE functions --------------------#

# warning: node needs to be defined as hybrid before adding to a
#          hybrid edge. First, an edge is defined as hybrid, and then
#          the nodes are added to it. If the node added is leaf, the
#          edge length is set unidentifiable (as it is external edge)
function setNode!(edge::Edge, node::Node)
    global DEBUG
    size(edge.node,1)  !=  2 || error("vector of nodes already has 2 values");
    push!(edge.node,node);
    if(size(edge.node,1) == 1)
        if(edge.hybrid)
            if(node.hybrid)
                edge.isChild1 = true;
            else
                edge.isChild1 = false;
	    end
        end
        if(node.leaf)
            edge.istIdentifiable = false;
        else
            edge.istIdentifiable = true
        end
    else
        if(node.leaf)
            !edge.node[1].leaf || error("edge $(edge.number) has two leaves")
            edge.istIdentifiable = false;
        else
            if(edge.hybrid)
	        if(node.hybrid)
                    if(DEBUG)
                        !edge.node[1].hybrid || println("hybrid edge $(edge.number) has two hybrid nodes");
                    end
                    edge.isChild1 = false;
	        else
	            edge.node[1].hybrid || error("hybrid edge $(edge.number) has no hybrid nodes");
	            edge.isChild1 = true;
	        end
            else #edge is tree
                if(!edge.node[1].leaf)
                    if(!node.hybrid && !edge.node[1].hybrid)
                        if(edge.fromBadDiamondI)
                            edge.istIdentifiable = false
                        else
                            edge.istIdentifiable = true
                        end
                    else
                        if(node.hybrid && (node.isBadDiamondI || node.isBadDiamondII || node.isBadTriangle))
                            edge.istIdentifiable = false
                        elseif(edge.node[1].hybrid && (edge.node[1].isBadDiamondI ||edge.node[1].isBadDiamondII || edge.node[1].isBadTriangle))
                            edge.istIdentifiable = false
                        else
                            edge.istIdentifiable = true
                        end
                    end
                else
                    edge.istIdentifiable = false
                end
            end
        end
    end
end

# warning: node needs to be defined as hybrid before adding to a hybrid edge.
#          First, an edge is defined as hybrid, and then the nodes are added to it.
#          If there is a leaf in node, the edge.istIdentifiable=false
function setNode!(edge::Edge,node::Array{Node,1})
    size(node,1) ==  2 || error("vector of nodes must have exactly 2 values")
    edge.node = node;
    if(edge.hybrid)
      if(node[1].hybrid)
          edge.isChild1 = true;
      else
          node[2].hybrid || error("hybrid edge without hybrid node");
          edge.isChild1 = false;
      end
    end
    if(edge.node[1].leaf || edge.node[2].leaf)
        edge.istIdentifiable = false;
    else
        edge.istIdentifiable = true;
    end
end


# -------------- NODE -------------------------#

function setEdge!(node::Node,edge::Edge)
   push!(node.edge,edge);
   all((e->!e.hybrid), node.edge) ? node.hasHybEdge = false : node.hasHybEdge = true;
end

function getOtherNode(edge::Edge,node::Node)
  isequal(edge.node[1],node) ? edge.node[2] : edge.node[1]
end
# -------------- NETWORK ----------------------- #
	 function getIndex(node::Node, net::Network)
				i = 1;
			while(i<= size(net.node,1) && !isEqual(node,net.node[i]))
					i = i+1;
			end
			i>size(net.node,1)?error("node $(node.number) not in network"):return i;
	end

	 function getIndex(edge::Edge, net::Network)
			i = 1;
			while(i<= size(net.edge,1) && !isEqual(edge,net.edge[i]))
					i = i+1;
			end
			i>size(net.edge,1)?error("edge $(edge.number) not in network"):return i;
	end

	 function getIndex(edge::Edge, edges::Vector{Edge})
			i = 1;
			while(i<= size(edges,1) && !isEqual(edge,edges[i]))
					i = i+1;
			end
			i>size(edges,1)?error("edge $(edge.number) not in array of edges"):return i;
	end

	 function getIndex(bool::Bool, array::Array{Bool,1})
			i = 1;
			while(i<= size(array,1) && !isequal(bool,array[i]))
					i = i+1;
			end
			i>size(array,1)?error("$(bool) not in array"):return i;
	end

	 function getIndex(bool::Bool, array::Array{Bool,1})
			i = 1;
			while(i<= size(array,1) && !isequal(bool,array[i]))
					i = i+1;
			end
			i>size(array,1)?error("$(bool) not in array"):return i;
	end

	 function getIndex(bool::Bool, array::Array{Any,1})
			i = 1;
			while(i<= size(array,1) && !isequal(bool,array[i]))
					i = i+1;
			end
			i>size(array,1)?error("$(bool) not in array"):return i;
	end

	# aux function to find the index of a string in a
	# string array
	 function getIndex(name::AbstractString, array::Array{ASCIIString,1})
			i = 1;
			while(i<= size(array,1) && !isequal(name,array[i]))
					i = i+1;
			end
			i>size(array,1)?error("$(name) not in array"):return i;
	end

	# aux function to find the index of a int in an int array.
	# But findfirst can do that as well, and probably more efficiently (returning 0 if not found)
	 function getIndex(name::Integer, array::Array{Int,1})
			i = 1;
			while(i<= size(array,1) && !isequal(name,array[i]))
					i = i+1;
			end
			i>size(array,1)?error("$(name) not in array"):return i;
	end


	# aux function to find the index of a node in a
	# node array
	 function getIndex(name::Node, array::Array{Node,1})
			i = 1;
			while(i<= size(array,1) && !isequal(name,array[i]))
					i = i+1;
			end
			i>size(array,1)?error("$(name.number) not in array"):return i;
	end


	 function getIndexNode(number::Integer,net::Network)
			ind = findfirst([number==n.number for n in net.node])
			if ind==0
					error("node number not in net.node")
			end
			return ind
	end

	 function getIndexEdge(number::Integer,net::Network)
			ind = findfirst([number==n.number for n in net.edge])
			if ind==0
					error("edge number not in net.edge")
			end
			return ind
	end

	# find the index of an edge in node.edge
	 function getIndexEdge(edge::Edge,node::Node)
			getIndex(true,[isequal(edge,e) for e in node.edge])
	end

	# find the index of an edge with given number in node.edge
	 function getIndexEdge(number::Integer,node::Node)
			getIndex(true,[isequal(edge,e) for e in node.edge])
	end

	# find the index of a node in edge.node
	 function getIndexNode(edge::Edge,node::Node)
			size(edge.node,1) == 2 || warn("this edge $(edge.number) has more or less than 2 nodes: $([n.number for n in edge.node])")
			if(isequal(node,edge.node[1]))
					return 1
			elseif(isequal(node,edge.node[2]))
					return 2
			else
					error("node not in edge.node")
			end
	end

# function to find hybrid index in net.hybrid
 function getIndexHybrid(node::Node, net::Network)
    node.hybrid || error("node $(node.number) is not hybrid so it cannot be in net.hybrid")
    i = 1;
    while(i<= size(net.hybrid,1) && !isEqual(node,net.hybrid[i]))
        i = i+1;
    end
    i>size(net.hybrid,1)?error("hybrid node not in network"):return i;
end

# function to find leaf index in qnet.leaf
 function getIndexLeaf(node::Node, net::Network)
    if(node.leaf)
        i = 1;
        while(i<= size(net.leaf,1) && !isEqual(node,net.leaf[i]))
            i = i+1;
        end
        i>size(net.leaf,1)?error("leaf node not in network"):return i;
    else
        error("node $(node.number) is not leaf so it cannot be in net.leaf")
    end
end


# function that given a hybrid node, it gives you the minor hybrid edge
function getHybridEdge(node::Node)
    node.hybrid || error("node $(node.number) is not hybrid node, cannot get hybrid edges")
    a = nothing;
    for(e in node.edge)
        (e.hybrid && !e.isMajor) ? a = e : nothing;
    end
    isa(a,Void) ? error("hybrid node $(node.number) does not have minor hybrid edge, edges: $([e.number for e in node.edge])") : return a
end


# function that given two nodes, it gives you the edge that connects them
# returns error if they are not connected by an edge
function getConnectingEdge(node1::Node,node2::Node)
    found = false;
    i = 1;
    while(i<= size(node1.edge,1) && !found)
        if(isequal(getOtherNode(node1.edge[i],node1),node2))
            found = true;
        end
        i = i+1;
    end
    if(found)
        return node1.edge[i-1]
    else
        error("nodes not connected")
    end
end

# function to check in an edge is in an array by comparing
# the edges numbers (uses isEqual)
# needed for updateHasEdge
function isEdgeNumIn(edge::Edge,array::Array{Edge,1})
    return all((e->!isEqual(edge,e)), array) ? false : true
end

# function to check in a leaf is in an array by comparing
# the numbers (uses isEqual)
# needed for updateHasEdge
 function isNodeNumIn(node::Node,array::Array{Node,1})
    return all((e->!isEqual(node,e)), array) ? false : true
end

# function to push a Node in net.node and
# update numNodes and numTaxa
function pushNode!(net::Network, n::Node)
    push!(net.node,n);
    net.numNodes += 1;
    if(n.leaf)
        net.numTaxa += 1
        push!(net.leaf,n);
    end
    if(n.hybrid)
        pushHybrid!(net,n)
    end
end

# function to push an Edge in net.edge and
# update numEdges
function pushEdge!(net::Network, e::Edge)
    push!(net.edge,e);
    net.numEdges += 1;
end


# function to push a hybrid Node in net.hybrid and
# update numHybrids
function pushHybrid!(net::Network, n::Node)
    if(n.hybrid)
        push!(net.hybrid,n);
        net.numHybrids += 1;
    else
        error("node $(n.number) is not hybrid, so cannot be pushed in net.hybrid")
    end
end

"""
`deleteNode!(net::HybridNetwork, n::Node)`


deletes a Node from a network, i.e. removes it from
net.node, and from net.hybrid or net.leaf as appropriate.
Updates attributes numNodes, numTaxa, numHybrids
(it does not update net.names though).

Warning: if the root is deleted, the new root is arbitrarily set to the
first node in the list. This is intentional to save time because this function
is used frequently in snaq!, which handles semi-directed (unrooted) networks.
"""
function deleteNode!(net::HybridNetwork, n::Node)
    index = 0
    try
        index = getIndex(n,net);
    catch
        error("Node $(n.number) not in network");
    end
    # println("deleting node $(n.number) from net, index $(index).")
    deleteat!(net.node,index);
    net.numNodes -= 1;
    if(net.root == index) # do not check containRoot to save time in snaq!
        net.root = 1      # arbitrary
    elseif(net.root > index)
        net.root -= 1
    end
    if(n.hybrid)
       removeHybrid!(net,n)
    end
    if(n.leaf)
        removeLeaf!(net,n)
    end
end

# function to delete a Node in net.node and
# update numNodes and numTaxa for QuartetNetwork
# if hybrid node, it deletes also from net.hybrid
# and updates numHybrids
# note that net.names is never updated to keep it
# accurate
# if n is leaf, we delete from qnet.leaf
function deleteNode!(net::QuartetNetwork, n::Node)
    index=0
    try
        index = getIndex(n,net);
    catch
        error("Node $(n.number) not in network");
    end
    #println("deleting node $(n.number) from net")
    deleteat!(net.node,index);
    net.numNodes -= 1;
    net.numTaxa -= n.leaf ? 1 : 0;
    if(n.hybrid)
       removeHybrid!(net,n)
    end
    if(n.leaf)
        index = getIndexLeaf(n,net)
        deleteat!(net.leaf,index)
    end
end

# function to delete an Edge in net.edge and
# update numEdges from a HybridNetwork
# added part boolean, default true to check the partition only when part=true
function deleteEdge!(net::HybridNetwork, e::Edge; part=true::Bool)
    if(part)
        if(e.inCycle == -1 && !e.hybrid && !isempty(net.partition) && !isTree(net))
            ind = whichPartition(net,e)
            indE = getIndex(e,net.partition[ind].edges)
            deleteat!(net.partition[ind].edges,indE)
        end
    end
    index = 0
    try
        index = getIndex(e,net);
    catch
        error("Edge $(e.number) not in network");
    end
    #println("delete edge $(e.number) from net")
    deleteat!(net.edge,index);
    net.numEdges -= 1;
end

# function to delete an Edge in net.edge and
# update numEdges from a QuartetNetwork
function deleteEdge!(net::QuartetNetwork, e::Edge)
    index=0
    try
        index = getIndex(e,net);
    catch
        error("Edge not in network");
    end
    #println("delete edge $(e.number) from net")
    deleteat!(net.edge,index);
    net.numEdges -= 1;
end


# function to delete a hybrid Node in net.hybrid and
# update numHybrid
# used when you do not want to delete the actual node
# only remove it from net.hybrid
function removeHybrid!(net::Network, n::Node)
    n.hybrid || error("cannot delete node $(n.number) from net.hybrid because it is not hybrid")
    index = 0
    try
        index = getIndexHybrid(n,net);
    catch
        error("Hybrid Node $(n.number) not in network");
    end
    deleteat!(net.hybrid,index);
    net.numHybrids -= 1;
end

# function to delete a leaf node in net.leaf
# and update numTaxa
function removeLeaf!(net::Network,n::Node)
    if(n.leaf)
        index = 0
        try
            index = getIndexLeaf(n,net)
        catch
            error("Leaf node $(n.number) not in network")
        end
        deleteat!(net.leaf,index)
        net.numTaxa -= 1
    else
        error("cannot delete node $(n.number) from net.leaf because it is not leaf")
    end
end

# function to delete an internal node with only 2 edges
function deleteIntNode!(net::Network, n::Node)
    size(n.edge,1) == 2 || error("node $(n.number) does not have only two edges")
#    isEqual(n,net.node[net.root]) && println("deleting the root $(n.number) because it has only two edges attached")
    index = n.edge[1].number < n.edge[2].number ? 1 : 2;
    edge1 = n.edge[index];
    edge2 = n.edge[index==1?2:1];
    if(!edge1.hybrid && !edge2.hybrid)
        node1 = getOtherNode(edge1,n);
        node2 = getOtherNode(edge2,n);
        removeEdge!(node2,edge2);
        removeNode!(n,edge1);
        setEdge!(node2,edge1);
        setNode!(edge1,node2);
        deleteNode!(net,n);
        deleteEdge!(net,edge2);
    else
        warn("the two edges $([edge1.number,edge2.number]) attached to node $(n.number) must be tree edges to delete node")
        if(edge1.hybrid)
            hybedge = edge1
            otheredge = edge2
        elseif(edge2.hybrid)
            hybedge = edge2
            otheredge = edge1
        end
        othernode = getOtherNode(otheredge,n)
        removeNode!(n,hybedge)
        removeEdge!(othernode,otheredge)
        setEdge!(othernode,hybedge)
        setNode!(hybedge,othernode)
        deleteNode!(net,n)
        deleteEdge!(net,otheredge)
    end
end


# search the hybrid node(s) in network: returns the hybrid node(s)
# in an array
# throws error if no hybrid in network
function searchHybridNode(net::Network)
    suma = sum([net.node[i].hybrid?1:0 for i = 1:size(net.node,1)]);
    if(suma == 0)
        error("network has no hybrid node");
    end
    k = getIndex(true,[net.node[i].hybrid for i = 1:size(net.node,1)]);
    if(suma>1)
        a = [net.node[k]];
        count = suma-1;
        index = k;
        vect = [net.node[i].hybrid for i = 1:size(net.node,1)];
        while(count>0 && count<size(net.node,1))
            index == 1 ? vect = [false;vect[2:size(net.node,1)]] : vect = [vect[1:(index-1)];false;vect[(index+1):size(net.node,1)]]
            index = getIndex(true,vect);
            push!(a,net.node[index]);
            count = count-1;
        end
        return a
    else
        return [net.node[k]]
    end
end

# search the hybrid edges in network: returns the hybrid edges
# hybrid edges come in pairs, both edges are returned
# throws error if no hybrid in network
# check: change to return only the minor edge?
function searchHybridEdge(net::Network)
    suma = sum([net.edge[i].hybrid?1:0 for i = 1:size(net.edge,1)]);
    if(suma == 0)
        error("network has no hybrid edge");
    end
    k = getIndex(true,[net.edge[i].hybrid for i = 1:size(net.edge,1)]);
    if(suma>1)
        a = [net.edge[k]];
        count = suma-1;
        index = k;
        vect = [net.edge[i].hybrid for i = 1:size(net.edge,1)];
        while(count>0 && count<size(net.edge,1))
            index == 1 ? vect = [false,vect[2:size(net.node,1)]] : vect = [vect[1:(index-1)],false,vect[(index+1):size(net.node,1)]]
            index = getIndex(true,vect);
            push!(a,net.edge[index]);
            count = count-1;
        end
        return a
    else
        return net.edge[k]
    end
end

# print for every edge, nodes, inCycle, containRoot, istIdentifiable
function printEdges(net::QuartetNetwork)
    println("Edge\tNode1\tNode2\tInCycle\tcontainRoot\tistIdentifiable\tLength\tisHybrid\tGamma")
    for e in net.edge
        println("$(e.number)\t$(e.node[1].number)\t$(e.node[2].number)\t$(e.inCycle)\t$(e.containRoot)\t\t$(e.istIdentifiable)\t\t$(round(e.length,2))\t$(e.hybrid)\t$(round(e.gamma,4))")
    end
end

"""
`printEdges(net::HybridNetwork)`

prints the information on the edges of net: edge number, node numbers of nodes attached to it, in which cycle it is contained (-1 if no cycle), can it contain root, is it an identifiable edge, length, is it hybrid, gamma value
"""

function printEdges(net::HybridNetwork)
    if(net.numBad > 0)
        println("net has $(net.numBad) bad diamond I. Some γ and edge lengths t are not identifiable, although their γ * (1-exp(-t)) are.")
    end
    miss = "NA"
    println("Edge\tNode1\tNode2\tInCycle\tcontainRoot\tistIdentitiable\tLength\tisHybrid\tGamma\tisMajor")
    for e in net.edge
        println("$(e.number)\t$(e.node[1].number)\t$(e.node[2].number)\t$(e.inCycle)\t$(e.containRoot)\t\t$(e.istIdentifiable)\t\t$(e.length==-1? miss :round(e.length,2))\t$(e.hybrid)\t\t$(e.gamma == 1.0 && e.hybrid ? miss : round(e.gamma,4))\t$(e.isMajor)")
    end
end

# print for every node, inCycle and edges
"""
`printNodes(net::HybridNetwork)`

prints information on the nodes of net: node number, in which cycle it is contained (-1 if no cycle), is it hybrid, does it has hybrid edges, edges number attached to it
"""
function printNodes(net::Network)
    println("Node\tIn Cycle\tisHybrid\thasHybEdge\tNode label\tisLeaf\tEdges numbers")
    for n in net.node
        print("$(n.number)\t$(n.inCycle)\t\t$(n.hybrid)\t\t$(n.hasHybEdge)\t\t$(n.name)\t\t$(n.leaf)")
        for e in n.edge
            print("\t$(e.number)")
        end
        print("\n")
    end
end

# find the edges for a given hybrid node
# in the order: hybrid major, hybrid minor, tree edge
# if node is tree node with hybrid edges, it returns
# hybrid edge, tree edge in cycle, tree edge not in cycle
# warning: assumes any tree node with hybrid edge has two tree edges
#          one in cycle, the other not in cycle
function hybridEdges(node::Node)
    size(node.edge,1) == 3 || error("node $(node.number) has $(size(node.edge,1)) edges instead of 3");
    if(node.hybrid)
        hybmajor = nothing;
        hybminor = nothing;
        tree = nothing;
        for(e in node.edge)
            (e.hybrid && e.isMajor) ? hybmajor = e : nothing
            (e.hybrid && !e.isMajor) ? hybminor = e : nothing
            !e.hybrid ? tree = e : nothing
        end
        return hybmajor, hybminor, tree
    elseif(node.hasHybEdge)
        hybrid = nothing;
        treecycle = nothing;
        tree = nothing;
        for(e in node.edge)
            (e.hybrid) ? hybrid = e : nothing
            (!e.hybrid && e.inCycle != -1) ? treecycle = e : nothing
            (!e.hybrid && e.inCycle == -1) ? tree = e : nothing
        end
        return hybrid, treecycle, tree
    else
        #warn("node $(node.number) is not hybrid $(node.hybrid) nor tree with hybrid edges (hasHybEdge) $(node.hasHybEdge), return the node.edge in order, unless a leaf is attached, then the edge attached to leaf is last");
        edge1 = nothing
        edge2 = nothing
        edge3 = nothing
        leaffound = false
        ind = 1
        for(i in 1:3)
            if(getOtherNode(node.edge[i],node).leaf)
                leaffound = true
                edge3 = node.edge[i]
                ind = i
                break
            end
        end
        if(leaffound)
            if(ind == 1)
                return node.edge[2], node.edge[3], edge3
            elseif(ind == 2)
                return node.edge[1], node.edge[3], edge3
            elseif(ind == 3)
                return node.edge[1], node.edge[2], edge3
            end
        else
            return node.edge[1], node.edge[2], node.edge[3]
        end
    end
end

# function to get the other two edges of a node
# besides the one specified
# it is called hybridEdges, but it not restricted to hybrid
function hybridEdges(node::Node, edge::Edge)
    size(node.edge,1) == 3 || error("node $(node.number) has $(size(node.edge,1)) edges instead of 3")
    edge1 = nothing
    edge2 = nothing
    for(e in node.edge)
        if(!isequal(e,edge))
            isa(edge1,Void) ? edge1 = e : edge2 = e
        end
    end
    return edge1,edge2
end


# function to remove an edge from a node
# warning: deletion is final, you can only
#          have edge back by pushing it again
# warning: if the edge removed is hybrid and node is tree,
#          node.hasHybEdge is set to false
#          assuming any tree node can only have one
#          one hybrid edge
function removeEdge!(node::Node,edge::Edge)
    index = 0
    try
        index = getIndexEdge(edge,node);
    catch e
        if isa(e, ErrorException)
            error("edge $(edge.number) not in node $(node.number)")
        end
    end
    deleteat!(node.edge,index);
    all((e->!e.hybrid), node.edge) ? node.hasHybEdge = false : node.hasHybEdge = true;
end

# function to remove a node from a edge
# warning: deletion is final, you can only
#          have node back by pushing it again
# warning: only removes node from edge, edge might still
#          be in node.edge
function removeNode!(node::Node,edge::Edge)
    try
        index = getIndexNode(edge,node);
    catch e
        if isa(e, ErrorException)
            error("node $(node.number) not in edge or strange edge with more than 2 nodes")
        end
    end
    index = getIndexNode(edge,node);
    deleteat!(edge.node,index);
end


# ----------------------------------------------------------------------------------------

# setLength
# warning: allows to change edge length for istIdentifiable=false
#          but issues a warning
# negative=true means it allows negative branch lengths (useful in qnet typeHyb=4)
function setLength!(edge::Edge, new_length::Number, negative::Bool)
    (negative || new_length >= 0) || error("length has to be nonnegative: $(new_length), cannot set to edge $(edge.number)")
    new_length >= -0.4054651081081644 || error("length can be negative, but not too negative (greater than -log(1.5)) or majorCF<0: new length is $(new_length)")
    #println("setting length $(new_length) to edge $(edge.number)")
    if(new_length > 10.0)
        new_length = 10.0;
    end
    edge.length = new_length;
    edge.y = exp(-new_length);
    edge.z = 1 - edge.y;
    #edge.istIdentifiable || warn("set edge length for edge $(edge.number) that is not identifiable")
    return nothing
end

"""
`setLength!(Edge,new length)`

set a new length for an object Edge. The new length needs to be positive.
For example, if you have a HybridNetwork object net, and do printEdges(net), you can see the list of Edges and their lengths. You can then change the length of the 3rd edge with setLength!(net.edge[3],1.2).
If `new length` is above 10, the value 10 will be used, as an upper limit
to coalescent units that can be reliably estimated.
"""
setLength!(edge::Edge, new_length::Number) = setLength!(edge, new_length, false)


"""
`setBranchLength!(Edge,new length)`

sets the length of an Edge object. The new length needs to be non-negative, or -1.0 to be interpreted as missing.
Example: if net is a HybridNetwork object, do printEdges(net) to see the list of all edges with their lengths. The length of the 3rd edge can be changed to 1.2 with setBranchLength!(net.edge[3],1.2). It can also be set to missing with setBranchLength!(net.edge[3],-1.0)
"""
function setBranchLength!(edge::Edge, new_length::Number)
    (new_length >= 0 || new_length == -1.0) || error("length $(new_length) has to be nonnegative or -1.0 (for missing).")
    edge.length = new_length;
    edge.y = exp(-new_length);
    edge.z = 1 - edge.y;
end


"""
`setGamma!(Edge,new gamma)`

set γ for an edge, which must be a hybrid edge. The new γ needs to be in (0,1).
The γ of the sister hybrid edge is changed accordingly, to 1-γ.
If `net` is a HybridNetwork object, `printEdges(net)` will show the list of edges and their γ's.
The γ of the third hybrid edge (say) can be changed to 0.2 with `setGamma!(net.edge[3],0.2)`.
This will automatically set γ of the sister hybrid edge to 0.8.
"""
# setGamma
# warning in the bad diamond/triangle cases because gamma is not identifiable
# updates isMajor according to gamma value
# changeOther = true, looks for the other hybrid edge and changes gamma too
# read = true, function called in readSubtree, needs to be the old one

setGamma!(edge::Edge, new_gamma::Float64) = setGamma!(edge, new_gamma, true, false)

setGamma!(edge::Edge, new_gamma::Float64, changeOther::Bool) = setGamma!(edge, new_gamma, changeOther, false)

function setGamma!(edge::Edge, new_gamma::Float64, changeOther::Bool, read::Bool)
    global DEBUG
    new_gamma >= 0 || error("gamma has to be positive: $(new_gamma)")
    new_gamma <= 1 || error("gamma has to be less than 1: $(new_gamma)")
    edge.hybrid || error("cannot change gamma in a tree edge");
    edge.isChild1 ? ind = 1 : ind = 2 ; # hybrid edge pointing at node 1 or 2
    node = edge.node[ind]
    node.hybrid || warn("hybrid edge $(edge.number) not pointing at hybrid node")
    if(DEBUG)
        !node.isBadDiamondI || warn("bad diamond situation: gamma not identifiable")
    end
    if(!read)
        edges = hybridEdges(node,edge)
        length(edges) == 2 || error("strange here: node $(node.number) should have 3 edges and it has $(length(edges)+1).")
        if(edges[1].hybrid && !edges[2].hybrid)
            ind = 1
        elseif(edges[2].hybrid && !edges[1].hybrid)
            ind = 2
        else
            error("strange hybrid node $(node.number) with only one hybrid edge or with three hybrid edges")
        end
        if(changeOther)
            if(!approxEq(new_gamma,0.5))
                edge.gamma = new_gamma;
                edge.isMajor = (new_gamma>0.5) ? true : false
                edges[ind].gamma = 1 - new_gamma;
                edges[ind].isMajor = (new_gamma<0.5) ? true : false
            else #new gamma is 0.5
                edge.gamma = new_gamma
                edge.isMajor = true
                edges[ind].gamma = 1 - new_gamma
                edges[ind].isMajor = false
            end
        else
            if(!approxEq(new_gamma,0.5))
                edge.gamma = new_gamma;
                edge.isMajor = (new_gamma>0.5) ? true : false
            else #new gamma is 0.5
                edge.gamma = new_gamma
                edge.isMajor = !edges[ind].isMajor
            end
        end
    else # comes from readSubtree
        edge.gamma = new_gamma;
        edge.isMajor = (new_gamma>=0.5) ? true : false
    end
    return nothing
end

"""
`setGammaBLfromGammaz!(node, network)`

Update the γ values of the two sister hybrid edges in a bad diamond I, given the `gammaz` values
of their parent nodes, and updates the branch lengths t1 and t2 of their parent edges
(those across from the hybrid nodes), in such a way that t1=t2 and that these branch lengths
and γ values are consistent with the `gammaz` values in the network.
"""
# similar to the beginning of undoGammaz!, but does not update anything else than γ and t's.
# unlike undoGammaz!, does nothing (no error) if non-hybrid or not at bad diamond I.
function setGammaBLfromGammaz!(node::Node, net::HybridNetwork)
    if !node.isBadDiamondI || !node.hybrid
        return nothing
    end
    edge_maj, edge_min, tree_edge2 = hybridEdges(node);
    other_maj = getOtherNode(edge_maj,node);
    other_min = getOtherNode(edge_min,node);
    edgebla,tree_edge_incycle1,tree_edge = hybridEdges(other_min);
    edgebla,tree_edge_incycle2,tree_edge = hybridEdges(other_maj);
    if(approxEq(other_maj.gammaz,0.0) && approxEq(other_min.gammaz,0.0))
        edge_maj.gamma = 1.0 # γ and t could be anything if both gammaz are 0
        edge_min.gamma = 0.0 # will set t's to 0 and minor γ to 0.
        newt = 0.0
    else
        ((approxEq(other_min.gammaz,0.0) || other_min.gammaz >= 0.0) &&
         (approxEq(other_maj.gammaz,0.0) || other_maj.gammaz >= 0.0)    ) ||
            error("bad diamond I in node $(node.number) but missing (or <0) gammaz")
        ztotal = other_maj.gammaz + other_min.gammaz
        edge_maj.gamma = other_maj.gammaz / ztotal
        edge_min.gamma = other_min.gammaz / ztotal
        newt = -log(1-ztotal)
    end
    setLength!(tree_edge_incycle1,newt)
    setLength!(tree_edge_incycle2,newt)
end


function numTreeEdges(net::HybridNetwork)
    2*net.numTaxa - 3 + net.numHybrids
end

function numIntTreeEdges(net::HybridNetwork)
    2*net.numTaxa - 3 + net.numHybrids - net.numTaxa
end


# function to get the partition where an edge is
# returns the index of the partition, or error if not found
# better to return the index than the partition itself, because we need the index
# to use splice and delete it from net.partition later on
# cycle: is the number to look for partition on that cycle only
function whichPartition(net::HybridNetwork,edge::Edge,cycle::Integer)
    global DEBUG
    !edge.hybrid || error("edge $(edge.number) is hybrid so it cannot be in any partition")
    edge.inCycle == -1 || error("edge $(edge.number) is in cycle $(edge.inCycle) so it cannot be in any partition")
    DEBUG && println("search partition for edge $(edge.number) in cycle $(cycle)")
    in(edge,net.edge) || error("edge $(edge.number) is not in net.edge")
    for(i in 1:length(net.partition))
        DEBUG && println("looking for edge $(edge.number) in partition $(i): $([e.number for e in net.partition[i].edges])")
        if(in(cycle,net.partition[i].cycle))
            DEBUG && println("looking for edge $(edge.number) in partition $(i), with cycle $(cycle): $([e.number for e in net.partition[i].edges])")
            if(in(edge,net.partition[i].edges))
                DEBUG && println("partition for edge $(edge.number) is $([e.number for e in net.partition[i].edges])")
                return i
            end
        end
    end
    DEBUG && printPartitions(net)
    error("edge $(edge.number) is not hybrid, nor part of any cycle, and it is not in any partition")
end

# function to get the partition where an edge is
# returns the index of the partition, or error if not found
# better to return the index than the partition itself, because we need the index
# to use splice and delete it from net.partition later on
function whichPartition(net::HybridNetwork,edge::Edge)
    global DEBUG
    !edge.hybrid || error("edge $(edge.number) is hybrid so it cannot be in any partition")
    edge.inCycle == -1 || error("edge $(edge.number) is in cycle $(edge.inCycle) so it cannot be in any partition")
    DEBUG && println("search partition for edge $(edge.number) without knowing its cycle")
    in(edge,net.edge) || error("edge $(edge.number) is not in net.edge")
    for(i in 1:length(net.partition))
        DEBUG && println("looking for edge $(edge.number) in partition $(i): $([e.number for e in net.partition[i].edges])")
        if(in(edge,net.partition[i].edges))
            DEBUG && println("partition for edge $(edge.number) is $([e.number for e in net.partition[i].edges])")
            return i
        end
    end
    DEBUG && printPartitions(net)
    error("edge $(edge.number) is not hybrid, nor part of any cycle, and it is not in any partition")
end

# function that will print the partition of net
function printPartitions(net::HybridNetwork)
    println("partition.cycle\t partition.edges")
    for(p in net.partition)
        println("$(p.cycle)\t\t $([e.number for e in p.edges])")
    end
end

# function to find if a given partition is in net.partition
function isPartitionInNet(net::HybridNetwork,desc::Vector{Edge},cycle::Vector{Int})
    for(p in net.partition)
        if(sort(cycle) == sort(p.cycle))
            if(sort([e.number for e in desc]) == sort([e.number for e in p.edges]))
                return true
            end
        end
    end
    return false
end

# function to check that everything matches in a network
# in particular, cycles, partitions and containRoot
# fixit: need to add check on identification of bad diamonds, triangles
# and correct computation of gammaz
# light=true: it will not collapse with nodes with 2 edges, will return a flag of true
# returns true if found egde with BL -1.0 (only when light=true, ow error)
# added checkPartition for undirectedOtherNetworks that do not need correct hybrid node number
function checkNet(net::HybridNetwork, light::Bool; checkPartition=true::Bool)
    global DEBUG
    DEBUG && println("checking net")
    net.numHybrids == length(net.hybrid) || error("discrepant number on net.numHybrids (net.numHybrids) and net.hybrid length $(length(net.hybrid))")
    net.numTaxa == length(net.leaf) || error("discrepant number on net.numTaxa (net.numTaxa) and net.leaf length $(length(net.leaf))")
    net.numNodes == length(net.node) || error("discrepant number on net.numNodes (net.numNodes) and net.node length $(length(net.node))")
    net.numEdges == length(net.edge) || error("discrepant number on net.numEdges (net.numEdges) and net.edge length $(length(net.edge))")
    if(isTree(net))
        all(x->x.containRoot,net.edge) || error("net is a tree, but not all edges can contain root")
        all(x->x.isMajor,net.edge) || error("net is a tree, but not all edges are major")
        all(x->!(x.hybrid),net.edge) || error("net is a tree, but not all edges are tree")
        all(x->!(x.hybrid),net.node) || error("net is a tree, but not all nodes are tree")
        all(x->!(x.hasHybEdge),net.node) || error("net is a tree, but not all nodes hasHybEdge=false")
        all(x->(x.gamma == 1.0 ? true : false),net.edge) || error("net is a tree, but not all edges have gamma 1.0")
    end
    for(h in net.hybrid)
        if(isBadTriangle(h))
            DEBUG && println("hybrid $(h.number) is very bad triangle")
            net.hasVeryBadTriangle || error("hybrid node $(h.number) is very bad triangle, but net.hasVeryBadTriangle is $(net.hasVeryBadTriangle)")
            h.isVeryBadTriangle || h.isExtBadTriangle || error("hybrid node $(h.number) is very bad triangle but it does not know it")
        end
        nocycle,edges,nodes = identifyInCycle(net,h)
        for(e in edges)
            e.inCycle == h.number || error("edge $(e.number) is in cycle of hybrid node $(h.number) but its inCycle attribute is $(e.inCycle)")
            if(e.length == -1.0)
                if(light)
                    return true
                else
                    error("found edge with BL -1.0")
                end
            end
            if(e.hybrid)
                !e.containRoot || error("hybrid edge $(e.number) should not contain root") # fixit: disagree
                o = getOtherNode(e,h)
                o.hasHybEdge || error("found node $(o.number) attached to hybrid edge but hasHybEdge=$(o.hasHybEdge)")
            end
        end
        for(n in nodes)
            n.inCycle == h.number || error("node $(n.number) is in cycle of hybrid node $(h.number) but its inCycle attribute is $(n.inCycle)")
            e1,e2,e3 = hybridEdges(n)
            i = 0
            for(e in [e1,e2,e3])
                if(isa(e,Void) && h.k != 2)
                    error("edge found that is Void, and hybrid node $(h.number) k is $(h.k). edge as nothing can only happen when k=2")
                elseif(!isa(e,Void))
                    if(e.inCycle == -1)
                        i += 1
                        desc = [e]
                        cycleNum = [h.number]
                        getDescendants!(getOtherNode(e,n),e,desc,cycleNum)
                        if(checkPartition && !isPartitionInNet(net,desc,cycleNum))
                            printPartitions(net)
                            error("partition with cycle $(cycleNum) and edges $([e.number for e in desc]) not found in net.partition")
                        end
                    end
                end
            end
            i == 1 || error("strange node $(n.number) incycle $(h.number) but with $(i) edges not in cycle, should be only one")
            edgesRoot = identifyContainRoot(net,h)
            for(edge in edgesRoot)
                if(edge.containRoot)
                    DEBUG && printEverything(net)
                    error("edge $(edge.number) should not contain root")
                end
            end
        end
    end
    for(n in net.node)
        if(n.leaf)
            length(n.edge) == 1 || error("leaf $(n.number) with $(length(n.edge)) edges instead of 1")
        else
            if(light)
                if(length(n.edge) != 3)
                    DEBUG && warn("node $(n.number) with $(length(n.edge)) edges instead of 3")
                    return true
                end
            else
                length(n.edge) == 3 || error("node $(n.number) with $(length(n.edge)) edges instead of 3")
            end
        end
    end
    for(e in net.edge)
        if(e.length == -1.0)
            if(light)
                return true
            else
                error("edge found with BL -1.0")
            end
        end
    end
    DEBUG && println("no errors in checking net")
    return false
end

checkNet(net::HybridNetwork) = checkNet(net, false)

# function to print everything for a given net
# this is used a lot inside snaq when DEBUG is true, so need to use level1 attributes
# and not change the network: with writeTopologyLevel1
function printEverything(net::HybridNetwork)
    printEdges(net)
    printNodes(net)
    printPartitions(net)
    println("$(writeTopologyLevel1(net))")
end

# function to check if a node is very or ext bad triangle
function isBadTriangle(node::Node)
    node.hybrid || error("cannot check if node $(node.number) is very bad triangle because it is not hybrid")
    if(node.k == 3)
        edgemaj, edgemin, treeedge = hybridEdges(node)
        othermaj = getOtherNode(edgemaj,node)
        othermin = getOtherNode(edgemin,node)
        treenode = getOtherNode(treeedge,node)
        edges1 = hybridEdges(othermaj)
        o1 = getOtherNode(edges1[3],othermaj)
        edges2 = hybridEdges(othermin)
        o2 = getOtherNode(edges2[3],othermin)
        leaves = sum([n.leaf ? 1 : 0 for n in [treenode,o1,o2]])
        if(leaves == 1 || leaves == 2)
            return true
        else
            return false
        end
    else
        return false
    end
end


# function to check if a partition is already in net.partition
# used in updatePartition
function isPartitionInNet(net::HybridNetwork,partition::Partition)
    if(isempty(net.partition))
        return false
    end
    for(p in net.partition)
        cycle = isempty(setdiff(p.cycle,partition.cycle)) && isempty(setdiff(partition.cycle,p.cycle))
        edges = isempty(setdiff([n.number for n in p.edges],[n.number for n in partition.edges])) && isempty(setdiff([n.number for n in partition.edges],[n.number for n in p.edges]))
        if(cycle && edges)
            return true
        end
    end
    return false
end


# function to switch a hybrid node in a network to another node in the cycle
function switchHybridNode!(net::HybridNetwork, hybrid::Node, newHybrid::Node)
    hybrid.hybrid || error("node $(hybrid.number) has to be hybrid to switch to a different hybrid")
    newHybrid.inCycle == hybrid.number || error("new hybrid needs to be in the cycle of old hybrid: $(hybrid.number)")
    !newHybrid.hybrid || error("strange hybrid node $(newHybrid.number) in cycle of another hybrid $(hybrid.number)")
    newHybrid.hybrid = true
    newHybrid.hasHybEdge = true
    newHybrid.name = hybrid.name
    pushHybrid!(net,newHybrid)
    makeNodeTree!(net,hybrid)
end

"""
`assignhybridnames!(net)`

Assign names to hybrid nodes in the network `net`. Hybrid nodes with an empty `name` field ("")
are modified with a name that does not conflict with other hybrid names in the network.
The preferred name is "#H3" if the node number is 3 or -3, but an index other than 3 would be
used if "#H3" were the name of another hybrid node already.

If two hybrid nodes have non-empty and equal names, the name of one of them is changed and
re-assigned as described above (with a warning).
"""
function assignhybridnames!(net::HybridNetwork)
    hybnum = Int[]  # indices 'i' in hybrid names: #Hi
    # first: go through *all* existing non-empty names
    for ih in 1:length(net.hybrid)
        lab = net.hybrid[ih].name
        lab != "" || continue # do nothing if label is missing
        jh = findfirst([net.hybrid[j].name for j in 1:ih-1], lab)
        if jh > 0 # set repeated names to ""
            warn("hybrid nodes $(net.hybrid[ih].number) and $(net.hybrid[jh].number) have the same label: $lab. Will change the name of the former.")
            net.hybrid[ih].name = ""
        else
            m = match(r"^#H(\d+)$", lab)
            if m != nothing # make full list of existing indices "i" in #Hi
                push!(hybnum, parse(Int, m[1]))
            end
        end
    end
    # second: assign empty names to #Hi
    hnext = 1
    for ih in 1:length(net.hybrid)
        net.hybrid[ih].name == "" || continue # do nothing if non-empty label
        hnum = abs(net.hybrid[ih].number)
        while in(hnum, hybnum)
            hnum = hnext  # not efficient, but rare
            hnext += 1    # and okay on small networks
        end
        push!(hybnum, hnum)
        net.hybrid[ih].name = "#H$hnum"
    end
end

"""
    sorttaxa!(DataFrame, columns)

Reorder the 4 taxa and reorders the observed concordance factors accordingly, on each row of
the data frame. If `columns` is committed, taxon names are assumed to be in columns 1-4 and
CFs are assumed to be in columns 5-6 with quartets in this order: 12_34, 13_24, 14_23.
Does **not** reorder credibility interval values, if present.

    sorttaxa!(DataCF)
    sorttaxa!(Quartet, permutation_tax, permutation_cf)

Reorder the 4 taxa in each element of the DataCF `quartet`. For a given Quartet,
reorder the 4 taxa in its fields `taxon` and `qnet.quartetTaxon` (if non-empty)
and reorder the 3 concordance values accordingly, in `obsCF` and `qnet.expCF`.

`permutation_tax` and `permutation_cf` should be vectors of short integers (Int8) of length 4 and 3
respectively, whose memory allocation gets reused. Their length is *not checked*.
"""
# qnet.names unchanged: order of taxon names here relates to the order of nodes in the network

function sorttaxa!(dat::DataCF)
    ptax = Array{Int8}(4) # to hold the sort permutations
    pCF  = Array{Int8}(3)
    for q in dat.quartet
        sorttaxa!(q, ptax, pCF)
    end
end

function sorttaxa!(df::DataFrame, co=Int[]::Vector{Int})
    if length(co)==0
        co = collect(1:7)
    end
    length(co) > 6 || error("column vector must be of length 7 or more")
    ptax = Array{Int8}(4)
    pCF  = Array{Int8}(3)
    taxnam = Array{eltype(df[co[1]])}(4)
    for i in 1:size(df,1)
        for j=1:4 taxnam[j] = df[i,co[j]]; end
        sortperm!(ptax, taxnam)
        sorttaxaCFperm!(pCF, ptax) # update permutation pCF according to taxon permutation
        df[i,co[1]], df[i,co[2]], df[i,co[3]], df[i,co[4]] = taxnam[ptax[1]], taxnam[ptax[2]], taxnam[ptax[3]], taxnam[ptax[4]]
        df[i,co[5]], df[i,co[6]], df[i,co[7]] = df[i,co[pCF[1]+4]], df[i,co[pCF[2]+4]], df[i,co[pCF[3]+4]]
    end
    return df
end

function sorttaxa!(qua::Quartet, ptax::Vector{Int8}, pCF::Vector{Int8})
    qt = qua.taxon
    if length(qt)==4
        sortperm!(ptax, qt)
        sorttaxaCFperm!(pCF, ptax) # update permutation pCF accordingly
        qt[1], qt[2], qt[3], qt[4] = qt[ptax[1]], qt[ptax[2]], qt[ptax[3]], qt[ptax[4]]
        qua.obsCF[1], qua.obsCF[2], qua.obsCF[3] = qua.obsCF[pCF[1]], qua.obsCF[pCF[2]], qua.obsCF[pCF[3]]
        # do *NOT* modify qua.qnet.quartetTaxon: it points to the same array as qua.taxon
        eCF = qua.qnet.expCF
        if length(eCF)==3
            eCF[1], eCF[2], eCF[3] = eCF[pCF[1]], eCF[pCF[2]], eCF[pCF[3]]
        end
    elseif length(qt)!=0
        error("Quartet with $(length(qt)) taxa")
    end
    return qua
end

# find permutation pCF of the 3 CF values: 12_34, 13_24, 14_23. 3!=6 possible permutations
# ptax = one of 4!=24 possible permutations on the 4 taxon names
# kernel: pCF = identity if ptax = 1234, 2143, 3412 or 4321
# very long code, but to minimize equality checks at run time
function sorttaxaCFperm!(pcf::Vector{Int8}, ptax::Vector{Int8})
    if ptax[1]==1
        if     ptax[2]==2
            pcf[1]=1
            if  ptax[3]==3 # ptax = 1,2,3,4
                pcf[2]=2; pcf[3]=3
            else           # ptax = 1,2,4,3
                pcf[2]=3; pcf[3]=2
            end
        elseif ptax[2]==3
            pcf[1]=2
            if  ptax[3]==2 # ptax = 1,3,2,4
                pcf[2]=1; pcf[3]=3
            else           # ptax = 1,3,4,2
                pcf[2]=3; pcf[3]=1
            end
        else # ptax[2]==4
            pcf[1]=3
            if  ptax[3]==2 # ptax = 1,4,2,3
                pcf[2]=1; pcf[3]=2
            else           # ptax = 1,4,3,2
                pcf[2]=2; pcf[3]=1
            end
        end
    elseif ptax[1]==2
        if     ptax[2]==1
            pcf[1]=1
            if  ptax[3]==4 # ptax = 2,1,4,3
                pcf[2]=2; pcf[3]=3
            else           # ptax = 2,1,3,4
                pcf[2]=3; pcf[3]=2
            end
        elseif ptax[2]==4
            pcf[1]=2
            if  ptax[3]==1 # ptax = 2,4,1,3
                pcf[2]=1; pcf[3]=3
            else           # ptax = 2,4,3,1
                pcf[2]=3; pcf[3]=1
            end
        else # ptax[2]==3
            pcf[1]=3
            if  ptax[3]==1 # ptax = 2,3,1,4
                pcf[2]=1; pcf[3]=2
            else           # ptax = 2,3,4,1
                pcf[2]=2; pcf[3]=1
            end
        end
    elseif ptax[1]==3
        if     ptax[2]==4
            pcf[1]=1
            if  ptax[3]==1 # ptax = 3,4,1,2
                pcf[2]=2; pcf[3]=3
            else           # ptax = 3,4,2,1
                pcf[2]=3; pcf[3]=2
            end
        elseif ptax[2]==1
            pcf[1]=2
            if  ptax[3]==4 # ptax = 3,1,4,2
                pcf[2]=1; pcf[3]=3
            else           # ptax = 3,1,2,4
                pcf[2]=3; pcf[3]=1
            end
        else # ptax[2]==2
            pcf[1]=3
            if  ptax[3]==4 # ptax = 3,2,4,1
                pcf[2]=1; pcf[3]=2
            else           # ptax = 3,2,1,4
                pcf[2]=2; pcf[3]=1
            end
        end
    else # ptax[1]==4
        if     ptax[2]==3
            pcf[1]=1
            if  ptax[3]==2 # ptax = 4,3,2,1
                pcf[2]=2; pcf[3]=3
            else           # ptax = 4,3,1,2
                pcf[2]=3; pcf[3]=2
            end
        elseif ptax[2]==2
            pcf[1]=2
            if  ptax[3]==3 # ptax = 4,2,3,1
                pcf[2]=1; pcf[3]=3
            else           # ptax = 4,2,1,3
                pcf[2]=3; pcf[3]=1
            end
        else # ptax[2]==1
            pcf[1]=3
            if  ptax[3]==3 # ptax = 4,1,3,2
                pcf[2]=1; pcf[3]=2
            else           # ptax = 4,1,2,3
                pcf[2]=2; pcf[3]=1
            end
        end
    end
end
