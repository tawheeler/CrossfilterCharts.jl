# module DC

using DataFrames
import Base.writemime

type DCChart
	title::ASCIIString
	dim::Int # dimension; column in DCOut.df
	id::ASCIIString
	DCChart(title::ASCIIString, dim::Int) = new(title, dim, "chart_"*randstring(6))
end
type DCOut
	df::DataFrame
	charts::Vector{DCChart}

	function DCOut(df::DataFrame)
		charts = Array(DCChart, ncol(df))
		for (dim,name) in enumerate(names(df))
			title = "Chart for " * string(name)
			charts[dim] = DCChart(title, dim)
		end
		new(df, charts)
	end
end

function write_html_head(io::IO)
	print(io, """
	<head>
		<link href="https://cdnjs.cloudflare.com/ajax/libs/dc/1.7.5/dc.css" rel="stylesheet">
	</head>
	""")
end
function write_html_chart_entry(io::IO, chart::DCChart, indent::Int=0)
	tabbing = "  "^indent
	println(io, tabbing, "<div style=\"float:left;\">")
	println(io, tabbing, "  <h3>", chart.title, "</h3>")
	println(io, tabbing, "  <div id=\"", chart.id, "\"></div>")
	println(io, tabbing, "</div>")
end
function write_html_body(io::IO, charts::Vector{DCChart})
	println(io, "<body>")
	for chart in charts
		write_html_chart_entry(io, chart, 1)
	end
	println(io, "</body>")
end
function write_script_dependencies{S<:AbstractString}(io::IO, dependencies::Vector{S})
	for src in dependencies
		@printf(io, "<script src='%s'></script>\n", src)
	end
end
function write_json_entry(io, names::Vector{Symbol}, values::Vector{Any})
	print(io, "{")
	for i in 1 : length(names)
		print(io, "\"", names[i], "\": ")
		v = values[i]
		if isa(v, AbstractString)
			print(io, "\"", v, "\"")
		else
			print(io, v)
		end
		if i < length(names)
			print(io, ", ")
		end
	end
	print(io, "}")
end
function write_data(io::IO, df::DataFrame)
	colnames = names(df)
	values = Array(Any, ncol(df))
	print(io, "data = [")
	for i in 1:nrow(df)
		for j in 1:ncol(df)
			values[j] = df[i,j]
		end
		write_json_entry(io, colnames, values)
		if i < nrow(df)
			print(io, ",")
		end
	end
	println(io, "];")
end
function write_script(io::IO, dcout::DCOut)
	println(io, """<script type="text/javascript">""")
	write_data(io, dcout.df)
	
	# crossfilter
	println(io, "var cf = crossfilter(data);")

	# dimensions
	for (dim, name) in enumerate(names(dcout.df))
		print(io, "var ", name, " = cf.dimension(function(d){")
		if eltype(df[dim]) <: Real
			print(io, "return Math.round(d.", name, " * 2)/2;")
		else
			print(io, "return d.", name, ";")
		end
		println(io, "});")
	end

	# groups
	for (dim, name) in enumerate(names(dcout.df))
		print(io, "var ", name, "_sum = ", name, ".group().")
		if eltype(df[dim]) <: Real
			println(io, "reduceSum(function(d){ return d.", name, "; });")
		else
			println(io, "reduceCount();")
		end
	end

	# unique name extraction (TODO: get rid of underscore.js)
	for (dim, name) in enumerate(names(dcout.df))
		if eltype(df[dim]) <: AbstractString
			print(io, "window.", name, "_names = _.chain(data).pluck(\"", name, "\").uniq().value();")
		end
	end

	# charts
	colnames = names(dcout.df)
	for chart in dcout.charts
		name = colnames[chart.dim]
		println(io, "var ", chart.id, " = dc")
		if eltype(df[chart.dim]) <: Real
			println(io, ".barChart(\"#", chart.id, "\")")
			println(io, "  .width(250)")
			println(io, "  .height(200)")
			println(io, "  .dimension(", name, ")")
			println(io, "  .group(", name, "_sum)")
			println(io, "  .centerBar(true)")
			@printf(io, "  .x( d3.scale.linear().domain([%d,%d]))\n", floor(Int, minimum(dcout.df[chart.dim])), ceil(Int, maximum(dcout.df[chart.dim])))
			println(io, "  .xUnits(dc.units.fp.precision(.5));")
		else
			println(io, ".barChart(\"#", chart.id, "\")")
			println(io, "  .width(250)")
			println(io, "  .height(200)")
			println(io, "  .dimension(", name, ")")
			println(io, "  .group(", name, "_sum)")
			println(io, "  .centerBar(true)")
			println(io, "  .x(d3.scale.ordinal().domain(", name, "_names))")
			println(io, "  .xUnits(dc.units.ordinal);")
		end
	end

	println(io, "dc.renderAll();")

	println(io, "</script>")
end
function write_source_html(io::IO, dcout::DCOut)
	write_html_head(io)
	write_html_body(io, dcout.charts)
	write_script_dependencies(io, ["https://cdnjs.cloudflare.com/ajax/libs/underscore.js/1.8.3/underscore-min.js", 
								   "https://cdnjs.cloudflare.com/ajax/libs/d3/3.5.17/d3.min.js",
								   "https://cdnjs.cloudflare.com/ajax/libs/crossfilter/1.3.7/crossfilter.js",
								   "https://cdnjs.cloudflare.com/ajax/libs/dc/1.7.1/dc.js"])
	write_script(io, dcout)
end

function writemime(io::IO, ::MIME"text/html", dcout::DCOut)
	

	# If IJulia is present, go for it
	if isdefined(Main, :IJulia)
		#=
		1 - determine chart layout
		2 - generate iframe html + js page
		3 - write link to it
		=#
		fout = open("test.htm", "w")
		write_source_html(fout, dcout)
		close(fout)
		write(io, """<iframe src="test.htm" width="975" height="500"></iframe>""")
	else
		# TODO
		# decide what to do in the absence of IJulia
	end
end

function generate_test_df(nrows::Int)
	df = DataFrame()
	df[:a] = Array(Int, nrows)
	df[:b] = Array(Float64, nrows)
	df[:c] = Array(ASCIIString, nrows)

	for i in 1 : nrows
		df[:a][i] = rand(1:4)
		df[:b][i] = df[:a][i] + randn()
		if df[:b][i] > 2.0
			df[:c][i] = rand() > 0.5 ? "a" : "b"
		else
			df[:c][i] = rand() > 0.3 ? "c" : "d"
		end
	end
	df
end

# end # module

# <link href="https://cdnjs.cloudflare.com/ajax/libs/dc/1.7.5/dc.css" rel="stylesheet">