using Test
using SymbolicRegression
using Optim: Optim

# testing types
op = Options(; optimizer_options=(iterations=16, f_calls_limit=100, x_tol=1e-16));
@test isa(op.optimizer_options, Optim.Options)

op = Options(;
    optimizer_options=Dict(:iterations => 32, :g_calls_limit => 50, :f_tol => 1e-16)
);
@test isa(op.optimizer_options, Optim.Options)

optim_op = Optim.Options(; iterations=16)
op = Options(; optimizer_options=optim_op);
@test isa(op.optimizer_options, Optim.Options)
