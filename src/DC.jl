VERSION >= v"0.4.0-dev+6521" && __precompile__(true)

module DC

using DataFrames

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
	datacountwidget,
	datatablewidget,

	add_chart!,
	add_widget!,
	add_group!,
	add_datacountwidget!,
	add_datatablewidget!,
	quick_add!,
	clear_charts!,
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