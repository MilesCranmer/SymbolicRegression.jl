#functions

module QBC

include("PhConstraints.jl")
using CSV
using HTTP
using LinearAlgebra
using SymbolicRegression
using Random
using StatsBase
using InvertedIndices
using DataFrames
using Noise

Random.seed!(1234)


using CSV

struct MyDataset
    X::Matrix{Float32}
    y::Vector{Float32}
    num_features::Int          #columns
    num_data::Int 				#rows
end

function load_data(file_number::Int, delim::AbstractString=" ")
    file_name = "$(file_number)"
    file1 = CSV.File(file_name, header=false, delim=delim)

    num_columns = ncol(file1)
    num_features = num_columns - 1

    # Initialize an empty array to store feature columns
    X = Matrix{Float32}(undef, 0, num_features)

    # Loop through columns and concatenate them
    for i in 1:num_features
        col = Symbol("Column", i)
        X = hcat(X1, Float32.(file1[:, col]))
    end

    # Transpose the feature matrix
    X = Float32.(transpose(X))

    # Get the last column as the label vector
    label = file1[:, Symbol("Column", num_columns)]
    y = Float32.(label)

	return MyDataset(X1, y, num_features, num_data)

end


sample_pool= range(1,num_data,step=1)
index = sample(sample_pool,Number_of_sample,replace=false)

#just a sample of data

using Random

function samplenewdata(dataset::MyDataset, number_of_sample::Int)
    num_data = dataset.num_data
    X = dataset.X
    y = dataset.y

    # Sample indices without replacement
    sample_indices = sample(1:num_data, number_of_sample, replace=false)

    # Preallocate new_X and new_y matrices
    new_X = Matrix{Float32}(undef, dataset.num_features, number_of_sample)
    new_y = Vector{Float32}(undef, number_of_sample)

    # Fill new_X and new_y with sampled data
    for (counter, idx) in enumerate(sample_indices)
        new_X[:, counter] = X[:, idx]
        new_y[counter] = y[idx]
    end

    return new_X, new_y
end

#new_X1,new_y1= samplenewdata(dataset,Number_of_sample)
#new_X1noise,new_y1noise = samplenewdata(X1,y1noisy,Number_of_sample)
#new_X2,new_y2= samplenewdata(X2,y2,Number_of_sample)
#new_X3,new_y3= samplenewdata(X3,y3,Number_of_sample)

function append_one_data_point(new_X::Matrix{Float32}, new_y::Vector{Float32}, index::Vector{Int}, X::Matrix{Float32}, y::Vector{Float32}, sample_pool::Vector{Int})
    new_idx = sample(sample_pool, 1, replace=false)[1]

    if !(new_idx in index)
        new_X = hcat(new_X, X[:, new_idx])
        new_y = vcat(new_y, y[new_idx])
        push!(index, new_idx)
    end

    return new_X, new_y
end

inv(x)=1/x #anonymous function to be included in unary operators

options=Options(binary_operators =(+,-,*,/),
        unary_operators = (inv,square,cube,exp,sqrt,cos),
                  npopulations = 100,custom_loss_function=ConstrainsData.divergency,progress=true,nested_constraints=[cos=>[exp=>0],cos=>[cos=>0],exp=>[exp=>0]],stateReturn = true);

options2= Options(binary_operators = (+,-,*,/),
		  unary_operators = (inv,square,cube,exp,sqrt,cos),
		  npopulations = 100,
		  progress=true,nested_constraints =[cos=>[exp=>0],cos=>[cos=>0],exp=>[exp=>0]],stateReturn=true)

options3= Options(binary_operators = (+,-,*,/),
                  unary_operators = (inv,square,cube,exp,sqrt,cos),
                  npopulations = 100,
                  progress=false,nested_constraints =[cos=>[exp=>0],cos=>[cos=>0],exp=>[exp=>0]])

				  using SymbolicRegression

function constraint_loss()				  


end #end module 
