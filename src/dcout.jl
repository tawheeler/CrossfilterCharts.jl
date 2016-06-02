type DCOut
	df::DataFrame
	dims::Vector{Dimension}
	groups::Vector{Group}
	charts::Vector{DCChart}
	widgets::Vector{DCWidget}
	output_id::Integer

	function DCOut(df::DataFrame)
		retval = new()
		retval.df = df
		retval.dims = Dimension[]
		retval.groups = Group[]
		retval.charts = DCChart[]
		retval.widgets = DCWidget[]
		retval.output_id = rand(0:999999)
		retval
	end
end

type NotInferrableError <: Exception end

"""
	quick_add!

A utility function for quickly building a chart and adding it.
Works with linechart, barchart, rowchart, piechart.
Requires previously a constructed group.
"""
function quick_add!(dcout::DCOut, column::Symbol, chart_constructor::Function)
	if can_infer_chart(dcout.df[column])
		i = findfirst(group->group.dim.name == column, dcout.groups)
		new_chart = chart_constructor(dcout.df[column], dcout.groups[i])
		push!(dcout.charts, new_chart)
	else
		throw(NotInferrableError())
	end
end

"""
	add_dimension!

Append the Dimension to the list of dimensions in the DCOut object.
"""
function add_dimension!(dcout::DCOut, dim::Dimension)
	push!(dcout.dims, dim)
	dcout
end

"""
	add_chart!

Append the DCChart to the list of charts in the DCOut object.
"""
function add_chart!(dcout::DCOut, chart::DCChart)
	push!(dcout.charts, chart)
	dcout
end

"""
	add_widget!

Append the DCWidget to the list of widgets in the DCOut object.
"""
function add_widget!(dcout::DCOut, widget::DCWidget)
	push!(dcout.widgets, widget)
	dcout
end

"""
	add_group!

Append the Group to the list of groups in the DCOut object.
"""
function add_group!(dcout::DCOut, group::Group)
	push!(dcout.groups, group)
	dcout
end

"""
	add_datacountwidget!

Construct and append a Data Count Widget to the DCOut object.
"""
function add_datacountwidget!(dcout::DCOut)
	add_widget!(dcout, datacountwidget())
	dcout
end

"""
	add_datatablewidget!

Construct and append a Data Table Widget to the DCOut object.
"""
function add_datatablewidget!(dcout::DCOut)
	columns = Symbol[]
	for dim in dcout.dims
		push!(columns, dim.name)
	end
	add_widget!(dcout, datatablewidget(columns))
	dcout
end


"""
	clear_charts!

Remove all charts from the DCOut object.
"""
function clear_charts!(dcout::DCOut)
	dcout.charts = DCChart[]
	dcout.widgets = DCWidget[]
	Union{}
end

"""
	randomize_ids!

Randomly re-initialize all dcout random ids.
These are used when exporting to HTML to prevent charts from
referencing one another across IJulia cells.
"""
function randomize_ids!(dcout::DCOut)
	dcout.output_id = rand(0:999999)

  for chart in dcout.charts
    randomize_parent(chart)
  end
  for widget in dcout.widgets
    randomize_parent(widget)
  end
end

"""
	infer_dimensions!

Infer a dimension for each column in the DCOut DataFrame
"""
function infer_dimensions!(dcout::DCOut)
	for name in names(dcout.df)
		arr = dcout.df[name]
		if can_infer_chart(arr)
			dim = infer_dimension(arr, name)
			add_dimension!(dcout, dim)
		end
	end
	dcout
end

"""
	infer_groups!

Infer a group for each dimension in the DCOut DataFrame
"""
function infer_groups!(dcout::DCOut)
	for dim in dcout.dims
		arr = dcout.df[dim.name]
		if can_infer_chart(arr)
			group = infer_group(arr, dim)
			add_group!(dcout, group)
		end
	end
	dcout
end

"""
	dc(df::DataFrame)

Construct a DC.js visualization based on the columns in the given DataFrame.
This is the easiest and most straightforward way to use DC.jl.
"""
function dc(df::DataFrame)
	dcout = DCOut(df)

	for name in names(dcout.df)
		arr = dcout.df[name]
		if can_infer_chart(arr)
			dim = infer_dimension(arr, name)
			add_dimension!(dcout, dim)

			group = infer_group(arr, dim)
			add_group!(dcout, group)

			chart = infer_chart(arr, group)
			add_chart!(dcout, chart)
		end
	end

	dcout
end