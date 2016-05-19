type Group
	dim::Dimension
	name::ASCIIString
	reduction::ASCIIString
end
Base.write(io::IO, group::Group) = print(io, "var ", group.name, " = ", group.dim.name, ".group().", group.reduction, ";")

reduce_count(dim::Dimension) = Group(dim, string(dim.name)*"_count", "reduceCount()")
reduce_sum(dim::Dimension) = Group(dim, string(dim.name)*"_sum", @sprintf("reduceSum(function(d){ return d.%s; })", dim.name))

infer_group{I<:Integer}(arr::AbstractDataArray{I}, dim::Dimension) = reduce_sum(dim)
infer_group{F<:AbstractFloat}(arr::AbstractDataArray{F}, dim::Dimension) = reduce_sum(dim)
infer_group{S<:AbstractString}(arr::AbstractDataArray{S}, dim::Dimension) = reduce_count(dim)