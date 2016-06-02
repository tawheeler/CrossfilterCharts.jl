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
	if length(find(x -> x.name == dim.name, dcout.dims)) > 0
		error(string("attempt to add dimension \"", dim.name, "\" failed: a dimension with that name already exists"))
	end
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
	if length(find(x -> x.name == group.name, dcout.groups)) > 0
		error(string("attempt to add group \"", group.name, "\" failed: a group with that name already exists"))
	end
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

Construct and append a Data Table Widget to the DCOut object. Requires
a previously constructed dimension for the first column.
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
	add_bubblechart!

Construct and append a Bubble Chart to the DCOut object. Requires a
previously created dimension. x_col, y_col, and r_col denote the
DataFrame fields whose sums will determine the x position, y position, and
radius of the bubbles in the final chart.

Use `:DCCount` to access the count field.
"""
function add_bubblechart!(dcout::DCOut, dim::Dimension, x_col::Symbol, y_col::Symbol, r_col::Symbol)
	group = reduce_master(dim, [x_col, y_col, r_col])
	try
		add_group!(dcout, group)
	catch
		# Group already exists, no need to add
	end
	add_chart!(dcout, bubblechart(group, x_col, y_col, r_col, dcout.df))
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
	get_group_by_name

Returns the group inside the given DCCout instance with the given name.
"""
function get_group_by_name(dcout::DCOut, name::ASCIIString)
	results = find(x -> x.name == name, dcout.groups)
	if length(results) == 0
		error("group \"", name, "\" not found")
	elseif length(results) == 1
		return dcout.groups[results[1]]
	else
		error("dcout in invalid state: two groups have the same name")
	end
end

"""
	get_groups_by_col

Returns the groups inside the given DCCout instance associated with
the given column.
"""
function get_groups_by_col(dcout::DCOut, col::Symbol)
	idxs = find(x -> x.dim.name == col, dcout.groups)
	result = Group[]
	for idx in idxs
		push!(result, dcout.groups[idx])
	end
	result
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