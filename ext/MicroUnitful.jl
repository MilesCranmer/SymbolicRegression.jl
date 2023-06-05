module MicroUnitful

#! format: off
const D_TYPE = Dict{Symbol,Rational{Int}}
const COMPAT_D_TYPE = Union{D_TYPE,Vector{Pair{Symbol,Rational{Int}}},Vector{Pair{Symbol,Int}}}
struct Dimensions
    data::D_TYPE

    Dimensions() = new(D_TYPE())
    Dimensions(data::D_TYPE) = new(data)
    Dimensions(data::COMPAT_D_TYPE) = new(D_TYPE(data))
end
struct Quantity{T}
    val::T
    dimensions::Dimensions
    valid::Bool

    Quantity(x) = new{typeof(x)}(x, Dimensions(), true)
    Quantity(x, dimensions::Dimensions) = new{typeof(x)}(x, dimensions, true)
    Quantity(x, data::COMPAT_D_TYPE) = new{typeof(x)}(x, Dimensions(data), true)
    Quantity(x, valid::Bool) = new{typeof(x)}(x, Dimensions(), valid)
    Quantity(x, dimensions::Dimensions, valid::Bool) = new{typeof(x)}(x, dimensions, valid)
    Quantity(x, data::COMPAT_D_TYPE, valid::Bool) = new{typeof(x)}(x, Dimensions(data), valid)
end

Base.show(io::IO, d::Dimensions) = foreach(k -> d[k] != 0 ? (print(io, k); pretty_print_exponent(io, d[k]); print(io, " ")) : print(io, ""), keys(d))
Base.show(io::IO, q::Quantity) = q.valid ? print(io, q.val, " ", q.dimensions) : print(io, "INVALID")
tryround(x::Rational{Int}) = isinteger(x) ? round(Int, x) : x
pretty_print_exponent(io::IO, x::Rational{Int}) = (x >= 0 && isinteger(x)) ? print(io, "^", round(Int, x)) : print(io, "^(", tryround(x), ")")
Base.convert(::Type{Dimensions}, d::D_TYPE) = Dimensions(d)
Base.isfinite(q::Quantity) = isfinite(q.val)
Base.keys(d::Dimensions) = keys(d.data)
Base.values(d::Dimensions) = values(d.data)
Base.iszero(d::Dimensions) = all(iszero, values(d))
Base.getindex(d::Dimensions, k::Symbol) = get(d.data, k, zero(Rational{Int}))
Base.:(==)(l::Dimensions, r::Dimensions) = all(k -> (l[k] == r[k]), union(keys(l), keys(r)))
Base.convert(::Type{T}, q::Quantity) where {T<:Real} = q.valid ? (iszero(q.dimensions) ? convert(T, q.val) : throw(error("Quantity $(q) has dimensions!"))) : throw(error("Quantity $(q) is invalid!"))
Base.float(q::Quantity{T}) where {T<:AbstractFloat} = convert(T, q)

Base.:*(l::Dimensions, r::Dimensions) = Dimensions(D_TYPE([(k, l[k] + r[k]) for k in union(keys(l.data), keys(r.data))]))
Base.:/(l::Dimensions, r::Dimensions) = Dimensions(D_TYPE([(k, l[k] - r[k]) for k in union(keys(l.data), keys(r.data))]))
Base.inv(d::Dimensions) = Dimensions(D_TYPE([(k, -d[k]) for k in keys(d.data)]))

Base.:*(l::Quantity, r::Quantity) = Quantity(l.val * r.val, l.dimensions * r.dimensions, l.valid && r.valid)
Base.:/(l::Quantity, r::Quantity) = Quantity(l.val / r.val, l.dimensions / r.dimensions, l.valid && r.valid)
Base.:+(l::Quantity, r::Quantity) = Quantity(l.val + r.val, l.dimensions, l.dimensions == r.dimensions)
Base.:-(l::Quantity, r::Quantity) = Quantity(l.val - r.val, l.dimensions, l.dimensions == r.dimensions)
Base.:^(l::Quantity, r::Quantity) = let rr=convert(Rational{Int}, r.val); Quantity(l.val ^ rr, l.dimensions ^ rr, l.valid && r.valid && iszero(r.dimensions)); end

Base.:*(l::Quantity, r::Number) = Quantity(l.val * r, l.dimensions, l.valid)
Base.:*(l::Number, r::Quantity) = Quantity(l * r.val, r.dimensions, r.valid)
Base.:/(l::Quantity, r::Number) = Quantity(l.val / r, l.dimensions, l.valid)
Base.:/(l::Number, r::Quantity) = l * inv(r)
Base.:^(l::Dimensions, r::Rational{Int}) = Dimensions(D_TYPE([(k, l.data[k] * r) for k in keys(l.data)]))
Base.:^(l::Quantity, r::Number) = let rr=convert(Rational{Int}, r); Quantity(l.val ^ rr, l.dimensions ^ rr, l.valid); end
Base.inv(q::Quantity) = Quantity(inv(q.val), inv(q.dimensions), q.valid)
Base.sqrt(q::Quantity) = Quantity(sqrt(q.val), q.dimensions ^ (1//2), q.valid)

#! format: on
end