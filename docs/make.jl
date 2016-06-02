using DataFrames, Documenter, DC

makedocs(
    # options
    modules = [DC]
)

deploydocs(
    deps   = Deps.pip("mkdocs", "python-markdown-math"),
    repo   = "github.com/tawheeler/DC.jl.git",
    julia  = "0.4.5"
)