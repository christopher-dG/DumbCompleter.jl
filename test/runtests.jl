using DumbCompleter
using Test

const DC = DumbCompleter

@testset "DumbCompleter.jl" begin
    @testset "modkey" begin
        @test DC.modkey(Module(:Foo)) == :Foo
        @test DC.modkey(Module(Symbol("Foo.Bar"))) == Symbol("Foo.Bar")
        @test DC.modkey(Module(Symbol("Main.Foo.Bar"))) == Symbol("Foo.Bar")
    end

    @testset "cancomplete" begin
        s = gensym()
        eval(:($s = 1))
        @test !DC.cancomplete(s, @__MODULE__)
        @test !DC.cancomplete(:abcdefg, Base)
        @test DC.cancomplete(:one, Base)
        @test DC.cancomplete(Symbol("@pure"), Base)
        @test DC.cancomplete(:π, Base)
    end

    @testset "putleaf!" begin
        tr = DC.Tree()
        ab = DC.Leaf(:ab, "foo")
        DC.putleaf!(tr, ab)
        @test tr.tr['a'].tr['b'].lf == ab

        abcd = DC.Leaf(:abcd, "bar")
        DC.putleaf!(tr, abcd)
        @test tr.tr['a'].tr['b'].lf == ab
        @test tr.tr['a'].tr['b'].tr['c'].tr['d'].lf == abcd
    end

    @testset "loadmodule!" begin
        empty!(DC.EXPORTS[].tr)
        empty!(DC.MODULES[])
        DC.loadmodule!(Base)

        tr = DC.EXPORTS[]
        @test tr.tr['o'].tr['n'].tr['e'].lf.name === :one
        @test !haskey(tr.tr['_'].tr, 'o')

        tr = DC.MODULES[][:Base]
        @test tr.tr['o'].tr['n'].tr['e'].lf.name === :one
        @test tr.tr['_'].tr['o'].tr['n'].tr['e'].lf.name === :_one
    end

    @testset "leaves" begin
        DC.loadmodule!(Base)
        nlvs = length(DC.leaves(DC.MODULES[][:Base]))
        nns = length(filter(DC.cancomplete(Base), names(Base; all=true, imported=true)))
        @test nlvs == nns
    end

    @testset "completions" begin
        @test isempty(DC.completions("foo", "bar"))
        @test isempty(DC.completions("one", Core))
        ns = map(lf -> lf.name, DC.completions("one", Base))
        @test Set(ns) == Set([:one, :ones, :oneunit])
        ns = map(lf -> lf.name, DC.completions("show"))
        @test Set(ns) == Set([:show, :showable, :showerror, :show_sexpr])
    end
end
