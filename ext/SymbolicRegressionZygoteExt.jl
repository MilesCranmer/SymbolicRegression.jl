module SymbolicRegressionZygoteExt

import SymbolicRegression.ConstantOptimizationModule: _withgradient
using Zygote: withgradient

_withgradient(f, t) = withgradient(f, t)

end
