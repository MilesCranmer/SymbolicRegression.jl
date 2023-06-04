# Losses

These losses, and their documentation, are included
from the [LossFunctions.jl](https://github.com/JuliaML/LossFunctions.jl)
package.

Pass the function as, e.g., `elementwise_loss=L1DistLoss()`.

You can also declare your own loss as a function that takes
two (unweighted) or three (weighted) scalar arguments. For example,

```
f(x, y, w) = abs(x-y)*w
options = Options(elementwise_loss=f)
```

## Regression

Regression losses work on the distance between targets
and predictions: `r = x - y`.

```@docs
LPDistLoss{P}
L1DistLoss
L2DistLoss
PeriodicLoss
HuberLoss
L1EpsilonInsLoss
L2EpsilonInsLoss
LogitDistLoss
QuantileLoss
```

## Classification

Classifications losses (assuming binary) work on the margin between targets
and predictions: `r = x y`, assuming the target `y` is either `-1`
or `+1`.

```@docs
ZeroOneLoss
PerceptronLoss
LogitMarginLoss
L1HingeLoss
L2HingeLoss
SmoothedL1HingeLoss
ModifiedHuberLoss
L2MarginLoss
ExpLoss
SigmoidLoss
DWDMarginLoss
```
