type DCOut
	df::DataFrame
	dims::Vector{Dimension}
	groups::Vector{Group}
	charts::Vector{DCChart}
	widgets::Vector{DCWidget}
	output_id::Integer

	function DCOut(df::DataFrame)

		dims = Dimension[]
		groups = Group[]
		charts = DCChart[]
		widgets = DCWidget[]

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

		new(df, dims, groups, charts, widgets, rand(0:999999))
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

function add_widget(dcout::DCOut, widget::DCWidget)
	push!(dcout.widgets, widget)
end

function clear_charts(dcout::DCOut)
	dcout.charts = DCChart[]
	dcout.widgets = DCWidget[]
	Union{}
end

function randomize_ids(dcout::DCOut)
	dcout.output_id = rand(0:999999)

  for chart in dcout.charts
    randomize_parent(chart)
  end
  for widget in dcout.widgets
    randomize_parent(widget)
  end
end

"""
	dc(df::DataFrame)

Construct a DC.js visualization based on the columns in the given DataFrame.
"""
dc(df::DataFrame) = DCOut(df)