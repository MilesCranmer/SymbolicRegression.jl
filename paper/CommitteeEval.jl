module Committee
using SymbolicRegression
using Statistics
using StatsBase
using Combinatorics
using Random
using InvertedIndices


function IBMD(x::AbstractArray{T},y::AbstractArray{T}) where T<:Real
    return log2.((abs.(x.-y)./abs.(max.(x,y))).+1)
end
function IBMD_disagreements_index(X::AbstractArray{T},comb::AbstractArray) where T<:Real
    #measure IBMD for every combination 
    cum=zeros(size(X)[1])
    for i in 1:size(comb)[1]
         cum+=IBMD(X[:,comb[i][1]],X[:,comb[i][2]])
    end
    #return index of maximum value in cum
    return cum, findmax(cum)[2]
end
function CommiteeEvaluation(sample_x::AbstractArray,dominating,options;disagreement_measure="std")
    trees = [member.tree for member in dominating]
    Results = [SymbolicRegression.eval_tree_array(node,sample_x,options) for node in trees]    #results => [Evaluations,Bool]# 
    arrays=[Results[i][1] for i in 1:size(Results)[1] ]     #extracting the evaluations from the results#
    y=reduce((x,y)-> hcat(x,y),[vectors for vectors in arrays])  #concantenating in one matrix
    if disagreement_measure == "std"  
        scores = std(y,dims=2)./ abs(mean(y,dims=2)) 
        scores= reshape(scores,(size(scores)[1]))
        maxindex= findmax(scores)[2] 
        return sample_x[:,maxindex],maxindex
    end
    if disagreement_measure == "IBMD"
        comb = collect(combinations(1:size(y)[2],2))
        scores,maxindex = IBMD_disagreements_index(y,comb)
        return sample_x[:,maxindex],maxindex
    end
    #calculating the scores for each datapoint# #disagreement measuremen#
end    


function AppendnewData(test_X,test_y,sample_x,sample_y,maxindex)
    test_X = hcat(test_X,sample_x[:,maxindex])
    test_y = vcat(test_y,sample_y[maxindex])
    #remove the sample from the sample set
    sample_x= sample_x[:,[1:maxindex-1; maxindex+1:end]]
    sample_y= sample_y[[1:maxindex-1; maxindex+1:end],:]
    return test_X,test_y,sample_x,sample_y
end

end
