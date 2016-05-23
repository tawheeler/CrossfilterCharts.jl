using DataFrames, Documenter, DC

makedocs()

deploydocs(
    deps   = Deps.pip("mkdocs", "python-markdown-math"),
    repo   = "github.com/tawheeler/DC.jl.git"
)