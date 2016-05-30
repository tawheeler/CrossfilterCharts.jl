VERSION >= v"0.4.0-dev+6521" && __precompile__(true)

module DC

using DataFrames

export
	dc,
	quick_add,
	clear_charts,

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

	reduce_count,
	reduce_sum,
	can_infer_chart,
	infer_dimension,
	infer_group,
	infer_chart

include("dimensions.jl")
include("groups.jl")
include("charts.jl")
include("dcout.jl")
include("io.jl")

end # module