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
	                             Attribute(:yAxisPadding), Attribute(:round)],
								[BaseChart, ColorChart])
const AbstractBubbleChart = ChartType([Attribute(:r), Attribute(:radiusValueAccessor),
										 									 Attribute(:minRadiusWithLabel), Attribute(:maxBubbleRelativeSize)],
										 									[ColorChart])

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
const DataTableWidget = ChartType("dataTable",
									 [Attribute(:size), Attribute(:columns),
									  Attribute(:sortBy), Attribute(:order)],
									 [BaseChart])

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

function scale_default{F<:AbstractFloat}(arr::AbstractDataArray{F})
	@sprintf("d3.scale.linear().domain([%d,%d])",
					     floor(Int, minimum(arr)),
					     ceil(Int, maximum(arr)))
end
function scale_default{I<:Integer}(arr::AbstractDataArray{I})
	@sprintf("d3.scale.linear().domain([%d,%d])",
					     floor(Int, minimum(arr)),
					     ceil(Int, maximum(arr)))
end
function size_default!(chart::ChartType)
	chart[:width] = "250.0"
	chart[:height] = "200.0"
end

function barchart{I<:Integer}(arr::AbstractDataArray{I}, group::Group)
	chart = deepcopy(BarChart)
	size_default!(chart)
	chart[:x] = scale_default(arr)
	chart[:xUnits] = "dc.units.fp.precision(.0)"
	chart
end
function barchart{F<:AbstractFloat}(arr::AbstractDataArray{F}, group::Group)
	chart = deepcopy(BarChart)
	size_default!(chart)
	chart[:centerBar] = "true"
	chart[:x] = scale_default(arr)
	chart[:xUnits] = "dc.units.fp.precision(.1)"
	chart
end
function piechart{S<:AbstractString}(arr::AbstractDataArray{S}, group::Group)
	chart = deepcopy(PieChart)
	size_default!(chart)
	chart
end
function piechart{I<:Integer}(arr::AbstractDataArray{I}, group::Group)
	chart = deepcopy(PieChart)
	size_default!(chart)
	chart
end
function linechart{F<:AbstractFloat}(arr::AbstractDataArray{F}, group::Group)
	chart = deepcopy(LineChart)
	size_default!(chart)
	chart[:x] = scale_default(arr)
	chart
end
function linechart{I<:Integer}(arr::AbstractDataArray{I}, group::Group)
	chart = deepcopy(LineChart)
	size_default!(chart)
	chart[:x] = scale_default(arr)
	chart
end

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



#=
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
