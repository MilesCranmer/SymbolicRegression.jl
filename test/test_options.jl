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

# testing loss_scale parameter
op_log = Options(; loss_scale=:log);
@test op_log.loss_scale == :log

op_linear = Options(; loss_scale=:linear);
@test op_linear.loss_scale == :linear

# test that invalid loss_scale values are caught
@test_throws AssertionError Options(; loss_scale=:invalid)
@test_throws AssertionError Options(; loss_scale=:cubic)
