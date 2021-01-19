using SymbolicUtils

@syms x1::Real x2::Real x3::Real x4::Real x5::Real x6::Real x7::Real x8::Real x9::Real x10::Real x11::Real x12::Real x13::Real x14::Real x15::Real x16::Real x17::Real x18::Real x19::Real x20::Real x21::Real x22::Real x23::Real x24::Real x25::Real x26::Real x27::Real x28::Real x29::Real x30::Real x31::Real x32::Real x33::Real x34::Real x35::Real x36::Real x37::Real x38::Real x39::Real x40::Real x41::Real x42::Real x43::Real x44::Real x45::Real x46::Real x47::Real x48::Real x49::Real x50::Real x51::Real x52::Real x53::Real x54::Real x55::Real x56::Real x57::Real x58::Real x59::Real x60::Real x61::Real x62::Real x63::Real x64::Real x65::Real x66::Real x67::Real x68::Real x69::Real x70::Real x71::Real x72::Real x73::Real x74::Real x75::Real x76::Real x77::Real x78::Real x79::Real x80::Real x81::Real x82::Real x83::Real x84::Real x85::Real x86::Real x87::Real x88::Real x89::Real x90::Real x91::Real x92::Real x93::Real x94::Real x95::Real x96::Real x97::Real x98::Real x99::Real x100::Real

function to_symbolic(X::AbstractMatrix{T}, tree::Node, options::Options) where {T<:Real}

    if options.useVarMap
        throw(AssertionError("Using custom variable names and converting to symbolic form is not supported"))
    end
    if size(X)[2] > 100
        throw(AssertionError("Using more than 100 features and converting to symbolic is not supported"))
    end

    printTree(tree, options)
    string_equation = stringTree(tree, options)
    symbolic_form = eval(Meta.parse(string_equation))
    return symbolic_form
end
