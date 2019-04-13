module DumbCompleter

__init__() = foreach(loadmodule!, (Core, Base))

struct Leaf
    name::Symbol
    type::Type
    mod::Module
    Leaf(n::Symbol, ::T, m::Module=parentmodule(T)) where T = new(n, T, m)
end

struct Tree
    lf::Union{Leaf, Nothing}
    tr::Dict{Char, Tree}
    Tree(lf::Union{Leaf, Nothing}=nothing) = new(lf, Dict{Char, Tree}())
end

const EXPORTS = Tree()
const MODULES = Dict{Module, Tree}()

function putleaf!(tr::Tree, lf::Leaf)
    name = string(lf.name)
    ind = 1
    while ind <= length(name)
        tr = get!(tr.tr, name[ind], Tree(ind == length(name) ? lf : nothing))
        ind = nextind(name, ind)
    end
end

cancomplete(m::Module) = s -> cancomplete(s, m)
cancomplete(s::Symbol, m::Module) = isdefined(m, s) && !startswith(string(s), "#")

function loadmodule!(m::Module)
    (m === Main || haskey(MODULES, m)) && return
    MODULES[m] = Tree()
    ns = filter(cancomplete(m), names(m; all=true, imported=true))
    foreach(ns) do n
        lf = Leaf(n, getfield(m, n))
        putleaf!(MODULES[m], lf)
        Base.isexported(m, n) && putleaf!(EXPORTS, lf)
    end
    foreach(loadmodule!, map(n -> getfield(m, n), filter(n -> getfield(m, n) isa Module, ns)))
end

function leaves(tr::Tree)
    lvs = map(tr -> tr.lf, Iterators.filter(tr -> tr.lf !== nothing, values(tr.tr)))
    return vcat(lvs, mapreduce(leaves, vcat, values(tr.tr); init=Leaf[])...)
end

function getcompletions(tr::Tree, s::AbstractString)
    for c in s
        haskey(tr.tr, c) || return Leaf[]
        tr = tr.tr[c]
    end
    lvs = leaves(tr)
    return tr.lf === nothing ? lvs : [tr.lf; lvs]
end

getcompletions(s::AbstractString) = getcompletions(EXPORTS, s)
getcompletions(s::AbstractString, m::Module) = getcompletions(get(MODULES, m, Tree()), s)
getcompletions(s::AbstractString, m::Symbol) =
    getcompletions(get(MODULES, Module(m), Tree()), s)
getcompletions(s::AbstractString, m::AbstractString) =
    getcompletions(get(MODULES, Symbol(m), Tree()), s)

end
