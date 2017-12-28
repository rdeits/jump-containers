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
    @eval addconstraint!(c::SpecializedContainer, (f, s)::$(types)) = push!(c.$(field), (f, s))
end

"""
Stores a dictionary that maps (function, set) types to vectors,
allowing any constraint type to be added at any time.
"""
struct TypeContainer
    constraints::Dict{Tuple{DataType, DataType}, Vector}
end

TypeContainer() = TypeContainer(Dict())

function addconstraint!(c::TypeContainer, (f, s)::Tuple{F, S}) where {F <: AbstractFunction, S <: AbstractSet}
    v = get!(c.constraints, (F, S)) do
        Vector{Tuple{F, S}}()
    end::Vector{Tuple{F, S}}
    push!(v, (f, s))
end

"""
Like TypeContainer, but uses the object_id as its keys
so that the keys in the Dict can be the same concrete type
"""
struct IDContainer
    constraints::Dict{Tuple{UInt64, UInt64}, Vector}
end

IDContainer() = IDContainer(Dict())

function addconstraint!(c::IDContainer, (f, s)::Tuple{F, S}) where {F <: AbstractFunction, S <: AbstractSet}
    v = get!(c.constraints, (object_id(F), object_id(S))) do
        Vector{Tuple{F, S}}()
    end::Vector{Tuple{F, S}}
    push!(v, (f, s))
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

function get_slot!(c::IDVectContainer, (f, s)::Tuple{F, S}) where {F <: AbstractFunction, S <: AbstractSet}
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


function addconstraint!(c::IDVectContainer, (f, s)::Tuple{F, S}) where {F <: AbstractFunction, S <: AbstractSet}
    push!(get_slot!(c, (f, s)), (f, s))
end

"""
A completely generic container which does not sort its constraints
by type
"""
struct ErasedContainer
    constraints::Vector{Tuple{AbstractFunction, AbstractSet}}
end

ErasedContainer() = ErasedContainer([])

addconstraint!(c::ErasedContainer, (f, s)) = push!(c.constraints, (f, s))


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
end

using BenchmarkTools

for container in [SpecializedContainer, TypeContainer, IDContainer, IDVectContainer, ErasedContainer]
    @show container
    @btime add_some_constraints!(m) setup=(m=$container()) evals=1
end
