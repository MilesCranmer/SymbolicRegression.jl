#functions
module ConstrainsData
using SymbolicRegression 
using Random
using Distributions


function symmetry_loss(tree::SymbolicRegression.Node, dataset::SymbolicRegression.Dataset{T},options,var1=1,var2=2,var3=3,var4=4,n=100) where {T}
   _,d= size(dataset.X)
   symmetrydata = copy(dataset.X)
   symmetrydata[var1,:],symmetrydata[var2,:],symmetrydata[var3,:],symmetrydata[var4,:]=symmetrydata[var2,:],symmetrydata[var1,:],symmetrydata[var4,:],symmetrydata[var3,:]
   prediction1, complete1 = SymbolicRegression.eval_tree_array(tree,dataset.X,options)
   (!complete1) && return(T(10000000))
   prediction2, complete2 = SymbolicRegression.eval_tree_array(tree,symmetrydata,options)
   (!complete2) && return(T(10000000))
   
   predictive_loss_L2Dis = sum(abs.(dataset.y .- prediction1))
   symmetry_loss = sum(n*abs.(prediction1-prediction2))/d
  
   return predictive_loss_L2Dis + symmetry_loss

end

function divergency_symmetry_loss(treetree::SymbolicRegression.Node, dataset::SymbolicRegression.Dataset{T},options,var1=2,var2=3,n=5) where {T}
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

n_data = 10
Random.seed!(1234)
data = Float32.(rand(1:10000,2,n_data)) # 10 points

distance = Float32.(rand(1:100,1,n_data)) #10 points)

G = Float32(6.6743e-11)
F = G .*data[1,:] .*data[2,:]./(distance[1,:] .^2) 
d = Normal()
noise = rand(d,n_data)
NoisyF = F + Float32.(0.01.*noise.*F)
#F1 = 2*G .*mass .*mass2 ./(distance .^2) 
#mass = reshape(mass,2,10)
#distance = reshape(distance,1,10)    #todo use the size of mass and distance
#F1 = reshape(F1,1,15)

#nondimensional


X = vcat(data,distance)
shape = size(X)


end