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


file1 = CSV.File("I.8.14",header=false,delim=" ")
#file2 = CSV.File("I.10.7.txt",header=false,delim=" ")
#file3 = CSV.File("II.36.38.txt",header=false,delim=" ")

X11 = file1[:Column1]
X12 = file1[:Column2]
X13 = file1[:Column3]
X14 = file1[:Column4]
label1 = file1[:Column5]
label1noisy=add_gauss(file1[:Column5],0.01)

#X21 = file2[:Column1]
#X22 = file2[:Column2]
#X23 = file2[:Column3]
#label2= file2[:Column4]

#X31 = file3[:Column1]
#X32 = file3[:Column1]
#X33 = file3[:Column2]
#X34 = file3[:Column3]
#X35 = file3[:Column4]
#X36 = file3[:Column5]
#X37 = file3[:Column6]
#X38 = file3[:Column8]
#label3= file3[:Column9]

X1 = hcat(X11,X12,X13,X14)
X1 = Float32.(transpose(X1))
y1 = Float32.(1 ./label1)
y1noisy = Float32.(1 ./label1noisy )

#X2 = hcat(X21,X22,X23)
#X2 = Float32.(transpose(X2))
#y2 = Float32.(label2)
#X3 = hcat(X31,X32,X33,X34,X35,X36,X37,X38)
#X3 = Float32.(transpose(X3))
#y3 = Float32.(label3)
Number_of_sample = 15

num_features1,num_data1 =size(X1)
#num_features2,num_data2 =size(X2)
#num_features3,num_data3 =size(X3)
small_angle=1.0
non_desired_index=[]
#for i in 1:num_data
#   if X[6,i] != small_angle
#	append!(non_desired_index,i)
#   end
#end 
#X=X[1:end,Not(non_desired_index)]
#y=y[Not(non_desired_index)]
num_features,num_data = size(X1)

sample_pool= range(1,num_data,step=1)
index = sample(sample_pool,Number_of_sample,replace=false)

#just a sample of data

function samplenewdata(X,y,Number_of_sample)
	
	num_features,num_data =size(X)

	sample_pool= range(1,num_data,step=1)

	counter = 1
	new_X = ones(num_features,Number_of_sample)
	new_y = ones(Number_of_sample)
	for idx in index
		new_X[:,counter] = new_X[:,counter].*	X[:,idx]
		new_y[counter] = new_y[counter] .* y[idx]
		counter+=1
	end
	return new_X, new_y
end	
new_X1,new_y1= samplenewdata(X1,y1,Number_of_sample)
new_X1noise,new_y1noise = samplenewdata(X1,y1noisy,Number_of_sample)
#new_X2,new_y2= samplenewdata(X2,y2,Number_of_sample)
#new_X3,new_y3= samplenewdata(X3,y3,Number_of_sample)


function append_one_data_point(new_X,new_Y, index)
	new_idx= sample(sample_pool,1,replace=false)
	if !(new_idx in index) 	
		new_X = hcat(new_X,X[:,new_idx[1]])
		append!(new_y,y[new_idx[1]])		
		push!(index,new_idx[1])
	end
	return new_X,new_Y
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



end #end module 
