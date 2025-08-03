module Utils

using ..QuoteProtocol, Logging, Dates, JSON3

export to_namedtuple


"""
通用结构体转NamedTuple函数
"""
function to_namedtuple(obj)
    if obj === nothing
        return nothing
    elseif obj isa JSON3.Object
        # Convert JSON object to NamedTuple
        keys = Tuple(propertynames(obj))
        values = Tuple(to_namedtuple(obj[key]) for key in keys)
        return NamedTuple{keys}(values)
    elseif obj isa Union{JSON3.Array, Vector, SubArray}
        # Convert JSON array or Vector to Vector of converted items
        return [to_namedtuple(item) for item in obj]
    elseif isstructtype(typeof(obj))
        # Handle structs, but exclude types that are problematic or should be treated as values
        if obj isa Union{String, Date, DateTime, Tuple}
            return obj
        end
        field_names = fieldnames(typeof(obj))
        field_values = map(field_names) do name
            field_val = getfield(obj, name)
            if name === :timestamp && field_val isa Number
                # Convert protobuf timestamp (seconds) to DateTime
                return unix2datetime(field_val)
            # Recursively convert nested objects
            elseif (isstructtype(typeof(field_val)) && !(field_val isa Union{String, Date, DateTime, Tuple})) ||
                   (field_val isa JSON3.Object || field_val isa JSON3.Array)
                return to_namedtuple(field_val)
            else
                return field_val
            end
        end
        return NamedTuple{field_names}(Tuple(field_values))
    else
        # Return primitives and other types as-is
        return obj
    end
end


end
