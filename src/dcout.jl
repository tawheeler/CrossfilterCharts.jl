type DCOut
	df::DataFrame
	dims::Vector{Dimension}
	groups::Vector{Group}
	charts::Vector{DCChart}

	function DCOut(df::DataFrame)

		dims = Dimension[]
		groups = Group[]
		charts = DCChart[]

		for name in names(df)

			arr = df[name]
			if can_infer_chart(arr)
				dim = infer_dimension(arr, name)
				push!(dims, dim)

				group = infer_group(arr, dim)
				push!(groups, group)

				chart = DCChart(infer_chart(arr, group), group)
				push!(charts, chart)
			end
		end

		new(df, dims, groups, charts)
	end
end

dc(df::DataFrame) = DCOut(df)