module Utils

using ..QuoteProtocol, Logging, Dates

export to_namedtuple


"""
通用结构体转NamedTuple函数
"""
function to_namedtuple(obj)
    if obj === nothing
        return nothing
    elseif obj isa Vector
        result = [to_namedtuple(item) for item in obj]
        if length(result) == 1      # 单个namedtuple不再以vector格式输出
            return result[1]
        end
        return result
    elseif isstructtype(typeof(obj))
        if obj isa String || obj isa Date
            return obj
        end
        field_names = fieldnames(typeof(obj))
        field_values = map(field_names) do name
            field_val = getfield(obj, name)
            if name === :timestamp
                # All protobuf timestamps are expected to be in seconds.
                dt = unix2datetime(field_val)
                return dt
            elseif isstructtype(typeof(field_val)) && !(field_val isa String)
                return to_namedtuple(field_val)
            else
                return field_val
            end
        end
        return NamedTuple{field_names}(Tuple(field_values))
    else
        return obj
    end
end


end
