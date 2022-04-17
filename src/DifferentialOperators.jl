struct Dx
    feature::Int

    Dx(feature::Int) = new(feature)
end

"""Create differential operator from string (e.g., `Dx("x1")`)"""
function Dx(var_string::String; varMap::Union{Array{String, 1}, Nothing}=nothing)
    if varMap === nothing
        feature = parse(Int, var_string[2:end])
    else
        feature = findfirst(i->varMap[i]==var_string, 1:length(varMap))
    end
    return Dx(feature)
end