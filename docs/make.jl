using DataFrames, Documenter, CrossfilterCharts

makedocs(
    # options
    modules = [CrossfilterCharts]
)

deploydocs(
    deps   = Deps.pip("mkdocs", "python-markdown-math"),
    repo   = "github.com/tawheeler/CrossfilterCharts.jl.git",
    julia  = "release",
    osname = "linux"
)
