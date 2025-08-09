module Errors

using JSON3

export LongportException, ApiResponse

struct ApiResponse{T}
    code::Int
    message::String
    data::T

    function ApiResponse(body::AbstractString)
        json = JSON3.read(body)
        new{typeof(json.data)}(json.code, json.message, json.data)
    end
end

struct LongportException <: Exception
    code::Union{Int, Nothing}
    trace_id::Union{String, Nothing}
    message::String
    
    function LongportException(code::Union{Int, Nothing}, trace_id::Union{String, Nothing}, message::String)
        new(code, trace_id, message)
    end
    
    function LongportException(message::String)
        new(nothing, nothing, message)
    end
end

function Base.show(io::IO, e::LongportException)
    if !isnothing(e.code)
        print(io, "LongportException: (code=$(e.code), trace_id=$(e.trace_id)) $(e.message)")
    else
        print(io, "LongportException: $(e.message)")
    end
end

end # module Errors
