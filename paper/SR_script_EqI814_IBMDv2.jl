include("QBC.jl")
include("CommitteeEval.jl")
using SymbolicRegression
using Random
using InvertedIndices
using StatsBase
using LinearAlgebra

Random.seed!(1234)
#train_X,train_y = QBC.new_X1, QBC.new_y1
#sample_X, sample_y= QBC.X1, QBC.label11

#sample_pool= range(1,size(sample_X,2),step=1)


function append_one_data_point(train_X,train_y, sample_X,sample_y,index)
    flag = 1
    while flag == 1
        new_idx= sample(sample_pool,1,replace=false)
	if !(new_idx in index) 	
		global train_X = hcat(train_X,sample_X[:,new_idx[1]])
		global train_y = vcat(train_y,sample_y[new_idx[1]])	
		global index = vcat(index,new_idx[1])
        flag = 0
	end
	return Float32.(train_X),Float32.(train_y),index
    end
end

index= QBC.index


for i in 1:100
  
text_file = open("EquationI815noise0_01_divconstraintv2.txt","a");
  global train_X, train_y,sample_X,sample_y  = QBC.new_X1noise,QBC.new_y1noise,QBC.X1,QBC.y1noisy

  global j=1
      while j < 500
        global number_data = size(train_y);
        if j ==1
	   print("about to start EquationI815noise0_01_forrealdivconstraintv2.txt")
	end
	hof = EquationSearch(train_X,train_y;niterations=10,options=QBC.options);
	dataset = SymbolicRegression.Dataset(train_X,train_y)
	SymbolicRegression.LossFunctionsModule.update_baseline_loss!(dataset,QBC.options2)
	for population in hof[1][1]
	    for mem in population.members
		mem.score, mem.loss = SymbolicRegression.PopMemberModule.score_func(dataset,mem.tree,QBC.options2)
	    end
        end
	hof2 = EquationSearch(train_X,train_y;niterations=90,options=QBC.options2,saved_state=hof);
	global dominating = calculate_pareto_frontier(train_X,train_y,hof2,QBC.options2);
         #write(text_file,"Pareto_Frontier number$(j)","\n")
         #write(text_file,"Number of datapoints:$(number_data)","\n")
	losses = [member.loss for member in dominating]
	ratios = [losses[n+1]/losses[n] for n in 1:(size(losses)[1]-1)]
	threshold = [ratios .< 9e-3]  #jump in 5 orders of magnitude
	
	if sum(sum(threshold)) != 0

           for member in dominating
            
		if j >0
		global j=1001;
		loss= member.loss
		complexity = compute_complexity(member.tree,QBC.options2);
		string = string_tree(member.tree,QBC.options2);
		write(text_file,"Run#$(i)\t Datapoints$(number_data) $(complexity)\t$(loss)\t$(string)\n")
		end
           end                
        end
	j+=1 
	if j == 500;
	write(text_file,"run#$(i) completed","\n")
	end 

        new_point,new_index= Committee.CommiteeEvaluation(sample_X,dominating,QBC.options2;disagreement_measure="IBMD");
        global train_X,train_y,sample_X,sample_y=Committee.AppendnewData(train_X,train_y,sample_X,sample_y,new_index);
        println(j)
     end
close(text_file)
end

