using SymbolicRegression
using Plots
using LinearAlgebra
using Distributions
using MLJ

#region function definitions
function multivariate_gaussian(x::Vector{Float64}, μ::Vector{Float64}, Σ::Matrix{Float64})
    """
    Compute the probability density of a N-D Gaussian distribution at point x.

    Parameters:
    x - Point at which to evaluate the PDF (N-element vectorm)
    μ - Mean vector (N-element vector)
    Σ - Covariance matrix (N×N matrix)

    Returns:
    The probability density at point x
    """
    N = length(μ)
    det_Σ = det(Σ)
    inv_Σ = inv(Σ)

    # Normalization constant
    normalization = 1 / ((2π)^(N / 2) * sqrt(det_Σ))

    # Exponent term
    diff = x - μ
    exponent = -0.5 * diff' * inv_Σ * diff

    return normalization * exp(exponent)
end

function conditional_y_given_x(μ::Vector{Float64}, Σ::Matrix{Float64}, x_val::Float64)
    """
    Compute P(Y|X=x) conditional distribution
    Returns a Normal distribution object
    """
    μ_cond = μ[2] + (Σ[1, 2] / Σ[1, 1]) * (x_val - μ[1])
    σ²_cond = Σ[2, 2] - (Σ[1, 2]^2) / Σ[1, 1]
    return Normal(μ_cond, sqrt(σ²_cond))
end

function conditional_x_given_y(μ::Vector{Float64}, Σ::Matrix{Float64}, y_val::Float64)
    """
    Compute P(X|Y=y) conditional distribution
    Returns a Normal distribution object
    """
    μ_cond = μ[1] + (Σ[1, 2] / Σ[2, 2]) * (y_val - μ[2])
    σ²_cond = Σ[1, 1] - (Σ[1, 2]^2) / Σ[2, 2]
    return Normal(μ_cond, sqrt(σ²_cond))
end
#endregion

#region Plotting and parameter specification
# Example usage:
μ = [1.0, 2.0]  # Mean vector
Σ = [
    1.0 0.6    # Covariance matrix
    0.6 2.0
]

gaussian_simple(x, y) = multivariate_gaussian([x, y], μ, Σ)
marginal_x = Normal(μ[1], sqrt(Σ[1, 1]))
marginal_y = Normal(μ[2], sqrt(Σ[2, 2]))
conditional_x(y_condition) = conditional_x_given_y(μ, Σ, y_condition)
conditional_y(x_condition) = conditional_y_given_x(μ, Σ, x_condition)

x = -4:0.1:6
y = -3:0.1:7
x = reshape(collect(x),:,1)
X = repeat(x', length(y))
Y = repeat(y', length(x))
Z = gaussian_simple.(X, Y)

plot(
    x,
    y,
    gaussian_simple;
    st=:surface,
    title="Gaussian 2D",
    xlabel="x",
    ylabel="y",
    zlabel="z",
)
#endregion

x = -4:0.1:6
y = -3:0.1:7

# Marginal Dataset
prob_x = pdf(marginal_x, x)
prob_y = pdf(marginal_y, y)

x_slices = [-2.2, 4.3]
y_slices = [-1.4, 3.5]

# Conditional Datasets
prob_x_given_y_is_n2_2 = pdf(conditional_x(x_slices[1]), x)
prob_x_given_y_is_4_3 = pdf(conditional_x(x_slices[2]), x)
prob_y_given_x_is_n1_4 = pdf(conditional_y(y_slices[1]), y)
prob_y_given_x_is_3_5 = pdf(conditional_y(y_slices[2]), y)

#region Low level API
options = SymbolicRegression.Options(;
    binary_operators=[+, *, /, -], unary_operators=[cos, exp]
)

if true
    hall_of_fame = equation_search(
        reshape(collect(x), 1, :), prob_x; options=options, parallelism=:serial, niterations=10
    )

    dominating = calculate_pareto_frontier(hall_of_fame)

    trees = [member.tree for member in dominating]

    initial_population = [[hall_of_fame.members]; [hall_of_fame.members]]
    println(typeof(initial_population))
    println("Press any key to continue...")
    readline()
    options1 = SymbolicRegression.Options(;
        binary_operators=[+, *, /, -], unary_operators=[cos, exp], populations = 2, population_size = length(initial_population[1])
        )
    
    hof = equation_search(
         reshape(collect(x), 1, :), prob_x; options=options1, parallelism=:serial, initial_populations=initial_population
    )

    println("Press any key to continue...")
    readline()

    tree = trees[end]
    output, did_succeed = eval_tree_array(tree, X, options)

    println("Complexity\tMSE\tEquation")

    for member in dominating
        complexity = compute_complexity(member, options)
        loss = member.loss
        string = string_tree(member.tree, options)

        println("$(complexity)\t$(loss)\t$(string)")
    end
end
#endregion

#region MLJ interface
# model = SRRegressor(
#     binary_operators=[+, *, /, -],
#     unary_operators=[cos, exp],
#     niterations=10
# )

# mach = machine(model, x, prob_x)
# fit!(mach)

# r=report(mach)
# println("$(r.equations[r.best_idx])")
#endregion 

#region custom Dataset and Loss
var = [zeros(size(x)); zeros(size(x)); ones(size(y)); ones(size(y))]
xy = [collect(x); collect(x); collect(y); collect(y)]
targets = [prob_x_given_y_is_n2_2; prob_x_given_y_is_4_3; prob_y_given_x_is_n1_4; prob_y_given_x_is_3_5]
weights = [ones(size(x))*pdf(marginal_y, x_slices[1]); ones(size(x))*pdf(marginal_y, x_slices[2]); ones(size(y))*pdf(marginal_x, y_slices[1]); ones(size(y))*pdf(marginal_x, y_slices[2])]

# There is no need for a custom dataset or custom Loss, we can directly compute the joint.
#endregion custom Dataset and Loss


# Manipulate expression in Julia sing the object (We need to multiply conditional and marginal expressions)
# Initialize the population