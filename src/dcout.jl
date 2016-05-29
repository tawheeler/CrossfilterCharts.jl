type DCOut
	df::DataFrame
	dims::Vector{Dimension}
	groups::Vector{Group}
	charts::Vector{DCChart}

	function DCOut(df::DataFrame)

		dims = Dimension[]
		groups = Group[]
		charts = DCChart[]

		for name in names(df)

			arr = df[name]
			if can_infer_chart(arr)
				dim = infer_dimension(arr, name)
				push!(dims, dim)

				group = infer_group(arr, dim)
				push!(groups, group)

				chart = infer_chart(arr, group)
				push!(charts, chart)
			end
		end

		new(df, dims, groups, charts)
	end
end

type NotInferrableError <: Exception end

function quick_add(dcout::DCOut, column::Symbol, chart_constructor::Function)
	if can_infer_chart(dcout.df[column])
		i = 0
		for i in 1 : length(dcout.dims)
			if (dcout.dims[i].name == column)
				break
			end
		end
		new_chart = chart_constructor(dcout.df[column], dcout.groups[i])
		push!(dcout.charts, new_chart)
	else
		throw(NotInferrableError())
	end
end

function clear_charts(dcout::DCOut)
	dcout.charts = DCChart[]
	Union{}
end

"""
	dc(df::DataFrame)

Construct a DC.js visualization based on the columns in the given DataFrame.
"""
dc(df::DataFrame) = DCOut(df)