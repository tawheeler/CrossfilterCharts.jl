

function write_html_head(io::IO)
	print(io, """
	<head>
		<link href="https://cdnjs.cloudflare.com/ajax/libs/dc/1.7.5/dc.css" rel="stylesheet">
		<style>
	    .fake-link {
	      color: blue;
	      text-decoration: underline;
	      cursor: pointer;
	      font-size: 12px;
	    }
	  </style>
	</head>
	""")
end
function write_html_chart_entry(io::IO, chart::DCChart, indent::Int=0)
	tabbing = "  "^indent
	println(io, tabbing, "<div style=\"float:left;\">")
	println(io, tabbing, "  <h3 id=\"heading_", chart.parent, "\">", chart.title, " </h3>")
	println(io, tabbing, "  <div id=\"", chart.parent, "\"></div>")
	println(io, tabbing, "</div>")
end
function write_html_body(io::IO, charts::Vector{DCChart})
	println(io, "<body>")
	for chart in charts
		write_html_chart_entry(io, chart, 1)
	end
	print(io, """
	<div style="float:left;">
    <div id="reset_all_well">&nbsp</div>
  </div>
  """)
	println(io, "</body>")
end
function write_script_dependencies{S<:AbstractString}(io::IO, dependencies::Vector{Tuple{S, S, Bool}})
  print(io, """require.config({paths: {""")
	for i in 1 : length(dependencies)
    #=
		@printf(io, "<script src='%s'></script>\n", src)
    =#
    @printf(io, """ "%s": "%s" """, dependencies[i][1], dependencies[i][2])
    if i < length(dependencies)
      print(io, ",\n")
    end
	end
  print(io, """}});\n""")
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
function write_reset_script(io::IO, dcout::DCOut)
	print(io, "var charts = [")
	for i in 1 : length(dcout.charts)
		print(io, dcout.charts[i].parent)
		if i < length(dcout.charts)
			print(io, ", ")
		end
	end
	println(io, "];")
	print(io, "var chart_names = [")
	for i in 1 : length(dcout.charts)
		print(io, "\"", dcout.charts[i].parent, "\"")
		if i < length(dcout.charts)
			print(io, ", ")
		end
	end
	println(io, "];")
	print(io, """
var update_reset_buttons = function(chart) {
  var filter_in_use = false;
  for (var i = 0; i < charts.length; i++) {
    if (charts[i].filters().length > 0) {
      filter_in_use = true;
      break;
    }
  }
  var idx = charts.indexOf(chart);
  d3.select("#reset_all_btn").remove();
  d3.select("#heading_" + chart_names[idx]).select(".chart-reset").remove();
  if (filter_in_use) {
    d3.select("#reset_all_well")
      .append("button")
      .attr("type", "button")
      .attr("id", "reset_all_btn")
      .append("div")
      .attr("class", "label")
      .text(function(d) {
        return "Reset All";
      })
      .on("click", function() {
        for (var i = 0; i < charts.length; i++) {
          charts[i].filter(null);
        }
        dc.redrawAll();
      });
    if (chart.filters().length > 0) {
      d3.select("#heading_" + chart_names[idx])
        .append("span")
        .attr("class", "chart-reset fake-link")
        .text(function(d) {
          return "Reset";
        })
        .on("click", function(d) {
          chart.filter(null);
          dc.redrawAll();
        });
    }
  }
};

for (var i = 0; i < charts.length; i++) {
  charts[i].on('filtered', function(chart) {
    update_reset_buttons(chart);
  });
}
	""")
end
function quote_corrector() # doesn't actually do anything, just corrects quotes on sublime
	x = """
	a"c
	"""
end
function write_script{S<:AbstractString}(io::IO, dcout::DCOut, dependencies::Vector{Tuple{S, S, Bool}})
	println(io, """<script type="text/javascript">""")
  
  write_script_dependencies(io, dependencies)
  print(io, "require([")
  for i in 1 : length(dependencies)
    print(io, "\"", dependencies[i][1], "\"")
    if i < length(dependencies)
      print(io, ", ")
    end
  end
  print(io, "], function(")
  unused_counter = 1;
  for i in 1 : length(dependencies)
    if (dependencies[i][3])
      print(io, dependencies[i][1])
    else
      print(io, "unused", unused_counter)
      unused_counter += 1
    end
    if i < length(dependencies)
      print(io, ", ")
    end
  end
  print(io, ") {\n")
  #=
  print(io, """require.config({paths: {"_": "https://cdnjs.cloudflare.com/ajax/libs/underscore.js/1.8.3/underscore-min" ,
 "d3": "https://cdnjs.cloudflare.com/ajax/libs/d3/3.5.17/d3.min" ,
 "crossfilter": "https://cdnjs.cloudflare.com/ajax/libs/crossfilter/1.3.7/crossfilter" ,
 "dc": "https://cdnjs.cloudflare.com/ajax/libs/dc/1.7.1/dc" }});

require(["_", "d3", "crossfilter", "dc"], function(_, d3, _unused, dc) {""")
  =#
	write_data(io, dcout.df)

	# crossfilter
	println(io, "var cf = crossfilter(data);")

	# dimensions
	for dim in dcout.dims
		write(io, dim)
		print(io, "\n")
	end

	# groups
	for group in dcout.groups
		write(io, group)
		print(io, "\n")
	end

	# # unique name extraction (TODO: get rid of underscore.js)
	# for (dim, name) in enumerate(names(dcout.df))
	# 	if eltype(df[dim]) <: AbstractString
	# 		println(io, "window.", name, "_names = _.chain(data).pluck(\"", name, "\").uniq().value();")
	# 	end
	# end

	# charts
	for chart in dcout.charts
		write(io, chart, 1)
	end

	println(io, "dc.renderAll();")

	write_reset_script(io, dcout)

	println(io, "});
</script>")
end
function write_source_html(io::IO, dcout::DCOut)
	write_html_head(io)
	write_html_body(io, dcout.charts)
  # Note: dependencies must be ordered! (hence why this is not a dictionary)
  dependencies = [("_","https://cdnjs.cloudflare.com/ajax/libs/underscore.js/1.8.3/underscore-min", true),
                  ("d3","https://cdnjs.cloudflare.com/ajax/libs/d3/3.5.17/d3.min", true),
                  ("crossfilter","https://cdnjs.cloudflare.com/ajax/libs/crossfilter/1.3.7/crossfilter", false),
                  ("dc","https://cdnjs.cloudflare.com/ajax/libs/dc/1.7.1/dc", true)]
	write_script(io, dcout, dependencies)
end

function Base.writemime(io::IO, ::MIME"text/html", dcout::DCOut)


	# If IJulia is present, go for it
	if isdefined(Main, :IJulia)
		#=
		1 - determine chart layout
		2 - generate iframe html + js page
		3 - write link to it
		=#
		iframe_name = @sprintf("dc%s.htm", Dates.format(now(), "yyyymmdd_HHMMSS"))
    #=
		fout = open(iframe_name, "w")
		write_source_html(fout, dcout)
		close(fout)
		write(io, """<iframe src="$iframe_name" width="975" height="550"></iframe>""")
    =#
    write(io, """<div style="width:900px; height: 500px;">""")
    write_source_html(io, dcout)
    write(io, """</div>""")
	else
		# TODO
		# decide what to do in the absence of IJulia
	end
end