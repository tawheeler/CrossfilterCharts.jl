type DCOut
	df::DataFrame
	# dims::Vector{Dimension}
	charts::Vector{DCChart}

	function DCOut(df::DataFrame)
		charts = Array(DCChart, ncol(df))
		for (dim,name) in enumerate(names(df))
			chart_type = infer_chart_type(df[name])
			title = "Chart for " * string(name)
			group = string(name) * "_sum"
			charts[dim] = DCChart(chart_type, dim, group, title)
		end
		new(df, charts)
	end
end