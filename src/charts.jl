type Attribute
	name::Symbol
	value::ASCIIString
	Attribute(name::Symbol) = new(name, "")
end
const NULL_ATTRIBUTE = Attribute(:NULL)

type ChartType
	concreteName::ASCIIString
	attributes::Vector{Attribute}
	ancestors::Vector{ChartType}
	ChartType{A<:Attribute}(attributes::Vector{A}, ancestors::Vector{ChartType}=ChartType[]) = new("NONE", convert(Vector{Attribute}, attributes), ancestors)
	ChartType{A<:Attribute}(concreteName::ASCIIString, attributes::Vector{A}, ancestors::Vector{ChartType}=ChartType[]) = new(concreteName, convert(Vector{Attribute}, attributes), ancestors)
end
function Base.deepcopy(chart_type::ChartType)
	name = chart_type.concreteName
	attributes = Array(Attribute, length(chart_type.attributes))
	for (i,a) in enumerate(chart_type.attributes)
		attributes[i] = deepcopy(a)
	end
	ancestors = Array(ChartType, length(chart_type.ancestors))
	for (i,ancestor) in enumerate(chart_type.ancestors)
		ancestors[i] = deepcopy(ancestor)
	end
	ChartType(name, attributes, ancestors)
end
function get_all_attributes(chart_type::ChartType)
	retval = Attribute[]
	for ancestor in chart_type.ancestors
		append!(retval, get_all_attributes(ancestor))
	end
	append!(retval, chart_type.attributes)
	retval
end
function Base.getindex(chart_type::ChartType, s::Symbol)
	for a in chart_type.attributes
		if a.name == s
			return a
		end
	end

	for ancestor in chart_type.ancestors
		a = ancestor[s]
		if a.name != :NULL
			return a
		end
	end

	NULL_ATTRIBUTE
end
function Base.setindex!(chart_type::ChartType, v::ASCIIString, s::Symbol)
	for a in chart_type.attributes
		if a.name == s
			a.value = v
			return
		end
	end

	for ancestor in chart_type.ancestors
		a = ancestor[s]
		if a.name != :NULL
			a.value = v
			return
		end
	end
end

const BaseChart = ChartType([Attribute(:width), Attribute(:height)])
const ColorChart = ChartType([Attribute(:colors), Attribute(:colorAccessor), Attribute(:colorDomain)])
const CoordinateGridChart = ChartType([Attribute(:zoomScale),
	                             Attribute(:zoomOutRestrict), Attribute(:mouseZoomable),
	                             Attribute(:x), Attribute(:xUnits),
	                             Attribute(:xAxis), Attribute(:elasticX),
	                             Attribute(:xAxisPadding), Attribute(:y),
	                             Attribute(:yAxis), Attribute(:elasticY),
	                             Attribute(:renderHorizontalGridLines), Attribute(:renderVerticalGridLines),
	                             Attribute(:yAxisPadding), Attribute(:round),
	                             Attribute(:keyAccessor), Attribute(:valueAccessor)],
								[BaseChart, ColorChart])
const AbstractBubbleChart = ChartType([Attribute(:r), Attribute(:radiusValueAccessor),
										 									 Attribute(:minRadiusWithLabel), Attribute(:maxBubbleRelativeSize)],
										 									[ColorChart])
const WidgetChart = ChartType([Attribute(:dimension), Attribute(:group)])

# StackableChart = ChartType(false, [Attribute{}])

const PieChart = ChartType("pieChart",
	                  [Attribute(:slicesCap), Attribute(:innerRadius),
	                   Attribute(:radius), Attribute(:cx),
	                   Attribute(:cy), Attribute(:minAngleForLabel)],
	                  [ColorChart, BaseChart])
const BarChart = ChartType("barChart",
					 					[Attribute(:centerBar), Attribute(:gap)],
	                  [CoordinateGridChart]) # StackableChart
const LineChart = ChartType("lineChart",
	                  [Attribute(:renderArea), Attribute(:dotRadius)],
					  				[CoordinateGridChart]) # StackableChart
const RowChart = ChartType("rowChart",
										[Attribute(:gap), Attribute(:elasticX),
										 Attribute(:labelOffsetX), Attribute(:labelOffsetY)],
										[ColorChart, BaseChart])
const BubbleChart = ChartType("bubbleChart",
										[Attribute(:elasticRadius)],
										[AbstractBubbleChart, CoordinateGridChart])
const DataCountWidget = ChartType("dataCount",
										Attribute[],
										[WidgetChart])
const DataTableWidget = ChartType("dataTable",
										[Attribute(:size), Attribute(:columns),
										 Attribute(:sortBy), Attribute(:order)],
										[WidgetChart])

# DC Chart
type DCChart
	group::Group
	typ::ChartType
	title::ASCIIString
	parent::ASCIIString

	function DCChart(
		typ::ChartType,
		group::Group;
		title::ASCIIString = "Chart for " * string(group.dim.name),
		parent::ASCIIString = @sprintf("chart_%06d", rand(0:999999)),
		)

		new(group, typ, title, parent)
	end
end

function randomize_parent(chart::DCChart)
	chart.parent = @sprintf("chart_%06d", rand(0:999999))
	Union{}
end

function Base.write(io::IO, chart::DCChart, indent::Int)
	tabbing = "  "^indent
	println(io, tabbing, "var ", chart.parent, " = dc.", chart.typ.concreteName, "(\"\#", chart.parent, "\")") # TODO: add chart grouping
	println(io, tabbing, "  .dimension(", chart.group.dim.name, ")")
	print(io, tabbing, "  .group(", chart.group.name, ")")

	attributes = get_all_attributes(chart.typ)
	for (i,a) in enumerate(attributes)
		if !isempty(a.value)
			print(io, "\n", tabbing, "  .", string(a.name), "(", a.value, ")")
		end
	end
	println(io, ";")
end

# DC Widget
type DCWidget
	typ::ChartType
	parent::ASCIIString
	html::ASCIIString
	columns::Vector{Symbol}
	group_results::Bool

	function DCWidget(
		typ::ChartType,
		columns::Vector{Symbol} = Symbol[],
		group_results::Bool = false,
		html::ASCIIString = "",
		parent::ASCIIString = @sprintf("chart_%06d", rand(0:999999)),
		)

		new(typ, parent, html, columns, group_results)
	end
end

# Inelegant way to handle the two types of widgets. Change if time permits.
function randomize_parent(widget::DCWidget)
	widget.parent = @sprintf("chart_%06d", rand(0:999999))
	if widget.typ.concreteName == "dataCount"
		widget.html = string("<div id=\"", widget.parent, """\"><span class="filter-count"></span> selected out of <span class="total-count"></span> records</div>""")
	elseif widget.typ.concreteName == "dataTable"
		html_str = IOBuffer()
		if !widget.group_results
			write(html_str, "
			<style>
			  #", widget.parent, " .dc-table-group{display:none}
			</style>")
		end
		write(html_str, "
			<table class=\"table table-hover\" id=\"", widget.parent, "\">
			 <thead>
            <tr>")
		for key in widget.columns
    	write(html_str, "<th>", key, "</th>")
   	end
    write(html_str, "</tr>
        </thead>
        </table>")
		widget.html = takebuf_string(html_str)
	end
	Union{}
end

function Base.write(io::IO, chart::DCWidget, indent::Int)
	tabbing = "  "^indent
	print(io, tabbing, "var ", chart.parent, " = dc.", chart.typ.concreteName, "(\"\#", chart.parent, "\")") # TODO: add chart grouping

	attributes = get_all_attributes(chart.typ)
	for (i,a) in enumerate(attributes)
		if !isempty(a.value)
			print(io, "\n", tabbing, "  .", string(a.name), "(", a.value, ")")
		end
	end
	println(io, ";")
end

"""
	can_infer_chart(arr::AbstractDataArray)

Whether chart inference is supported for the given array type.
"""
can_infer_chart(arr::AbstractDataArray) = false
can_infer_chart{I<:Integer}(arr::AbstractDataArray{I}) = true
can_infer_chart{F<:AbstractFloat}(arr::AbstractDataArray{F}) = true
can_infer_chart{S<:AbstractString}(arr::AbstractDataArray{S}) = true

"""
	infer_chart(arr::AbstractDataArray, group::Group)

Constructs a Chart suitable for the type in arr.
"""
infer_chart{I<:Integer}(arr::AbstractDataArray{I}, group::Group) = barchart(arr, group)
infer_chart{F<:AbstractFloat}(arr::AbstractDataArray{F}, group::Group) = barchart(arr, group)
infer_chart{S<:AbstractString}(arr::AbstractDataArray{S}, group::Group) = piechart(arr, group)

function scale_default{R<:Real}(arr::AbstractDataArray{R})
	@sprintf("d3.scale.linear().domain([%d,%d])",
					     floor(Int, minimum(arr)),
					     ceil(Int, maximum(arr)))
end
function size_default!(chart::ChartType)
	chart[:width] = "300.0"
	chart[:height] = "225.0"
end

"""
	barchart

Infer construction of a DC barchart based on the given group.
"""
function barchart{I<:Integer}(arr::AbstractDataArray{I}, group::Group)
	chart = deepcopy(BarChart)
	size_default!(chart)
	chart[:x] = scale_default(arr)
	chart[:xUnits] = "dc.units.fp.precision(.0)"
	DCChart(chart, group)
end
function barchart{F<:AbstractFloat}(arr::AbstractDataArray{F}, group::Group)
	chart = deepcopy(BarChart)
	size_default!(chart)
	chart[:centerBar] = "true"
	chart[:x] = scale_default(arr)
	chart[:xUnits] = "dc.units.fp.precision($(group.dim.bin_width))"
	DCChart(chart, group)
end

"""
	piechart

Infer construction of a DC piechart based on the given group.
"""
function piechart{S<:AbstractString}(arr::AbstractDataArray{S}, group::Group)
	chart = deepcopy(PieChart)
	size_default!(chart)
	chart[:radius] = string(parse(Float64, chart[:height].value)*0.4)
	chart[:slicesCap] = "10"
	DCChart(chart, group)
end
function piechart{I<:Integer}(arr::AbstractDataArray{I}, group::Group)
	chart = deepcopy(PieChart)
	size_default!(chart)
	DCChart(chart, group)
end

"""
	linechart

Infer construction of a DC linechart based on the given group.
"""
# TODO: Use different xUnits on Float and Int
function linechart{R<:Real}(arr::AbstractDataArray{R}, group::Group)
	chart = deepcopy(LineChart)
	size_default!(chart)
	chart[:x] = scale_default(arr)
	DCChart(chart, group)
end

"""
	bubblechart

Construct an empty custom DC bubblechart.
"""
function bubblechart(group::Group)
	chart = deepcopy(BubbleChart)
	size_default!(chart)
	DCChart(chart, group)
end
function _generate_accessor(col::Symbol)
	if col == :DCCount
		return "function (d) { return d.value.DCCount;}"
	else
		return string("function (d) { return d.value.", col, "_sum;}")
	end
end
function bubblechart(group::Group, x_col::Symbol, y_col::Symbol, r_col::Symbol, df::DataFrame)
	chart = deepcopy(BubbleChart)
	size_default!(chart)
	chart[:width] = string(parse(Float64, chart[:width].value) * 2)
	chart[:x] = "d3.scale.linear().domain([0,150])"
	chart[:elasticX] = "true"
	chart[:elasticY] = "true"
	chart[:elasticRadius] = "true"
	chart[:xAxisPadding] = "100"
	chart[:yAxisPadding] = "100"
	chart[:keyAccessor] = _generate_accessor(x_col)
	chart[:valueAccessor] = _generate_accessor(y_col)
	chart[:radiusValueAccessor] = _generate_accessor(r_col)
	DCChart(chart, group)
end

"""
	rowchart

Infer construction of a DC rowchart based on the given group.
"""
function rowchart{S<:AbstractString}(arr::AbstractDataArray{S}, group::Group)
	chart = deepcopy(RowChart)
	size_default!(chart)
	DCChart(chart, group)
end
function rowchart{I<:Integer}(arr::AbstractDataArray{I}, group::Group)
	chart = deepcopy(RowChart)
	size_default!(chart)
	DCChart(chart, group)
end

"""
	datacountwidget

Construct a DC DataCountWidget.
"""
function datacountwidget()
	chart = deepcopy(DataCountWidget)
	chart[:dimension] = "cf"
	chart[:group] = "all"
	dcwidget = DCWidget(chart)
	randomize_parent(dcwidget)
	dcwidget
end

"""
	datatablewidget

Construct a DC DataTableWidget.
"""
function datatablewidget(col::Symbol, columns::Vector{Symbol}, group_results::Bool=false)
	chart = deepcopy(DataTableWidget)
	chart[:dimension] = string(col)
	if group_results
		chart[:group] = string("function(d) {return d.", col, ";}")
	else
		chart[:group] = """function(d) {return "Showing All Results";}"""
	end
	col_str = IOBuffer()
	print(col_str, "[\n")
	for key in columns
		print(col_str, "function(d) {return d.", key, ";},\n")
  end
  print(col_str, "]")
  chart[:columns] = takebuf_string(col_str)
  chart[:size] = "15"
  dcwidget = DCWidget(chart, columns, group_results)
  randomize_parent(dcwidget)
  dcwidget
end
function datatablewidget(columns::Vector{Symbol})
	datatablewidget(columns[1], columns, false)
end

#=
# Chart types
DataCountWidget <: BaseChart
DataTableWidget <: BaseChart
BubbleChart <: AbstractBubbleChart, CoordinateGridChart
CompositeChart <: CoordinateGridChart
GeoCloroplethChart <: ColorChart, BaseChart
BubbleOverlayChart <: AbstractBubbleChart, BaseChart
RowChart <: ColorChart, BaseChart
Legend
NumberDisplay <: BaseChart
=#
