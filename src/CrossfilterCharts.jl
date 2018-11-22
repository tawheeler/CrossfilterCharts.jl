__precompile__(true)

module CrossfilterCharts

using DataFrames
using Printf

export
	dc,

	DCOut,
	DCChart,

	BaseChart,
	ColorChart,
	CoordinateGridChart,
	PieChart,
	BarChart,
	LineChart,

	rowchart,
	barchart,
	piechart,
	linechart,
	bubblechart,
	datacountwidget,
	datatablewidget,

	get_group_by_name,
	get_groups_by_col,
	get_dim_by_col,
	get_charts,

	add_chart!,
	add_widget!,
	add_group!,
	add_datacountwidget!,
	add_datatablewidget!,
	add_bubblechart!,

	remove_group!,
	remove_chart!,

	quick_add!,
	clear_charts!,
	clear_widgets!,
	set_elastic_height!,
	randomize_ids!,

	reduce_count,
	reduce_sum,
	reduce_master,
	can_infer_chart,
	infer_dimension,
	infer_group,
	infer_chart,

	infer_dimensions!,
	infer_groups!

include("dimensions.jl")
include("groups.jl")
include("charts.jl")
include("dcout.jl")
include("io.jl")

end # module
