type Dimension
	name::Symbol # column name in dataframe
	accessor::ASCIIString # this lets us do: var paymentsByTotal = payments.dimension(function(d) { return d.total; });
end

function infer_dimension{I<:Integer}(arr::DataArray{I}, name::Symbol)
	accessor = @sprintf("function(d){return d.%s; }", name)
	Dimension(name, accessor)
end
function infer_dimension{F<:AbstractFloat}(arr::DataArray{F}, name::Symbol)
	accessor = @sprintf("function(d){return Math.round(d.%s * 2)/2; }", name)
	Dimension(name, accessor)
end
function infer_dimension{S<:AbstractString}(arr::DataArray{S}, name::Symbol)
	accessor = @sprintf("function(d){return d.%s; }", name)
	Dimension(name, accessor)
end

Base.write(io::IO, dim::Dimension) = print(io, "var ", dim.name, " = cf.dimension(", dim.accessor, ");")