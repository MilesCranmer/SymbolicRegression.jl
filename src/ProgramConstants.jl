module ProgramConstantsModule

const MAX_DEGREE = 2
const CONST_TYPE = Float32
const BATCH_DIM = 2
const FEATURE_DIM = 1
const RecordType = Dict{String,Any}

"""Enum for concurrency type (to get function specialization)"""
abstract type SRConcurrency end
struct SRSerial <: SRConcurrency end
struct SRThreaded <: SRConcurrency end
struct SRDistributed <: SRConcurrency end

end
