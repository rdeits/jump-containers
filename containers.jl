abstract type AbstractSet end

struct LessThan <: AbstractSet
    upper::Float64
end

struct GreaterThan <: AbstractSet
    lower::Float64
end

struct Interval <: AbstractSet
    lower::Float64
    upper::Float64
end

abstract type AbstractFunction end

struct Variable <: AbstractFunction
    idx::Int
end

struct Affine <: AbstractFunction
    vars::Vector{Int}
    coeffs::Vector{Float64}
    constant::Float64
end

build_constraint(s::Variable, f::LessThan) = Float64[s.idx, f.upper]
build_constraint(s::Variable, f::GreaterThan) = Float64[s.idx, f.lower]
build_constraint(s::Variable, f::Interval) = Float64[f.lower, s.idx, f.upper]
build_constraint(s::Affine, f::LessThan) = Float64[s.constant, f.upper]
build_constraint(s::Affine, f::GreaterThan) = Float64[s.constant, f.lower]
build_constraint(s::Affine, f::Interval) = Float64[f.lower, s.constant, f.upper]

"""
A fully specialized container type, which should be
fast, but will only support a fixed set of constraints
"""
struct SpecializedContainer
    vlt::Vector{Tuple{Variable, LessThan}}
    vgt::Vector{Tuple{Variable, GreaterThan}}
    vin::Vector{Tuple{Variable, Interval}}
    alt::Vector{Tuple{Affine, LessThan}}
    agt::Vector{Tuple{Affine, GreaterThan}}
    ain::Vector{Tuple{Affine, Interval}}
end

SpecializedContainer() = SpecializedContainer([], [], [], [], [], [])

for (field, types) in [
    (:vlt, Tuple{Variable, LessThan})
    (:vgt, Tuple{Variable, GreaterThan})
    (:vin, Tuple{Variable, Interval})
    (:alt, Tuple{Affine, LessThan})
    (:agt, Tuple{Affine, GreaterThan})
    (:ain, Tuple{Affine, Interval})
        ]
    @eval addconstraint!(c::SpecializedContainer, fs::$(types)) = push!(c.$(field), (fs[1], fs[2]))
end

function eachconstraint(f, c::SpecializedContainer)
    for constraint in c.vlt
        f(constraint)
    end
    for constraint in c.vgt
        f(constraint)
    end
    for constraint in c.vin
        f(constraint)
    end
    for constraint in c.alt
        f(constraint)
    end
    for constraint in c.agt
        f(constraint)
    end
    for constraint in c.ain
        f(constraint)
    end
end

"""
Stores a dictionary that maps (function, set) types to vectors,
allowing any constraint type to be added at any time.
"""
struct TypeContainer
    constraints::Dict{Tuple{DataType, DataType}, Vector}
end

TypeContainer() = TypeContainer(Dict())

function addconstraint!(c::TypeContainer, fs::Tuple{F, S}) where {F <: AbstractFunction, S <: AbstractSet}
    f, s = fs
    v = get!(c.constraints, (F, S)) do
        Vector{Tuple{F, S}}()
    end::Vector{Tuple{F, S}}
    push!(v, (f, s))
end

function eachconstraint(f, c::TypeContainer)
    for v in values(c.constraints)
        foreach(f, v)
    end
end

"""
Like TypeContainer, but uses the object_id as its keys
so that the keys in the Dict can be the same concrete type
"""
struct IDContainer
    constraints::Dict{Tuple{UInt64, UInt64}, Vector}
end

IDContainer() = IDContainer(Dict())

function addconstraint!(c::IDContainer, fs::Tuple{F, S}) where {F <: AbstractFunction, S <: AbstractSet}
    f, s = fs
    v = get!(c.constraints, (object_id(F), object_id(S))) do
        Vector{Tuple{F, S}}()
    end::Vector{Tuple{F, S}}
    push!(v, (f, s))
end

function eachconstraint(f, c::IDContainer)
    for v in values(c.constraints)
        foreach(f, v)
    end
end

"""
Like IDContainer, but stores a flat vector of keys instead of
a Dict for better performance with small numbers of keys
"""
struct IDVectContainer
    keys::Vector{Tuple{UInt, UInt}}
    constraints::Vector{Vector}
end

IDVectContainer() = IDVectContainer([], [])

function get_slot!(c::IDVectContainer, ::Tuple{F, S}) where {F <: AbstractFunction, S <: AbstractSet}
    key = (object_id(F), object_id(S))
    @inbounds for i in 1:length(c.keys)
        if c.keys[i] === key
            return c.constraints[i]::Vector{Tuple{F, S}}
        end
    end
    result = Vector{Tuple{F, S}}()
    push!(c.keys, key)
    push!(c.constraints, result)
    result
end


function addconstraint!(c::IDVectContainer, fs::Tuple{F, S}) where {F <: AbstractFunction, S <: AbstractSet}
    push!(get_slot!(c, fs), fs)
end

function eachconstraint(f, c::IDVectContainer)
    for v in c.constraints
        foreach(f, v)
    end
end

"""
A completely generic container which does not sort its constraints
by type
"""
struct ErasedContainer
    constraints::Vector{Tuple{AbstractFunction, AbstractSet}}
end

ErasedContainer() = ErasedContainer([])

addconstraint!(c::ErasedContainer, fs::Tuple) = push!(c.constraints, fs)

eachconstraint(f, c::ErasedContainer) = foreach(f, c.constraints)


#################################################
################ Benchmarks #####################

function add_some_constraints!(c)
    addconstraint!(c, (Variable(1), LessThan(2.0)))
    addconstraint!(c, (Variable(2), LessThan(5.0)))
    addconstraint!(c, (Variable(1), GreaterThan(-1.0)))
    addconstraint!(c, (Variable(2), GreaterThan(-1.0)))
    addconstraint!(c, (Affine([1, 2], [1.0, 2.0], 3.0), Interval(-1.0, 2.0)))
    for i in 1:100
        addconstraint!(c, (Variable(1), LessThan(2.0)))
    end
    for i in 1:10
        addconstraint!(c, (Affine([1, 2], [1.0, 2.0], 3.0), GreaterThan(-1.0)))
    end
end

function process_constraints(c)
    result = Vector{Vector{Float64}}()
    eachconstraint(c) do constraint
        push!(result, build_constraint(constraint[1], constraint[2]))
    end
    result
end

using BenchmarkTools

# Test that all the containers actually store the same data
for container in [TypeContainer, IDContainer, IDVectContainer, ErasedContainer]
    reference = SpecializedContainer()
    add_some_constraints!(reference)
    expected = process_constraints(reference)

    m = container()
    add_some_constraints!(m)
    @assert sort(process_constraints(m), by=Tuple) == sort(expected, by=Tuple)
end

for container in [SpecializedContainer, TypeContainer, IDContainer, IDVectContainer, ErasedContainer]
    @show container
    print("Adding constraints: \t")
    @btime add_some_constraints!(m) setup=(m=$container()) evals=1
    print("Iterating over constraints: \t")
    @btime process_constraints(m) setup=(m=$container(); add_some_constraints!(m)) evals=1
    print("Identity map over constraints: \t")
    @btime eachconstraint(identity, m) setup=(m=$container(); add_some_constraints!(m)) evals=1
end
