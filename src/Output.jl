using SymbolicUtils

@syms x1::Real x2::Real x3::Real x4::Real x5::Real x6::Real x7::Real x8::Real x9::Real x10::Real x11::Real x12::Real x13::Real x14::Real x15::Real x16::Real x17::Real x18::Real x19::Real x20::Real x21::Real x22::Real x23::Real x24::Real x25::Real x26::Real x27::Real x28::Real x29::Real x30::Real x31::Real x32::Real x33::Real x34::Real x35::Real x36::Real x37::Real x38::Real x39::Real x40::Real x41::Real x42::Real x43::Real x44::Real x45::Real x46::Real x47::Real x48::Real x49::Real x50::Real x51::Real x52::Real x53::Real x54::Real x55::Real x56::Real x57::Real x58::Real x59::Real x60::Real x61::Real x62::Real x63::Real x64::Real x65::Real x66::Real x67::Real x68::Real x69::Real x70::Real x71::Real x72::Real x73::Real x74::Real x75::Real x76::Real x77::Real x78::Real x79::Real x80::Real x81::Real x82::Real x83::Real x84::Real x85::Real x86::Real x87::Real x88::Real x89::Real x90::Real x91::Real x92::Real x93::Real x94::Real x95::Real x96::Real x97::Real x98::Real x99::Real x100::Real

const all_symbols = [x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16, x17, x18, x19, x20, x21, x22, x23, x24, x25, x26, x27, x28, x29, x30, x31, x32, x33, x34, x35, x36, x37, x38, x39, x40, x41, x42, x43, x44, x45, x46, x47, x48, x49, x50, x51, x52, x53, x54, x55, x56, x57, x58, x59, x60, x61, x62, x63, x64, x65, x66, x67, x68, x69, x70, x71, x72, x73, x74, x75, x76, x77, x78, x79, x80, x81, x82, x83, x84, x85, x86, x87, x88, x89, x90, x91, x92, x93, x94, x95, x96, x97, x98, x99, x100]

function evalTreeSymbolic(tree::Node, options::Options)
    if tree.degree == 0
        if tree.constant
            return tree.val
        else
            return all_symbols[tree.val]
        end
    elseif tree.degree == 1
        left_side = evalTreeSymbolic(tree.l, options)
        return options.unaops[tree.op](left_side)
    else
        left_side = evalTreeSymbolic(tree.l, options)
        right_side = evalTreeSymbolic(tree.r, options)
        return options.binops[tree.op](left_side, right_side)
    end
end


function to_symbolic(tree::Node, options::Options)
    if options.useVarMap
        throw(AssertionError("Using custom variable names and converting to symbolic form is not supported"))
    end
    return evalTreeSymbolic(tree, options)
end
