module DumbCompleter

using Pkg
using Serialization

export activate!, completions

# A completion.
struct Leaf
    name::Symbol
    type::Type
    mod::Module
    Leaf(n::Symbol, ::T, m::Module=parentmodule(T)) where T = new(n, T, m)
end

# A completion tree.
struct Tree
    lf::Union{Leaf, Nothing}
    tr::Dict{Char, Tree}
    Tree(lf::Union{Leaf, Nothing}=nothing) = new(lf, Dict{Char, Tree}())
end

# Stored completions.
struct Deps
    exports::Tree
    modules::Dict{Symbol, Tree}
end

const EXPORTS = Ref(Tree())
const MODULES = Ref(Dict{Symbol, Tree}())
const DEPS = joinpath(dirname(@__DIR__), "deps", "completions")

__init__() = try loaddeps!() catch; loadstoredeps!() end

# Load the completions file.
function loaddeps!()
    deps = open(deserialize, DEPS)
    EXPORTS[] = deps.exports
    MODULES[] = deps.modules
end

# Load default completions and store the completions file.
function loadstoredeps!()
    @info "Loading + storing default completions"
    foreach(loadmodule!, (Core, Base))
    mkpath(dirname(DEPS))
    deps = Deps(EXPORTS[], MODULES[])
    open(io -> serialize(io, deps), DEPS, "w")
end

# Store a single completion.
function putleaf!(tr::Tree, lf::Leaf)
    name = string(lf.name)
    ind = 1
    while ind <= length(name)
        tr = get!(tr.tr, name[ind], Tree(ind == length(name) ? lf : nothing))
        ind = nextind(name, ind)
    end
end

# Compute the normalized module name.
modkey(m::Module) = Symbol(replace(string(m), "Main." => ""))

# Determined whether a symbol is worth using as a completion.
cancomplete(m::Module) = s -> cancomplete(s, m)
cancomplete(s::Symbol, m::Module) = isdefined(m, s) && !startswith(string(s), "#")

# Load a module's names and store them as completions.
function loadmodule!(m::Module)
    m in (Main, Base.__toplevel__) && return
    k = modkey(m)
    haskey(MODULES[], k) && return
    MODULES[][k] = Tree()
    ns = filter(cancomplete(m), names(m; all=true, imported=true))
    foreach(ns) do n
        lf = Leaf(n, getfield(m, n))
        putleaf!(MODULES[][k], lf)
        Base.isexported(m, n) && putleaf!(EXPORTS[], lf)
    end
    foreach(loadmodule!, map(n -> getfield(m, n), filter(n -> getfield(m, n) isa Module, ns)))
end

loadmodule!(m::Symbol) = loadmodule!(Module(m))
loadmodule!(m::AbstractString) = loadmodule!(Symbol(m))

# Get all of a tree's completions.
function leaves(tr::Tree)
    lvs = map(tr -> tr.lf, Iterators.filter(tr -> tr.lf !== nothing, values(tr.tr)))
    return vcat(lvs, mapreduce(leaves, vcat, values(tr.tr); init=Leaf[])...)
end

"""
    completions(::Tree, s::AbstractString) -> Vector{Leaf}
    completions(s::AbstractString)
    completions(s::AbstractString, m::Union{Module, Symbol, AbstractString})

Get completions that begin with `s`.
"""
function completions(tr::Tree, s::AbstractString)
    for c in s
        haskey(tr.tr, c) || return Leaf[]
        tr = tr.tr[c]
    end
    lvs = sort!(leaves(tr); by=lf -> lf.name)
    return tr.lf === nothing ? lvs : [tr.lf; lvs]
end

completions(s::AbstractString) = completions(EXPORTS[], s)
completions(s::AbstractString, m::Module) =
    completions(get(MODULES[], modkey(m), Tree()), s)
completions(s::AbstractString, m::Symbol) =
    completions(get(MODULES[], Module(m), Tree()), s)
completions(s::AbstractString, m::AbstractString) =
    completions(get(MODULES[], Symbol(m), Tree()), s)

"""
    activate!(path::AbstractString)

Activate a project and load all of its modules' completions.
"""
function activate!(path::AbstractString)
    toml = joinpath(path, "Project.toml")
    isfile(toml) || return
    project = open(Pkg.Types.read_project, toml)
    current = Base.current_project()
    Pkg.activate(path)
    foreach(loadmodule!, keys(project.deps))
    loadmodule!(project.name)
    current === nothing ? Pkg.activate() : Pkg.activate(current)
end

end
