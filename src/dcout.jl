type DCOut
	df::DataFrame
	dims::Vector{Dimension}
	groups::Vector{Group}
	charts::Vector{DCChart}
	widgets::Vector{DCWidget}
	output_id::Integer
	elastic_height::Bool
	html_debug::Bool

	function DCOut(df::DataFrame)
		retval = new()
		retval.df = df
		retval.dims = Dimension[]
		retval.groups = Group[]
		retval.charts = DCChart[]
		retval.widgets = DCWidget[]
		retval.output_id = rand(0:999999)
		retval.elastic_height = false
		retval.html_debug = false
		retval
	end
end

"""
	get_group_by_name

Returns the group inside the given DCCout instance with the given name.
"""
function get_group_by_name(dcout::DCOut, name::String)
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
	get_group_by_name

Returns the dimension inside the given DCCout instance created from the given column.
"""
function get_dim_by_col(dcout::DCOut, col::Symbol)
	results = find(x -> x.name == col, dcout.dims)
	if length(results) == 0
		error("dimension from column \"", col, "\" not found")
	elseif length(results) == 1
		return dcout.dims[results[1]]
	else
		error("dcout in invalid state: two dimensions have the same name")
	end
end

"""
	get_charts

Returns all charts constructed from the given column of the given type.
`chart_type` can be: piechart, barchart, linechart, rowchart, bubblechart
"""
function get_charts(dcout::DCOut, col::Symbol, chart_type::String)
	idxs = find(x -> (x.group.dim.name == col && uppercase(chart_type) == uppercase(x.typ.concreteName)), dcout.charts)
	result = DCChart[]
	for idx in idxs
		push!(result, dcout.charts[idx])
	end
	result
end

"""
	add_dimension!

Append the Dimension to the list of dimensions in the DCOut object.
"""
function add_dimension!(dcout::DCOut, dim::Dimension)
	if findfirst(x -> x.name == dim.name, dcout.dims) > 0
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
	remove_group!

Removes the given Group from the list of groups in the DCOut object.
"""
function remove_group!(dcout::DCOut, group::Group)
	targets = find(x -> x.name == group.name, dcout.groups)
	if length(targets) == 0
		error("group \"", group.name, "\" does not exist")
	elseif length(targets) > 1
		# This case should technically not happen, but if it is the case,
		# we remove all groups that match `group`
		deleteat!(dcout.groups, targets[1])
		remove_group!(dcout, group)
	else
		deleteat!(dcout.groups, targets[1])
	end
	dcout
end

"""
	remove_chart!

Removes the given DCChart from the list of charts in the DCOut object.
"""
function remove_chart!(dcout::DCOut, chart::DCChart)
	targets = find(x -> x.parent == chart.parent, dcout.charts)
	if length(targets) == 0
		error("chart \"", chart.parent, "\" does not exist")
	elseif length(targets) > 1
		deleteat!(dcout.charts, targets[1])
		remove_group!(dcout, group)
	else
		deleteat!(dcout.charts, targets[1])
	end
	dcout
end

"""
	quick_add!

A utility function for quickly building a chart and adding it.
Works with linechart, barchart, rowchart, piechart.
Requires previously a constructed group.
"""
function quick_add!(dcout::DCOut, group::Group, chart_constructor::Function)
	new_chart = chart_constructor(dcout.df[group.dim.name], group)
	add_chart!(dcout, new_chart)
end
"""
	quick_add!

Quickly build a chart using the group constructed from `column`.
If multiple groups are found, an error is thrown unless `use_first`
is set, in which case the first group found is used.
"""
function quick_add!(dcout::DCOut, column::Symbol, chart_constructor::Function, use_first::Bool = false)
	groups = get_groups_by_col(dcout, column)
	if length(groups) == 0
		error("group from column \"", column, "\" not found")
	elseif length(groups) > 1
		if use_first
			quick_add!(dcout, groups[1], chart_constructor)
		else
			error("unable to infer group: multiple groups use column \"", column, "\"")
		end
	else
		quick_add!(dcout, groups[1], chart_constructor)
	end
end
"""
	quick_add!

Quickly build a chart using the group with the given name.
"""
function quick_add!(dcout::DCOut, group_name::String, chart_constructor::Function)
	group = get_group_by_name(dcout, group_name)
	quick_add!(dcout, group, chart_constructor)
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
	cols = [x_col, y_col, r_col]
	for col in cols
		if col != :DCCount
			get_dim_by_col(dcout, col)
		end
	end
	group = reduce_master(dim, [x_col, y_col, r_col])
	add_group!(dcout, group)
	add_chart!(dcout, bubblechart(group, x_col, y_col, r_col))
	dcout
end
function add_bubblechart!(dcout::DCOut, dim_col::Symbol, x_col::Symbol, y_col::Symbol, r_col::Symbol)
	add_bubblechart!(dcout, get_dim_by_col(dcout, dim_col), x_col, y_col, r_col)
end

"""
	clear_charts!

Remove all charts from the DCOut object.
"""
function clear_charts!(dcout::DCOut)
	dcout.charts = DCChart[]
	dcout
end

"""
	clear_widgets

Remove all widgets from the DCOut object.
"""
function clear_widgets!(dcout::DCOut)
	dcout.widgets = DCWidget[]
	dcout
end

"""
	set_elastic_height!

Changes the elasticity of the output div height. A value of true
indicates that the div will resize to fit all elements without
needing a scrollbar.
"""
function set_elastic_height!(dcout::DCOut, elastic_height::Bool)
	dcout.elastic_height = elastic_height
	dcout
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