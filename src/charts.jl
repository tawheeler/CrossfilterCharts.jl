

type Attribute{T}
	name::Symbol
	value::Nullable{T}
	Attribute(name::Symbol) = new(name, Nullable{T}())
end
const NULL_ATTRIBUTE = Attribute{Void}(:NULL)

type ChartType
	concreteName::ASCIIString
	attributes::Vector{Attribute}
	ancestors::Vector{ChartType}
	ChartType{A<:Attribute}(attributes::Vector{A}, ancestors::Vector{ChartType}=ChartType[]) = new("NONE", convert(Vector{Attribute}, attributes), ancestors)
	ChartType{A<:Attribute}(concreteName::ASCIIString, attributes::Vector{A}, ancestors::Vector{ChartType}=ChartType[]) = new(concreteName, convert(Vector{Attribute}, attributes), ancestors)
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

BaseChart = ChartType([Attribute{Float64}(:width), Attribute{Float64}(:height)])
ColorChart = ChartType([Attribute{ASCIIString}(:colors), Attribute{ASCIIString}(:colorAccessor), Attribute{Int}(:colorDomain)])
CoordinateGridChart = ChartType([Attribute{Tuple{Float64,Float64}}(:zoomScale),
	                             Attribute{Bool}(:zoomOutRestrict), Attribute{Bool}(:mouseZoomable),
	                             Attribute{ASCIIString}(:x), Attribute{ASCIIString}(:xUnits),
	                             Attribute{ASCIIString}(:xAxis), Attribute{Bool}(:elasticX),
	                             Attribute{ASCIIString}(:xAxisPadding), Attribute{Float64}(:y),
	                             Attribute{ASCIIString}(:yAxis), Attribute{Float64}(:elasticY),
	                             Attribute{Bool}(:renderHorizontalGridLines), Attribute{Bool}(:renderVerticalGridLines),
	                             Attribute{Union{Int,ASCIIString}}(:yAxisPadding), Attribute{ASCIIString}(:round)],
								[BaseChart, ColorChart])
# StackableChart = ChartType(false, [Attribute{}])

PieChart = ChartType("pieChart",
	                 [Attribute{Int}(:slicesCap), Attribute{Float64}(:innerRadius),
	                  Attribute{Float64}(:radius), Attribute{Float64}(:cx),
	                  Attribute{Float64}(:cy), Attribute{Float64}(:minAngleForLabel)],
	                 [ColorChart, BaseChart])
BarChart = ChartType("barChart",
					 [Attribute{Bool}(:centerBar), Attribute{Float64}(:gap)],
	                 ChartType[CoordinateGridChart]) # StackableChart
LineChart = ChartType("lineChart",
	                  [Attribute{Bool}(:renderArea), Attribute{Float64}(:dotRadius)],
					  ChartType[CoordinateGridChart]) # StackableChart

function infer_chart_type{I<:Integer}(arr::DataArray{I})
	chart = deepcopy(BarChart)
	chart[:width] = 250.0
	chart[:height] = 200.0
	chart
end
function infer_chart_type{R<:AbstractFloat}(arr::DataArray{R})
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
function infer_chart_type{S<:AbstractString}(arr::DataArray{S})
	chart = deepcopy(PieChart)
	chart[:width] = 250.0
	chart[:height] = 200.0
	chart
end

type DCChart
	title::ASCIIString
	dim::Int # dimension; column in DCOut.df
	parent::ASCIIString
	group::ASCIIString
	typ::ChartType

	function DCChart(
		typ::ChartType,
		dim::Int,
		group::ASCIIString,
		title::ASCIIString,
		parent::ASCIIString = "chart_"*randstring(6),
		)
		new(title, dim, parent, group, typ)
	end
end

function write_dcchart(io::IO, chart::DCChart, indent::Int, name::Symbol)
	tabbing = "  "^indent
	println(io, tabbing, "var ", chart.parent, " = dc.", chart.typ.concreteName, "(\#", chart.parent, ")") # TODO: add chart group
	println(io, tabbing, "  .dimension(", name, ")")
	print(io, tabbing, "  .group(", chart.group, ")")

	attributes = get_all_attributes(chart.typ)
	for (i,a) in enumerate(attributes)
		if !isnull(a.value)
			print(io, "\n", tabbing, "  .", string(a.name), "(", get(a.value), ")")
		end
	end
	println(";")
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
