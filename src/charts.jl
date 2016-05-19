type Attribute{T}
	name::Symbol
	value::Nullable{T}
	Attribute(name::Symbol) = new(name, Nullable{T}())
end
function Base.deepcopy{T}(a::Attribute{T})
	retval = Attribute{T}(a.name)
	if !isnull(a.value)
		retval.value = deepcopy(a.value)
	end
	retval
end
const NULL_ATTRIBUTE = Attribute{Void}(:NULL)

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
function Base.setindex!(chart_type::ChartType, v::Any, s::Symbol)
	for a in chart_type.attributes
		if a.name == s
			@assert(isa(v, eltype(a.value)))
			a.value = Nullable(v)
			return
		end
	end

	for ancestor in chart_type.ancestors
		a = ancestor[s]
		if a.name != :NULL
			@assert(isa(v, eltype(a.value)))
			a.value = Nullable(v)
			return
		end
	end
end

const BaseChart = ChartType([Attribute{Float64}(:width), Attribute{Float64}(:height)])
const ColorChart = ChartType([Attribute{ASCIIString}(:colors), Attribute{ASCIIString}(:colorAccessor), Attribute{Int}(:colorDomain)])
const CoordinateGridChart = ChartType([Attribute{Tuple{Float64,Float64}}(:zoomScale),
	                             Attribute{Bool}(:zoomOutRestrict), Attribute{Bool}(:mouseZoomable),
	                             Attribute{ASCIIString}(:x), Attribute{ASCIIString}(:xUnits),
	                             Attribute{ASCIIString}(:xAxis), Attribute{Bool}(:elasticX),
	                             Attribute{ASCIIString}(:xAxisPadding), Attribute{Float64}(:y),
	                             Attribute{ASCIIString}(:yAxis), Attribute{Float64}(:elasticY),
	                             Attribute{Bool}(:renderHorizontalGridLines), Attribute{Bool}(:renderVerticalGridLines),
	                             Attribute{Union{Int,ASCIIString}}(:yAxisPadding), Attribute{ASCIIString}(:round)],
								[BaseChart, ColorChart])
# StackableChart = ChartType(false, [Attribute{}])

const PieChart = ChartType("pieChart",
	                 [Attribute{Int}(:slicesCap), Attribute{Float64}(:innerRadius),
	                  Attribute{Float64}(:radius), Attribute{Float64}(:cx),
	                  Attribute{Float64}(:cy), Attribute{Float64}(:minAngleForLabel)],
	                 [ColorChart, BaseChart])
const BarChart = ChartType("barChart",
					 [Attribute{Bool}(:centerBar), Attribute{Float64}(:gap)],
	                 ChartType[CoordinateGridChart]) # StackableChart
const LineChart = ChartType("lineChart",
	                  [Attribute{Bool}(:renderArea), Attribute{Float64}(:dotRadius)],
					  ChartType[CoordinateGridChart]) # StackableChart

can_infer_chart(arr::AbstractDataArray) = false
can_infer_chart{I<:Integer}(arr::AbstractDataArray{I}) = true
can_infer_chart{F<:AbstractFloat}(arr::AbstractDataArray{F}) = true
# can_infer_chart{S<:AbstractString}(arr::DataArray{S}) = true

infer_chart{I<:Integer}(arr::AbstractDataArray{I}, group) = barchart(arr, group)
infer_chart{F<:AbstractFloat}(arr::AbstractDataArray{F}, group) = barchart(arr, group)
# infer_chart{S<:AbstractString}(arr::DataArray{S}) = piechart(arr)

function barchart{I<:Integer}(arr::DataArray{I}, group::Group)
	chart = deepcopy(BarChart)
	chart[:width] = 250.0
	chart[:height] = 200.0
	chart[:x] = @sprintf("d3.scale.linear().domain([%d,%d])",
					     floor(Int, minimum(arr)),
					     ceil(Int, maximum(arr)))
	chart[:xUnits] = "dc.units.fp.precision(.0)"
	chart
end
function barchart{F<:AbstractFloat}(arr::DataArray{F}, group::Group)
	chart = deepcopy(BarChart)
	chart[:width] = 250.0
	chart[:height] = 200.0
	chart[:centerBar] = true
	chart[:x] = @sprintf("d3.scale.linear().domain([%d,%d])",
					     floor(Int, minimum(arr)),
					     ceil(Int, maximum(arr)))
	chart[:xUnits] = "dc.units.fp.precision(.5)"
	chart
end
function piechart{S<:AbstractString}(arr::DataArray{S}, group::Group)
	chart = deepcopy(PieChart)
	chart[:width] = 250.0
	chart[:height] = 200.0
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
		if !isnull(a.value)
			print(io, "\n", tabbing, "  .", string(a.name), "(", get(a.value), ")")
		end
	end
	println(io, ";")
end



#=
AbstractBubbleChart <: ColorChart
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
