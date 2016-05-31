type Dependency
  name::ASCIIString
  path::ASCIIString
  has_export::Bool
end

function write_html_head(io::IO)
	print(io, """
	<link href="https://cdnjs.cloudflare.com/ajax/libs/dc/1.7.5/dc.css" rel="stylesheet">
	<style>
    .fake-link {
      color: blue;
      text-decoration: underline;
      cursor: pointer;
      font-size: 12px;
    }
    .button-label {
      cursor: pointer;
      margin-right: 20px;
    }
  	</style>
	""")
end

function write_html_chart_entry(io::IO, chart::DCChart, indent::Int=0)
	tabbing = "  "^indent
	println(io, tabbing, "<div style=\"float:left;\">")
	println(io, tabbing, "  <h3 id=\"heading_", chart.parent, "\">", chart.title, " </h3>")
	println(io, tabbing, "  <div id=\"", chart.parent, "\"></div>")
	println(io, tabbing, "</div>")
end

function write_html_widget_entry(io::IO, widget::DCWidget, indent::Int=0)
  tabbing = "  "^indent
  println(io, tabbing, widget.html, "<br/>")
end

function write_html_body(io::IO, dcout::DCOut)
	print(io, "<body>
  <div id=\"reset_all_well_", dcout.output_id, "\"style=\"width: 100%; text-align: right;\">&nbsp</div>
  ")
	for chart in dcout.charts
		write_html_chart_entry(io, chart, 1)
	end
	print(io, """
	<div style="clear:both;"></div>
  """)
  for widget in dcout.widgets
    write_html_widget_entry(io, widget, 0)
  end
	println(io, "</body>")
end

function write_script_dependencies(io::IO, dependencies::Vector{Dependency})
  print(io, """require.config({paths: {""")
	for i in 1 : length(dependencies)
    #=
		@printf(io, "<script src='%s'></script>\n", src)
    =#
    @printf(io, """ "%s": "%s" """, dependencies[i].name, dependencies[i].path)
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
  d3.select("#reset_all_btn_""", dcout.output_id,
  """").remove();
  d3.select("#heading_" + chart_names[idx]).select(".chart-reset").remove();
  
  if (filter_in_use) {
    d3.select("#reset_all_well_""", dcout.output_id, """")
      .append("a")
      .attr("class", "button-label")
      .attr("id", "reset_all_btn_""", dcout.output_id, """")
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
function write_script(io::IO, dcout::DCOut, dependencies::Vector{Dependency})
	println(io, """<script type="text/javascript">""")
  	write_script_dependencies(io, dependencies)

	print(io, "require([")
	for i in 1 : length(dependencies)
		print(io, "\"", dependencies[i].name, "\"")
		if i < length(dependencies)
	 		print(io, ", ")
		end
	end
	print(io, "], function(")
	unused_counter = 1;
	for i in 1 : length(dependencies)
		if (dependencies[i].has_export)
	 		print(io, dependencies[i].name)
		else
	  		print(io, "unused", unused_counter)
	  		unused_counter += 1
		end
		if i < length(dependencies)
	 		print(io, ", ")
		end
	end
	print(io, ") {\n")

	write_data(io, dcout.df)

	# crossfilter
	println(io, "var cf = crossfilter(data);")
 	println(io, "var all = cf.groupAll();")

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

	# charts
	for chart in dcout.charts
		write(io, chart, 1)
	end

	# widget
	for widget in dcout.widgets
		write(io, widget, 1)
	end

	println(io, "dc.renderAll();")

	write_reset_script(io, dcout)

	println(io, "});\n</script>")
end

function write_source_html(io::IO, dcout::DCOut)
	write_html_head(io)
	write_html_body(io, dcout)
 	# Note: dependencies must be ordered! (hence why this is not a dictionary)
	dependencies = [Dependency("d3","https://cdnjs.cloudflare.com/ajax/libs/d3/3.5.17/d3.min", true),
	                Dependency("crossfilter","https://cdnjs.cloudflare.com/ajax/libs/crossfilter/1.3.7/crossfilter", false),
	                Dependency("dc","https://cdnjs.cloudflare.com/ajax/libs/dc/1.7.1/dc", true)]
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
		
		iframe_width = 975 # [pix]
		row_height = 275 # [pix]

		ncharts = length(dcout.charts)
		nrows = ceil(Int, ncharts/3)
		iframe_height = nrows*275

    randomize_ids(dcout)

    write(io, """<div style="width:$(iframe_width)px; height: $(iframe_height)px; overflow-y: auto;">""")
    write_source_html(io, dcout)
    write(io, """</div>""")
	else
		# TODO
		# decide what to do in the absence of IJulia
	end
end
