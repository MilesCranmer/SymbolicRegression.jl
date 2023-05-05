#functions
module ConstrainsData
using SymbolicRegression 
using Random
using Distributions

export select_constraint, symmetry_loss, divergency

function select_constraint(typeofconstraint::AbstractString;lambda = 100, vars)
   if typeofconstraint == "symmetry"
         function symmetry_loss(tree::SymbolicRegression.Node, dataset::SymbolicRegression.Dataset{T},options,vars=vars,n=lambda) where {T}
         _,d= size(dataset.X)
         symmetrydata = copy(dataset.X)
         number_of_symmetries = size(vars)[1]
         for i in 1:number_of_symmetries
            if size(vars[i][1]) == 2
            symmetrydata[vars[i][1],:],symmetrydata[vars[i][2],:]=symmetrydata[vars[i][2],:],symmetrydata[vars[i][1],:]
            end
            if size(vars[i])[1] == 3
            symmetrydata[vars[i][1],:],symmetrydata[vars[i][2],:],symmetrydata[vars[i][3],:]=symmetrydata[vars[i][3],:],symmetrydata[vars[i][1],:],symmetrydata[vars[i][2],:]
            end
         end
         prediction1, complete1 = SymbolicRegression.eval_tree_array(tree,dataset.X,options)
         (!complete1) && return(T(10000000))
         prediction2, complete2 = SymbolicRegression.eval_tree_array(tree,symmetrydata,options)
         (!complete2) && return(T(10000000))
         
         predictive_loss_L2Dis = sum(abs.(dataset.y .- prediction1))
         symmetry_loss = sum(n*abs.(prediction1-prediction2))/d
        
         return predictive_loss_L2Dis + symmetry_loss
      end
      return symmetry_loss
   
   elseif typeofconstraint == "divergency1"
         function divergency(tree::SymbolicRegression.Node , dataset::SymbolicRegression.Dataset{T}, options;vars,n=lambda) where {T}
            _,d = size(dataset.X)
            divergency_data = copy(dataset.X)
            for i in collect(1:d)
               divergency_data[vars,i] = 0
            end
            prediction, complete = SymbolicRegression.eval_tree_array(tree, dataset.X, options)
            (!complete) && return T(10000000)
            prediction_div, _ = SymbolicRegression.eval_tree_array(tree, divergency_data, options)
           
            predictive_loss_L2Dis = sum(abs.(dataset.y .- prediction).^2)
            divergency_loss = n*sum(isfinite.(prediction_div))/d      #if Inf then no addition to divergency_loss
            return predictive_loss_L2Dis + divergency_loss
            end

      return divergency

      elseif typeofconstraint == "divergencya-b"
      function divergency(tree::SymbolicRegression.Node , dataset::SymbolicRegression.Dataset{T}, options;vars,n=lambda) where {T}
      _,d = size(dataset.X)
      divergency_data = copy(dataset.X)
      number_of_div = size(vars)[1]
      primes = [7,11,13,17,19,23,29,31,37,41,43,47,53,59,61]
      for i in 1:number_of_div
         for j in collect(1:d)
            divergency_data[vars[i][1],j] = primes[i]
            divergency_data[vars[i][2],j] = primes[i]
         end
      end
      prediction, complete = SymbolicRegression.eval_tree_array(tree, dataset.X, options)
      (!complete) && return T(10000000)
      prediction_div, _ = SymbolicRegression.eval_tree_array(tree, divergency_data, options)
     
      predictive_loss_L2Dis = sum(abs.(dataset.y .- prediction).^2)
      divergency_loss = n*sum(isfinite.(prediction_div))/d      #if Inf then no addition to divergency_loss
      return predictive_loss_L2Dis + divergency_loss
      end
      return divergency
   end
end
  



function symmetry_loss(tree::SymbolicRegression.Node, dataset::SymbolicRegression.Dataset{T},options,vars=[[1,2],[3,4]],n=100) where {T}
   _,d= size(dataset.X)
   symmetrydata = copy(dataset.X)
   number_of_symmetries = size(vars)[1]
   for i in 1:number_of_symmetries
      if number_of_symmetries ==2
      symmetrydata[vars[i][1],:],symmetrydata[vars[i][2],:]=symmetrydata[vars[i][2],:],symmetrydata[vars[i][1],:]
      end
      if number_of_symmetries ==3
      symmetrydata[vars[i][1],:],symmetrydata[vars[i][2],:],symmetrydata[vars[i][3],:]=symmetrydata[vars[i][3],:],symmetrydata[vars[i][1],:],symmetrydata[vars[i][2],:]
      end
   end
   prediction1, complete1 = SymbolicRegression.eval_tree_array(tree,dataset.X,options)
   (!complete1) && return(T(10000000))
   prediction2, complete2 = SymbolicRegression.eval_tree_array(tree,symmetrydata,options)
   (!complete2) && return(T(10000000))
   
   predictive_loss_L2Dis = sum(abs.(dataset.y .- prediction1))
   symmetry_loss = sum(n*abs.(prediction1-prediction2))/d
  
   return predictive_loss_L2Dis + symmetry_loss
end

function divergency_symmetry_loss(tree::SymbolicRegression.Node, dataset::SymbolicRegression.Dataset{T},options,var1=2,var2=3,n=5) where {T}
   for i in collect(1:d)
      divergency_data[dir,i] = 7
      divergency_data[dir+1,i] = 7
   end
   _,d= size(dataset.X)
   symmetrydata = copy(dataset.X)
   symmetrydata[var1,:],symmetrydata[var2,:]=symmetrydata[var2,:],symmetrydata[var1,:]
   prediction1, complete1 = SymbolicRegression.eval_tree_array(tree,dataset.X,options)
   (!complete1) && return(T(10000000))
   prediction2, complete2 = SymbolicRegression.eval_tree_array(tree,symmetrydata,options)
   (!complete2) && return(T(10000000))
   
   prediction_div, _ = SymbolicRegression.eval_tree_array(tree, divergency_data, options)

   predictive_loss_L2Dis = sum(abs.(dataset.y .- prediction1))
   symmetry_loss = n*sum(abs.(prediction1-prediction2))/d
   divergency_loss = n*sum(isfinite.(prediction_div))/d      #if Inf then no addition to divergency_loss

   return predictive_loss_L2Dis+ symmetry_loss+ divergency_loss
end 
function Asymptote_loss(tree::SymbolicRegression.Node , dataset::SymbolicRegression.Dataset{T}, options;dir=3,n=500) where {T}
    _,d = size(dataset.X)
    tree_asymptote = fill(Float32(0.1),d)
    asympdata = copy(dataset.X)
    for i in collect(1:d)
       asympdata[dir,i]= 10^(i*2)
    end
    if n!=0
       prediction, derivative, complete = SymbolicRegression.eval_diff_tree_array(tree, dataset.X, options, dir)
       (!complete) && return T(10000000)
    end
    if n!=0
       prediction_asymp,der_asymp,complete_asymp = SymbolicRegression.eval_diff_tree_array(tree,asympdata,options,dir)
       (!complete_asymp) && return T(10000000)
    end
     predictive_loss_L2Dis = sum(abs.(dataset.y .- prediction).^2)
    asymptotic_loss = sum(n*max.(0,(prediction_asymp - tree_asymptote)))     
    return predictive_loss_L2Dis + asymptotic_loss
    end
    
    function divergency(tree::SymbolicRegression.Node , dataset::SymbolicRegression.Dataset{T}, options;dir=1,n=100) where {T}
      _,d = size(dataset.X)
      divergency_data = copy(dataset.X)
      for i in collect(1:d)
         divergency_data[dir,i] = 7
	      divergency_data[dir+1,i] = 7
         divergency_data[dir+2,i] = 19
         divergency_data[dir+3,i] = 19   
      end
      prediction, complete = SymbolicRegression.eval_tree_array(tree, dataset.X, options)
      (!complete) && return T(10000000)
      prediction_div, _ = SymbolicRegression.eval_tree_array(tree, divergency_data, options)
     
      predictive_loss_L2Dis = sum(abs.(dataset.y .- prediction).^2)
      divergency_loss = n*sum(isfinite.(prediction_div))/d      #if Inf then no addition to divergency_loss
      return predictive_loss_L2Dis + divergency_loss
      end
            

    function Monotone_loss(tree::SymbolicRegression.Node , dataset::SymbolicRegression.Dataset{T}, options;dir=3,n=100) where {T}
    
    prediction, derivative, complete = SymbolicRegression.eval_diff_tree_array(tree, dataset.X, options, dir)
    (!complete) && return T(10000000)
    predictive_loss_L2Dis = sum((abs.(dataset.y .- prediction)).^2)
    ph_loss = sum(n*max.(derivative,0))
    return predictive_loss_L2Dis + ph_loss
    end




end
