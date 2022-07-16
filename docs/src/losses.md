# Losses

These losses, and their documentation, are included
from the [LossFunctions.jl](https://github.com/JuliaML/LossFunctions.jl)
package.

Pass the function as, e.g., `loss=L1DistLoss()`.

You can also declare your own loss as a function that takes
two (unweighted) or three (weighted) scalar arguments. For example,
```
f(x, y, w) = abs(x-y)*w
options = Options(loss=f)
```

## Regression:

Regression losses work on the distance between targets
and predictions: `r = x - y`.

### `LPDistLoss{P} <: DistanceLoss`

The P-th power absolute distance loss. It is Lipschitz continuous
iff `P == 1`, convex if and only if `P >= 1`, and strictly convex
iff `P > 1`.

```math
L(r) = |r|^P
```
### `L1DistLoss <: DistanceLoss`

The absolute distance loss.
Special case of the [`LPDistLoss`](@ref) with `P=1`.
It is Lipschitz continuous and convex, but not strictly convex.

```math
L(r) = |r|
```

---
```
              Lossfunction                     Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    3 │\.                     ./│    1 │            ┌------------│
      │ '\.                 ./' │      │            |            │
      │   \.               ./   │      │            |            │
      │    '\.           ./'    │      │_           |           _│
    L │      \.         ./      │   L' │            |            │
      │       '\.     ./'       │      │            |            │
      │         \.   ./         │      │            |            │
    0 │          '\./'          │   -1 │------------┘            │
      └────────────┴────────────┘      └────────────┴────────────┘
      -3                        3      -3                        3
                 ŷ - y                            ŷ - y
```

### `L2DistLoss <: DistanceLoss`

The least squares loss.
Special case of the [`LPDistLoss`](@ref) with `P=2`.
It is strictly convex.

```math
L(r) = |r|^2
```

---
```
              Lossfunction                     Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    9 │\                       /│    3 │                   .r/   │
      │".                     ."│      │                 .r'     │
      │ ".                   ." │      │              _./'       │
      │  ".                 ."  │      │_           .r/         _│
    L │   ".               ."   │   L' │         _:/'            │
      │    '\.           ./'    │      │       .r'               │
      │      \.         ./      │      │     .r'                 │
    0 │        "-.___.-"        │   -3 │  _/r'                   │
      └────────────┴────────────┘      └────────────┴────────────┘
      -3                        3      -2                        2
                 ŷ - y                            ŷ - y
```
### `PeriodicLoss <: DistanceLoss`

Measures distance on a circle of specified circumference `c`.

```math
L(r) = 1 - \cos \left( \frac{2 r \pi}{c} \right)
```

### `HuberLoss <: DistanceLoss`

Loss function commonly used for robustness to outliers.
For large values of `d` it becomes close to the [`L1DistLoss`](@ref),
while for small values of `d` it resembles the [`L2DistLoss`](@ref).
It is Lipschitz continuous and convex, but not strictly convex.

```math
L(r) = \begin{cases} \frac{r^2}{2} & \quad \text{if } | r | \le \alpha \\ \alpha | r | - \frac{\alpha^3}{2} & \quad \text{otherwise}\\ \end{cases}
```

---
```
              Lossfunction (d=1)               Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    2 │                         │    1 │                .+-------│
      │                         │      │              ./'        │
      │\.                     ./│      │             ./          │
      │ '.                   .' │      │_           ./          _│
    L │   \.               ./   │   L' │           /'            │
      │     \.           ./     │      │          /'             │
      │      '.         .'      │      │        ./'              │
    0 │        '-.___.-'        │   -1 │-------+'                │
      └────────────┴────────────┘      └────────────┴────────────┘
      -2                        2      -2                        2
                 ŷ - y                            ŷ - y
```

### `L1EpsilonInsLoss <: DistanceLoss`

The ``ϵ``-insensitive loss. Typically used in linear support vector
regression. It ignores deviances smaller than ``ϵ``, but penalizes
larger deviances linearly.
It is Lipschitz continuous and convex, but not strictly convex.

```math
L(r) = \max \{ 0, | r | - \epsilon \}
```

---
```
              Lossfunction (ϵ=1)               Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    2 │\                       /│    1 │                  ┌------│
      │ \                     / │      │                  |      │
      │  \                   /  │      │                  |      │
      │   \                 /   │      │_      ___________!     _│
    L │    \               /    │   L' │      |                  │
      │     \             /     │      │      |                  │
      │      \           /      │      │      |                  │
    0 │       \_________/       │   -1 │------┘                  │
      └────────────┴────────────┘      └────────────┴────────────┘
      -3                        3      -2                        2
                 ŷ - y                            ŷ - y
```
### `L2EpsilonInsLoss <: DistanceLoss`

The quadratic ``ϵ``-insensitive loss.
Typically used in linear support vector regression.
It ignores deviances smaller than ``ϵ``, but penalizes
larger deviances quadratically. It is convex, but not strictly convex.

```math
L(r) = \max \{ 0, | r | - \epsilon \}^2
```

---
```
              Lossfunction (ϵ=0.5)             Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    8 │                         │    1 │                  /      │
      │:                       :│      │                 /       │
      │'.                     .'│      │                /        │
      │ \.                   ./ │      │_         _____/        _│
    L │  \.                 ./  │   L' │         /               │
      │   \.               ./   │      │        /                │
      │    '\.           ./'    │      │       /                 │
    0 │      '-._______.-'      │   -1 │      /                  │
      └────────────┴────────────┘      └────────────┴────────────┘
      -3                        3      -2                        2
                 ŷ - y                            ŷ - y
```
### `LogitDistLoss <: DistanceLoss`

The distance-based logistic loss for regression.
It is strictly convex and Lipschitz continuous.

```math
L(r) = - \ln \frac{4 e^r}{(1 + e^r)^2}
```

---
```
              Lossfunction                     Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    2 │                         │    1 │                   _--'''│
      │\                       /│      │                ./'      │
      │ \.                   ./ │      │              ./         │
      │  '.                 .'  │      │_           ./          _│
    L │   '.               .'   │   L' │           ./            │
      │     \.           ./     │      │         ./              │
      │      '.         .'      │      │       ./                │
    0 │        '-.___.-'        │   -1 │___.-''                  │
      └────────────┴────────────┘      └────────────┴────────────┘
      -3                        3      -4                        4
                 ŷ - y                            ŷ - y
```
### `QuantileLoss <: DistanceLoss`

The distance-based quantile loss, also known as pinball loss,
can be used to estimate conditional τ-quantiles.
It is Lipschitz continuous and convex, but not strictly convex.
Furthermore it is symmetric if and only if `τ = 1/2`.

```math
L(r) = \begin{cases} -\left( 1 - \tau  \right) r & \quad \text{if } r < 0 \\ \tau r & \quad \text{if } r \ge 0 \\ \end{cases}
```

---
```
              Lossfunction (τ=0.7)             Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    2 │'\                       │  0.3 │            ┌------------│
      │  \.                     │      │            |            │
      │   '\                    │      │_           |           _│
      │     \.                  │      │            |            │
    L │      '\              ._-│   L' │            |            │
      │        \.         ..-'  │      │            |            │
      │         '.     _r/'     │      │            |            │
    0 │           '_./'         │ -0.7 │------------┘            │
      └────────────┴────────────┘      └────────────┴────────────┘
      -3                        3      -3                        3
                 ŷ - y                            ŷ - y
```

## Classification:

Classifications losses (assuming binary) work on the margin between targets
and predictions: `r = x y`, assuming the target `y` is either `-1`
or `+1`.

### `ZeroOneLoss <: MarginLoss`

The classical classification loss. It penalizes every misclassified
observation with a loss of `1` while every correctly classified
observation has a loss of `0`.
It is not convex nor continuous and thus seldom used directly.
Instead one usually works with some classification-calibrated
surrogate loss, such as [L1HingeLoss](@ref).

```math
L(a) = \begin{cases} 1 & \quad \text{if } a < 0 \\ 0 & \quad \text{if } a >= 0\\ \end{cases}
```

---
```
              Lossfunction                     Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    1 │------------┐            │    1 │                         │
      │            |            │      │                         │
      │            |            │      │                         │
      │            |            │      │_________________________│
      │            |            │      │                         │
      │            |            │      │                         │
      │            |            │      │                         │
    0 │            └------------│   -1 │                         │
      └────────────┴────────────┘      └────────────┴────────────┘
      -2                        2      -2                        2
                y * h(x)                         y * h(x)
```
### `PerceptronLoss <: MarginLoss`

The perceptron loss linearly penalizes every prediction where the
resulting `agreement <= 0`.
It is Lipschitz continuous and convex, but not strictly convex.

```math
L(a) = \max \{ 0, -a \}
```

---
```
              Lossfunction                     Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    2 │\.                       │    0 │            ┌------------│
      │ '..                     │      │            |            │
      │   \.                    │      │            |            │
      │     '.                  │      │            |            │
    L │      '.                 │   L' │            |            │
      │        \.               │      │            |            │
      │         '.              │      │            |            │
    0 │           \.____________│   -1 │------------┘            │
      └────────────┴────────────┘      └────────────┴────────────┘
      -2                        2      -2                        2
                 y ⋅ ŷ                            y ⋅ ŷ
```
### `LogitMarginLoss <: MarginLoss`

The margin version of the logistic loss. It is infinitely many
times differentiable, strictly convex, and Lipschitz continuous.

```math
L(a) = \ln (1 + e^{-a})
```

---
```
              Lossfunction                     Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    2 │ \.                      │    0 │                  ._--/""│
      │   \.                    │      │               ../'      │
      │     \.                  │      │              ./         │
      │       \..               │      │            ./'          │
    L │         '-_             │   L' │          .,'            │
      │            '-_          │      │         ./              │
      │               '\-._     │      │      .,/'               │
    0 │                    '""*-│   -1 │__.--''                  │
      └────────────┴────────────┘      └────────────┴────────────┘
      -2                        2      -4                        4
                 y ⋅ ŷ                            y ⋅ ŷ
```
### `L1HingeLoss <: MarginLoss`

The hinge loss linearly penalizes every prediction where the
resulting `agreement < 1` .
It is Lipschitz continuous and convex, but not strictly convex.

```math
L(a) = \max \{ 0, 1 - a \}
```

---
```
              Lossfunction                     Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    3 │'\.                      │    0 │                  ┌------│
      │  ''_                    │      │                  |      │
      │     \.                  │      │                  |      │
      │       '.                │      │                  |      │
    L │         ''_             │   L' │                  |      │
      │            \.           │      │                  |      │
      │              '.         │      │                  |      │
    0 │                ''_______│   -1 │------------------┘      │
      └────────────┴────────────┘      └────────────┴────────────┘
      -2                        2      -2                        2
                 y ⋅ ŷ                            y ⋅ ŷ
```
### `L2HingeLoss <: MarginLoss`

The truncated least squares loss quadratically penalizes every
prediction where the resulting `agreement < 1`.
It is locally Lipschitz continuous and convex,
but not strictly convex.

```math
L(a) = \max \{ 0, 1 - a \}^2
```

---
```
              Lossfunction                     Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    5 │     .                   │    0 │                 ,r------│
      │     '.                  │      │               ,/        │
      │      '\                 │      │             ,/          │
      │        \                │      │           ,/            │
    L │         '.              │   L' │         ./              │
      │          '.             │      │       ./                │
      │            \.           │      │     ./                  │
    0 │              '-.________│   -5 │   ./                    │
      └────────────┴────────────┘      └────────────┴────────────┘
      -2                        2      -2                        2
                 y ⋅ ŷ                            y ⋅ ŷ
```
### `SmoothedL1HingeLoss <: MarginLoss`

As the name suggests a smoothed version of the L1 hinge loss.
It is Lipschitz continuous and convex, but not strictly convex.

```math
L(a) = \begin{cases} \frac{0.5}{\gamma} \cdot \max \{ 0, 1 - a \} ^2 & \quad \text{if } a \ge 1 - \gamma \\ 1 - \frac{\gamma}{2} - a & \quad \text{otherwise}\\ \end{cases}
```

---
```
              Lossfunction (γ=2)               Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    2 │\.                       │    0 │                 ,r------│
      │ '.                      │      │               ./'       │
      │   \.                    │      │              ,/         │
      │     '.                  │      │            ./'          │
    L │      '.                 │   L' │           ,'            │
      │        \.               │      │         ,/              │
      │          ',             │      │       ./'               │
    0 │            '*-._________│   -1 │______./                 │
      └────────────┴────────────┘      └────────────┴────────────┘
      -2                        2      -2                        2
                 y ⋅ ŷ                            y ⋅ ŷ
```
### `ModifiedHuberLoss <: MarginLoss`

A special (4 times scaled) case of the [`SmoothedL1HingeLoss`](@ref)
with `γ=2`. It is Lipschitz continuous and convex,
but not strictly convex.

```math
L(a) = \begin{cases} \max \{ 0, 1 - a \} ^2 & \quad \text{if } a \ge -1 \\ - 4 a & \quad \text{otherwise}\\ \end{cases}
```

---
```
              Lossfunction                     Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    5 │    '.                   │    0 │                .+-------│
      │     '.                  │      │              ./'        │
      │      '\                 │      │             ,/          │
      │        \                │      │           ,/            │
    L │         '.              │   L' │         ./              │
      │          '.             │      │       ./'               │
      │            \.           │      │______/'                 │
    0 │              '-.________│   -5 │                         │
      └────────────┴────────────┘      └────────────┴────────────┘
      -2                        2      -2                        2
                 y ⋅ ŷ                            y ⋅ ŷ
```
### `L2MarginLoss <: MarginLoss`

The margin-based least-squares loss for classification,
which penalizes every prediction where `agreement != 1` quadratically.
It is locally Lipschitz continuous and strongly convex.

```math
L(a) = {\left( 1 - a \right)}^2
```

---
```
              Lossfunction                     Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    5 │     .                   │    2 │                       ,r│
      │     '.                  │      │                     ,/  │
      │      '\                 │      │                   ,/    │
      │        \                │      ├                 ,/      ┤
    L │         '.              │   L' │               ./        │
      │          '.             │      │             ./          │
      │            \.          .│      │           ./            │
    0 │              '-.____.-' │   -3 │         ./              │
      └────────────┴────────────┘      └────────────┴────────────┘
      -2                        2      -2                        2
                 y ⋅ ŷ                            y ⋅ ŷ
```
### `ExpLoss <: MarginLoss`

The margin-based exponential loss for classification, which
penalizes every prediction exponentially. It is infinitely many
times differentiable, locally Lipschitz continuous and strictly
convex, but not clipable.

```math
L(a) = e^{-a}
```

---
```
              Lossfunction                     Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    5 │  \.                     │    0 │               _,,---:'""│
      │   l                     │      │           _r/"'         │
      │    l.                   │      │        .r/'             │
      │     ":                  │      │      .r'                │
    L │       \.                │   L' │     ./                  │
      │        "\..             │      │    .'                   │
      │           '":,_         │      │   ,'                    │
    0 │                ""---:.__│   -5 │  ./                     │
      └────────────┴────────────┘      └────────────┴────────────┘
      -2                        2      -2                        2
                 y ⋅ ŷ                            y ⋅ ŷ
```
### `SigmoidLoss <: MarginLoss`

Continuous loss which penalizes every prediction with a loss
within in the range (0,2). It is infinitely many times
differentiable, Lipschitz continuous but nonconvex.

```math
L(a) = 1 - \tanh(a)
```

---
```
              Lossfunction                     Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    2 │""'--,.                  │    0 │..                     ..│
      │      '\.                │      │ "\.                 ./" │
      │         '.              │      │    ',             ,'    │
      │           \.            │      │      \           /      │
    L │            "\.          │   L' │       \         /       │
      │              \.         │      │        \.     ./        │
      │                \,       │      │         \.   ./         │
    0 │                  '"-:.__│   -1 │          ',_,'          │
      └────────────┴────────────┘      └────────────┴────────────┘
      -2                        2      -2                        2
                 y ⋅ ŷ                            y ⋅ ŷ
```
### `DWDMarginLoss <: MarginLoss`

The distance weighted discrimination margin loss. It is a
differentiable generalization of the [L1HingeLoss](@ref) that is
different than the [SmoothedL1HingeLoss](@ref). It is Lipschitz
continuous and convex, but not strictly convex.

```math
L(a) = \begin{cases} 1 - a & \quad \text{if } a \ge \frac{q}{q+1} \\ \frac{1}{a^q} \frac{q^q}{(q+1)^{q+1}} & \quad \text{otherwise}\\ \end{cases}
```

---
```
              Lossfunction (q=1)               Derivative
      ┌────────────┬────────────┐      ┌────────────┬────────────┐
    2 │      ".                 │    0 │                     ._r-│
      │        \.               │      │                   ./    │
      │         ',              │      │                 ./      │
      │           \.            │      │                 /       │
    L │            "\.          │   L' │                .        │
      │              \.         │      │                /        │
      │               ":__      │      │               ;         │
    0 │                   '""---│   -1 │---------------┘         │
      └────────────┴────────────┘      └────────────┴────────────┘
      -2                        2      -2                        2
                 y ⋅ ŷ                            y ⋅ ŷ
```
