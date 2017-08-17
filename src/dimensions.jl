mutable struct Dimension
	name::Symbol # the column name in dataframe
	accessor::String #var paymentsByTotal = payments.dimension(function(d) { return d.total; });
	bin_width::Float64 # discretization width, NaN if unused

	Dimension(name::Symbol, accessor::String, bin_width::Float64=NaN) = new(name, accessor, bin_width)
end


"""
    round_to_nearest_half_order_of_magnitude

Rounds a number to the nearest half order of magnitude, {...0.1,0.5,1,5,10,50,100,500...}
"""
function round_to_nearest_half_order_of_magnitude(w::Real)
    a = round(Int, log(w)/log(10))
    x_mid = 10.0^a
    x_lo = x_mid*0.5
    x_hi = 0.5*10.0^(a+1)
    i = indmin([abs(x_mid-w), abs(x_lo-w), abs(x_hi-w)])
    i == 1 ? x_mid : i ==2 ? x_lo : x_hi
end


"""
	infer_dimension

Constructs a Dimension suitable for the type in arr.
"""
function infer_dimension(arr::AbstractDataArray{I}, name::Symbol) where I<:Integer
	accessor = @sprintf("function(d){return d.%s; }", name)
	Dimension(name, accessor)
end
function infer_dimension(arr::AbstractDataArray{F}, name::Symbol, desired_bincount::Int=10) where F<:AbstractFloat

    lo,hi = extrema(arr)
    bin_width = round_to_nearest_half_order_of_magnitude((hi-lo)/desired_bincount)

	accessor = @sprintf("function(d){return Math.round(d.%s / %f)*%f; }", name, bin_width, bin_width)
	Dimension(name, accessor, bin_width)
end
function infer_dimension(arr::AbstractDataArray{S}, name::Symbol) where S<:AbstractString
	accessor = @sprintf("function(d){return d.%s; }", name)
	Dimension(name, accessor)
end


Base.write(io::IO, dim::Dimension) = print(io, "var ", dim.name, " = cf.dimension(", dim.accessor, ");")
