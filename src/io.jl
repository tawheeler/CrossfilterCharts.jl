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
		write_dcchart(io, chart, 1, :a)
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