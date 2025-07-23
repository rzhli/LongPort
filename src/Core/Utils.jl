module Utils

export to_namedtuple

"""
通用结构体转NamedTuple函数
"""
function to_namedtuple(obj)
    if obj === nothing
        return nothing
    elseif typeof(obj) <: Vector
        return [to_namedtuple(item) for item in obj]
    elseif isstructtype(typeof(obj))
        if isa(obj, String) # String is a struct, but we don't want to convert it
            return obj
        end
        field_names = fieldnames(typeof(obj))
        field_values = []
        for name in field_names
            field_val = getfield(obj, name)
            if isa(field_val, Union{Float64, Int64, String, Bool}) || field_val === nothing
                push!(field_values, field_val)
            else
                push!(field_values, to_namedtuple(field_val))
            end
        end
        return NamedTuple{field_names}(field_values)
    else
        return obj
    end
end

end
