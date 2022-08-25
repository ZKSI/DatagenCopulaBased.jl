# Archimedean copulas


"""
  arch_gen(copula::String, r::Matrix{Real}, θ::Real)

Auxiliary function used to generate data from archimedean copula (clayton, gumbel, frank or amh)
parametrized by a single parameter θ given a matrix of independent [0,1] distributerd
random vectors.

```jldoctest
  julia> arch_gen("clayton", [0.2 0.6 0.9; 0.4 0.5 0.8], 2.)
  2×2 Array{Real,2}:
   0.675778  0.851993
   0.687482  0.736394
```
"""

function arch_gen(copula, r, θ; rng)
  T = typeof(θ)
  t = size(r,1)
  if copula == "clayton"
    U = zeros(T, t, size(r,2)-1)
    for j in 1:t
      U[j,:] = clayton_gen(r[j,:], θ)
    end
    return U
  elseif copula == "amh"
    U = zeros(T ,t, size(r,2)-1)
    for j in 1:t
      U[j,:] = amh_gen(r[j,:], θ)
    end
    return U
  elseif copula == "frank"
    U = zeros(T, t, size(r,2)-1)
    w = logseriescdf(1-exp(-θ))
    for j in 1:t
      U[j,:] = frank_gen(r[j,:], θ, w)
    end
    return U
  else
    U = zeros(T, t, size(r,2)-1)
    u = r[:,end]
    p = invperm(sortperm(u))
    v = [levyel(θ, rand(rng), rand(rng)) for i in 1:length(u)]
    v = sort(v)[p]
    for j in 1:t
      U[j,:] = -log.(r[j,1:end-1])./v[j]
    end
    return exp.(-U.^(1/θ))
  end
end

"""
      gumbel_gen(r::Vector{Real}, θ::Real)

Given a vector of random numbers r of size n+2, return the sample from the Gumbel
copula parametrised by θ of the size n.
"""
function gumbel_gen(r, θ)
    u = -log.(r[1:end-2])./levyel(θ, r[end-1], r[end])
    return exp.(-u.^(1/θ))
end

"""
    clayton_gen(r::Vector{Real}, θ::Real)

Given a vector of random numbers r of size n+1, return the sample from the Clayton
copula parametrised by θ of the size n.
"""
function clayton_gen(r, θ)
    gamma_vec = gamma_inc_inv(1/θ, r[end], 1-r[end])
    u = -log.(r[1:end-1])./gamma_vec
    return (1 .+ u).^(-1/θ)
end

"""
    amh_gen(r::Vector{Real}, θ::Real)

Given a vector of random numbers r of size n+1, return the sample from the AMH
copula parametrised by θ of the size n.
"""
function amh_gen(r, θ)
    u = -log.(r[1:end-1])./(1 .+quantile.(Geometric(1-θ), r[end]))
    return (1-θ) ./(exp.(u) .-θ)
end

"""
    frank_gen(r::Vector{Real}, θ::Real, logseries::Vector{Real})

Given a vector of random numbers r of size n+1, return the sample from the Frank
copula parametrised by θ of the size n. Axiliary logseries is a vector of the
logseries sequence priorly computed.
"""
function frank_gen(r, θ, logseries)
    logseriesquantile = findlast(logseries .< r[end])
    u = -log.(r[1:end-1])./logseriesquantile
    return -log.(1 .+exp.(-u) .*(exp(-θ)-1)) ./θ
end

"""
    GumbelCopula

Fields:
  - n::Int - number of marginals
  - θ::Real - parameter

Constructor

        GumbelCopula(n::Int, θ::Real)

The Gumbel n variate copula is parameterized by θ::Real ∈ [1, ∞), supported for n::Int ≧ 2.

Constructor

    GumbelCopula(n::Int, θ::Real, cor::Type{<:CorrelationType})

For computing copula parameter from expected correlation use empty type cor::Type{<:CorrelationType} where
SpearmanCorrelation <:CorrelationType and KendallCorrelation<:CorrelationType. If used cor put expected correlation in the place of θ  in the constructor.
The copula parameter will be computed then. The correlation must be greater than zero.

```jldoctest

julia> GumbelCopula(4, 3.)
GumbelCopula(4, 3.0)

julia> GumbelCopula(4, .75, KendallCorrelation)
GumbelCopula(4, 4.0)
```
"""
struct GumbelCopula{T} <: Copula{T}
  n::Int
  θ::T
  function(::Type{GumbelCopula})(n::Int, θ::T) where T <: Real
      n >= 2 || throw(DomainError("not supported for n < 2"))
      testθ(θ, "gumbel")
      new{T}(n, θ)
  end
  function(::Type{GumbelCopula})(n::Int, ρ::T, cor::Type{<:CorrelationType}) where T <: Real
      n >= 2 || throw(DomainError("not supported for n < 2"))
      θ = getθ4arch(ρ, "gumbel", cor)
      new{T}(n, θ)
  end
end



"""
    simulate_copula!(U::Matrix{Real}, copula::GumbelCopula; rng::AbstractRNG = Random.GLOBAL_RNG)

Given the preallocated output U, Returns size(U,1) realizations from the Gumbel copula -  GumbelCopula(n, θ)
N.o. marginals is size(U,2), requires size(U,2) == copula.n

```jldoctest
julia> Random.seed!(43);

julia> U = zeros(2,3)
2×3 Array{Float64,2}:
 0.0  0.0  0.0
 0.0  0.0  0.0

julia> simulate_copula!(U, GumbelCopula(3, 1.5))

julia> U
2×3 Array{Float64,2}:
 0.740038  0.918928  0.950674
 0.637826  0.483514  0.123949
```
"""
function simulate_copula!(U, copula::GumbelCopula{T}; rng = Random.GLOBAL_RNG) where T
    θ = copula.θ
    n = copula.n
    size(U, 2) == n || throw(AssertionError("n.o. margins in pre allocated output and copula not equal"))
    for j in 1:size(U,1)
      u = rand(rng, T, n+2)
      U[j,:] = gumbel_gen(u, θ)
    end
end

"""
    GumbelCopulaRev

Fields:
  - n::Int - number of marginals
  - θ::Real - parameter

Constructor

    GumbelCopulaRev(n::Int, θ::Real)

The reversed Gumbel copula (reversed means u → 1 .- u),
parameterized by θ::Real ∈ [1, ∞), supported for n::Int ≧ 2.

Constructor

    GumbelCopulaRev(n::Int, θ::Real, cor::Type{<:CorrelationType})

For computing copula parameter from expected correlation use empty type cor::Type{<:CorrelationType} where
SpearmanCorrelation <:CorrelationType and KendallCorrelation<:CorrelationType. If used cor put expected correlation in the place of θ  in the constructor.
The copula parameter will be computed then. The correlation must be greater than zero.

```jldoctest
julia> c = GumbelCopulaRev(4, .75, KendallCorrelation)
GumbelCopulaRev(4, 4.0)

julia> Random.seed!(43);

julia> simulate_copula(2, c)
2×4 Array{Float64,2}:
 0.963524   0.872108  0.816626  0.783637
 0.0954475  0.138451  0.13593   0.0678172
```
"""
struct GumbelCopulaRev{T} <: Copula{T}
  n::Int
  θ::T
  function(::Type{GumbelCopulaRev})(n::Int, θ::T) where T <: Real
      n >= 2 || throw(DomainError("not supported for n < 2"))
      testθ(θ, "gumbel")
      new{T}(n, θ)
  end
  function(::Type{GumbelCopulaRev})(n::Int, ρ::T, cor::Type{<:CorrelationType}) where T <: Real
      n >= 2 || throw(DomainError("not supported for n < 2"))
      θ = getθ4arch(ρ, "gumbel", cor)
      new{T}(n, θ)
  end
end



"""
    simulate_copula!(U::Matrix{Real}, copula::GumbelCopulaRev; rng::AbstractRNG = Random.GLOBAL_RNG)

Given the preallocated output U, Returns size(U,1) realizations from the reversed Gumbel copula -  GumbelCopulaRev(n, θ)
N.o. marginals is size(U,2), requires size(U,2) == copula.n

```jldoctest
julia> Random.seed!(43);

julia> U = zeros(2,3)
2×3 Array{Float64,2}:
 0.0  0.0  0.0
 0.0  0.0  0.0

julia> simulate_copula!(U, GumbelCopulaRev(3, 1.5))

julia> U
2×3 Array{Flaot64,2}:
 0.259962  0.081072  0.0493259
 0.362174  0.516486  0.876051
```
"""
function simulate_copula!(U, copula::GumbelCopulaRev{T}; rng = Random.GLOBAL_RNG) where T
    θ = copula.θ
    n = copula.n
    size(U, 2) == n || throw(AssertionError("n.o. margins in pre allocated output and copula not equal"))
    for j in 1:size(U,1)
      u = rand(rng, T, n+2)
      U[j,:] = 1 .- gumbel_gen(u, θ)
    end
end

"""
    ClaytonCopula

Fields:
  - n::Int - number of marginals
  - θ::Real - parameter

Constructor

    ClaytonCopula(n::Int, θ::Real)

The Clayton n variate copula parameterized by θ::Real, such that θ ∈ (0, ∞) for n > 2 and θ ∈ [-1, 0) ∪ (0, ∞) for n = 2,
supported for n::Int ≥ 2.

Constructor

    ClaytonCopula(n::Int, θ::Real, cor::Type{<:CorrelationType})

For computing copula parameter from expected correlation use empty type cor::Type{<:CorrelationType} where
SpearmanCorrelation <:CorrelationType and KendallCorrelation<:CorrelationType. If used cor put expected correlation in the place of θ  in the constructor.
The copula parameter will be computed then. The correlation must be greater than zero.

```jldoctest
julia> ClaytonCopula(4, 3.)
ClaytonCopula(4, 3.0)

julia> ClaytonCopula(4, 0.9, SpearmanCorrelation)
ClaytonCopula(4, 5.5595567742323775)
```
"""
struct ClaytonCopula{T} <: Copula{T}
  n::Int
  θ::T
  function(::Type{ClaytonCopula})(n::Int, θ::T) where T <: Real
      n >= 2 || throw(DomainError("not supported for n < 2"))
      if n > 2
        testθ(θ, "clayton")
      else
        (θ >= -1.) & (θ != 0.) || throw(DomainError("bivariate Clayton not supported for θ < -1 or θ = 0"))
      end
      new{T}(n, θ)
  end
  function(::Type{ClaytonCopula})(n::Int, ρ::T, cor::Type{<:CorrelationType}) where T <: Real
      n >= 2 || throw(DomainError("not supported for n < 2"))
      θ = getθ4arch(ρ, "clayton", cor)
      new{T}(n, θ)
  end
end


"""
    simulate_copula!(U::Matrix{Real}, copula::ClaytonCopula; rng::AbstractRNG = Random.GLOBAL_RNG)

Given the preallocated output U, Returns t realizations from the Clayton copula - ClaytonCopula(n, θ)
N.o. marginals is size(U,2), requires size(U,2) == copula.n.
N.o. realisations is size(U,1).

```jldoctest
julia> Random.seed!(43);

julia> U = zeros(3,2)
3×2 Array{Float64,2}:
 0.0  0.0
 0.0  0.0
 0.0  0.0

julia> simulate_copula!(U, ClaytonCopula(2, 1.))

julia> U
3×2 Array{Float64,2}:
 0.562482  0.896247
 0.968953  0.731239
 0.749178  0.38015

julia> U = zeros(2,2)
2×2 Array{Float64,2}:
 0.0  0.0
 0.0  0.0

julia> Random.seed!(43);

julia> simulate_copula!(U, ClaytonCopula(2, -.5))

julia> U
2×2 Array{Float64,2}:
 0.180975  0.818017
 0.888934  0.863358
```
"""
function simulate_copula!(U, copula::ClaytonCopula{T}; rng = Random.GLOBAL_RNG) where T
    θ = copula.θ
    n = copula.n
    size(U, 2) == n || throw(AssertionError("n.o. margins in pre allocated output and copula not equal"))
    if (n == 2) & (θ < 0)
        simulate_copula!(U, ChainArchimedeanCopulas([θ], "clayton"); rng = rng)
    else
        for j in 1:size(U,1)
            u = rand(rng, T, n+1)
            U[j,:] = clayton_gen(u, θ)
        end
    end
end

"""
    ClaytonCopulaRev

Fields:
- n::Int - number of marginals
- θ::Real - parameter

Constructor

    ClaytonCopulaRev(n::Int, θ::Real)

The reversed Clayton copula parameterized by θ::Real (reversed means u → 1 .- u).
Domain: θ ∈ (0, ∞) for n > 2 and θ ∈ [-1, 0) ∪ (0, ∞) for n = 2,
supported for n::Int ≧ 2.

Constructor

    ClaytonCopulaRev(n::Int, θ::Real, cor::Type{<:CorrelationType})

For computing copula parameter from expected correlation use empty type cor::Type{<:CorrelationType} where
SpearmanCorrelation <:CorrelationType and KendallCorrelation<:CorrelationType. If used cor put expected correlation in the place of θ  in the constructor.
The copula parameter will be computed then. The correlation must be greater than zero.

```jldoctest

julia> ClaytonCopulaRev(4, 3.)
ClaytonCopulaRev(4, 3.0)

julia> ClaytonCopulaRev(4, 0.9, SpearmanCorrelation)
ClaytonCopulaRev(4, 5.5595567742323775)

```
"""
struct ClaytonCopulaRev{T} <: Copula{T}
  n::Int
  θ::T
  function(::Type{ClaytonCopulaRev})(n::Int, θ::T) where T <: Real
      n >= 2 || throw(DomainError("not supported for n < 2"))
      if n > 2
        testθ(θ, "clayton")
      else
        (θ >= -1.) & (θ != 0.) || throw(DomainError("bivariate Clayton not supported for θ < -1 or θ = 0"))
      end
      new{T}(n, θ)
  end
  function(::Type{ClaytonCopulaRev})(n::Int, ρ::T, cor::Type{<:CorrelationType}) where T <: Real
      n >= 2 || throw(DomainError("not supported for n < 2"))
      θ = getθ4arch(ρ, "clayton", cor)
      new{T}(n, θ)
  end
end



"""
    simulate_copula!(U::Matrix{Real}, copula::ClaytonCopulaRev; rng::AbstractRNG = Random.GLOBAL_RNG)

Given the preallocated output U, Returns size(U,1) realizations from the reversed Clayton copula - ClaytonCopulaRev(n, θ)
N.o. marginals is size(U,2), requires size(U,2) == copula.n

```jldoctest
julia> Random.seed!(43);

julia> U = zeros(2,2)
2×2 Array{Float64,2}:
 0.0  0.0
 0.0  0.0

julia> simulate_copula!(U, ClaytonCopulaRev(2, -0.5))

julia> U
2×2 Array{Float64,2}:
 0.819025  0.181983
 0.111066  0.136642

 julia> Random.seed!(43);

julia> U = zeros(2,2)
2×2 Array{Float64,2}:
 0.0  0.0
 0.0  0.0

julia> simulate_copula!(U, ClaytonCopulaRev(2, 2.))

julia> U
2×2 Array{Float64,2}:
 0.347188   0.087281
 0.0257036  0.212676
```
"""
function simulate_copula!(U, copula::ClaytonCopulaRev{T}; rng = Random.GLOBAL_RNG) where T
    θ = copula.θ
    n = copula.n
    size(U, 2) == n || throw(AssertionError("n.o. margins in pre allocated output and copula not equal"))
    if (n == 2) & (θ < 0)
        for j in 1:size(U,1)
          u = rand(rng, T)
          w = rand(rng, T)
          U[j,:] = 1 .- hcat(u, rand2cop(u, θ, "clayton", w))
        end
    else
        for j in 1:size(U,1)
            u = rand(rng, T, n+1)
            U[j,:] = 1 .- clayton_gen(u, θ)
        end
    end
end

"""
    AmhCopula

Fields:
- n::Int - number of marginals
- θ::Real - parameter

Constructor

    AmhCopula(n::Int, θ::Real)

The Ali-Mikhail-Haq copula parameterized by θ, domain: θ ∈ (0, 1) for n > 2 and  θ ∈ [-1, 1] for n = 2.

Constructor

    AmhCopula(n::Int, θ::Real, cor::Type{<:CorrelationType})

For computing copula parameter from expected correlation use empty type cor::Type{<:CorrelationType} where
SpearmanCorrelation <:CorrelationType and KendallCorrelation<:CorrelationType. If used cor put expected correlation in the place of θ  in the constructor.
The copula parameter will be computed then. The correlation must be greater than zero.
Such correlation must be grater than zero and limited from above due to the θ domain.
            - Spearman correlation must be in range (0, 0.5)
            - Kendall correlation must be in range (0, 1/3)

```jldoctest
julia> AmhCopula(4, .3)
AmhCopula(4, 0.3)

julia> AmhCopula(4, .3, KendallCorrelation)
AmhCopula(4, 0.9999)

```
"""
struct AmhCopula{T} <: Copula{T}
  n::Int
  θ::T
  function(::Type{AmhCopula})(n::Int, θ::T) where T <: Real
      n >= 2 || throw(DomainError("not supported for n < 2"))
      if n > 2
        testθ(θ, "amh")
      else
      1 >=  θ >= -1 || throw(DomainError("bivariate AMH not supported for θ > 1 or θ < -1"))
      end
      new{T}(n, θ)
  end
  function(::Type{AmhCopula})(n::Int, ρ::T, cor::Type{<:CorrelationType}) where T <: Real
      n >= 2 || throw(DomainError("not supported for n < 2"))
      θ = getθ4arch(ρ, "amh", cor)
      new{T}(n, θ)
  end
end



"""
    simulate_copula!(U::Matrix{Real}, copula::AmhCopula; rng::AbstractRNG = Random.GLOBAL_RNG)

Given the preallocated output U, Returns size(U,1) realizations from the Ali-Mikhail-Haq copula- AmhCopula(n, θ)
N.o. marginals is size(U,2), requires size(U,2) == copula.n

```jldoctest
julia> Random.seed!(43);

julia> simulate_copula!(U, AmhCopula(2, -0.5))

julia> U
4×2 Array{Float64,2}:
 0.180975  0.820073
 0.888934  0.886169
 0.408278  0.919572
 0.828727  0.335864
```
"""
function simulate_copula!(U, copula::AmhCopula{T}; rng = Random.GLOBAL_RNG) where T
  n = copula.n
  θ = copula.θ
  size(U, 2) == n || throw(AssertionError("n.o. margins in pre allocated output and copula not equal"))
  if (θ in [0,1]) | (n == 2)*(θ < 0)
      simulate_copula!(U, ChainArchimedeanCopulas([θ], "amh"); rng = rng)
  else
    for j in 1:size(U,1)
      u = rand(rng, T, n+1)
      U[j,:] = amh_gen(u, θ)
    end
  end
end

"""
    AmhCopulaRev

Fields:
  - n::Int - number of marginals
  - θ::Real - parameter

Constructor

    AmhCopulaRev(n::Int, θ::Real)

The reversed Ali-Mikhail-Haq copula parametrized by θ, i.e.
such that the output is 1 .- u, where u is modelled by the corresponding AMH copula.
Domain: θ ∈ (0, 1) for n > 2 and  θ ∈ [-1, 1] for n = 2.

Constructor

    AmhCopulaRev(n::Int, θ::Real, cor::Type{<:CorrelationType})

For computing copula parameter from expected correlation use empty type cor::Type{<:CorrelationType} where
SpearmanCorrelation <:CorrelationType and KendallCorrelation<:CorrelationType. If used cor put expected correlation in the place of θ  in the constructor.
The copula parameter will be computed then. The correlation must be greater than zero.
Such correlation must be grater than zero and limited from above due to the θ domain.
              - Spearman correlation must be in range (0, 0.5)
              -  Kendall correlation must be in range (0, 1/3)

```jldoctest
julia> AmhCopulaRev(4, .3)
AmhCopulaRev(4, 0.3)
```
"""
struct AmhCopulaRev{T} <: Copula{T}
  n::Int
  θ::T
  function(::Type{AmhCopulaRev})(n::Int, θ::T) where T <: Real
      n >= 2 || throw(DomainError("not supported for n < 2"))
      if n > 2
        testθ(θ, "amh")
      else
        1 >=  θ >= -1 || throw(DomainError("bivariate AMH not supported for θ > 1 or θ < -1"))
      end
      new{T}(n, θ)
  end
  function(::Type{AmhCopulaRev})(n::Int, ρ::T, cor::Type{<:CorrelationType}) where T <: Real
      n >= 2 || throw(DomainError("not supported for n < 2"))
      θ = getθ4arch(ρ, "amh", cor)
      new{T}(n, θ)
  end
end



"""
    simulate_copula!(U::Matrix{Real}, copula::AmhCopulaRev; rng::AbstractRNG = Random.GLOBAL_RNG)

Given the preallocated output U, Returns size(U,1) realizations from the reversed Ali-Mikhail-Haq copula a - AmhCopulaRev(n, θ)
N.o. marginals is size(U,2), requires size(U,2) == copula.n

```jldoctest
julia> Random.seed!(43);

julia> U = zeros(4,2)
4×2 Array{Float64,2}:
 0.0  0.0
 0.0  0.0
 0.0  0.0
 0.0  0.0

julia> simulate_copula!(U, AmhCopulaRev(2, 0.5))

julia> U
4×2 Array{Float64,2}:
 0.516061   0.116089
 0.0379356  0.334231
 0.292457   0.74958
 0.0845089  0.505477
```
"""
function simulate_copula!(U, copula::AmhCopulaRev{T}; rng = Random.GLOBAL_RNG) where T
    θ = copula.θ
    n = copula.n
    size(U, 2) == n || throw(AssertionError("n.o. margins in pre allocated output and copula not equal"))
    if (n == 2) & (θ < 0)
        for j in 1:size(U,1)
          u = rand(rng, T)
          w = rand(rng, T)
          U[j,:] = 1 .- hcat(u, rand2cop(u, θ, "amh", w))
        end
    else
        for j in 1:size(U,1)
            u = rand(rng, T, n+1)
            U[j,:] = 1 .- amh_gen(u, θ)
        end
    end
end

"""
    FrankCopula

Fields:
- n::Int - number of marginals
- θ::Real - parameter

Constructor

    FrankCopula(n::Int, θ::Real)

The Frank n variate copula parameterized by θ::Real.
Domain: θ ∈ (0, ∞) for n > 2 and θ ∈ (-∞, 0) ∪ (0, ∞) for n = 2,
supported for n::Int ≧ 2.

Constructor

    FrankCopula(n::Int, θ::Real, cor::Type{<:CorrelationType})

For computing copula parameter from expected correlation use empty type cor::Type{<:CorrelationType} where
SpearmanCorrelation <:CorrelationType and KendallCorrelation<:CorrelationType. If used cor put expected correlation in the place of θ  in the constructor.
The copula parameter will be computed then. The correlation must be greater than zero.

```jldoctest
julia> FrankCopula(2, -5.)
FrankCopula(2, -5.0)

julia> FrankCopula(4, .3)
FrankCopula(4, 0.3)
```
"""
struct FrankCopula{T} <: Copula{T}
  n::Int
  θ::T
  function(::Type{FrankCopula})(n::Int, θ::T) where T <: Real
      n >= 2 || throw(DomainError("not supported for n < 2"))
      if n > 2
        testθ(θ, "frank")
      else
        θ != 0 || throw(DomainError("bivariate frank not supported for θ = 0"))
      end
      new{T}(n, θ)
  end
  function(::Type{FrankCopula})(n::Int, ρ::T, cor::Type{<:CorrelationType}) where T <: Real
      n >= 2 || throw(DomainError("not supported for n < 2"))
      θ = getθ4arch(ρ, "frank", cor)
      new{T}(n, θ)
  end
end



"""
    simulate_copula!(U::Matrix{Real}, copula::FrankCopula; rng::AbstractRNG = Random.GLOBAL_RNG)

Given the preallocated output U, Returns size(U,1) realizations from the Frank copula- FrankCopula(n, θ)
N.o. marginals is size(U,2), requires size(U,2) == copula.n

```jldoctest
julia> U = zeros(4,2)
4×2 Array{Float64,2}:
 0.0  0.0
 0.0  0.0
 0.0  0.0
 0.0  0.0

julia> Random.seed!(43);

julia> simulate_copula!(U, FrankCopula(2, 3.5))

julia> U
4×2 Array{Float64,2}:
 0.650276  0.910212
 0.973726  0.789701
 0.690966  0.358523
 0.747862  0.29333
```
"""
function simulate_copula!(U, copula::FrankCopula{T}; rng = Random.GLOBAL_RNG) where T
  n = copula.n
  θ = copula.θ
  size(U, 2) == n || throw(AssertionError("n.o. margins in pre allocated output and copula not equal"))
  if (n == 2) & (θ < 0)
      simulate_copula!(U, ChainArchimedeanCopulas([θ], "frank"); rng = rng)
  else
    w = logseriescdf(1-exp(-θ))
    for j in 1:size(U,1)
      u = rand(rng, T, n+1)
      U[j,:] = frank_gen(u, θ, w)
    end
  end
end

"""
  function testθ(θ::Real, copula::String)

Tests the parameter θ value for archimedean copula, returns void
"""
function testθ(θ, copula) where T
  if copula == "gumbel"
    θ >= 1 || throw(DomainError("gumbel copula not supported for θ < 1"))
  elseif copula == "amh"
    1 > θ > 0 || throw(DomainError("amh multiv. copula supported only for 0 < θ < 1"))
  else
    θ > 0 || throw(DomainError("generaton not supported for θ ≤ 0"))
  end
  Nothing
end

"""
  useρ(ρ::Real, copula::String)

Tests the available Spearman correlation for the Archimedean copula.

Returns Real, the copula parameter θ with the Spearman correlation ρ.
```jldoctest

julia> useρ(0.75, "gumbel")
2.294053859606698
```

"""
function useρ(ρ, copula)
  0 < ρ < 1 || throw(DomainError("Spearman correlation coeficiant must fulfill 0 < ρ < 1"))
  if copula == "amh"
    0 < ρ < 0.5 || throw(DomainError("Spearman correlation coeficiant must fulfill 0 < ρ < 0.5"))
  end
  ρ2θ(ρ, copula)
end

"""
  useτ(ρ::Real, copula::String)

Tests the available kendall's correlation for archimedean copula, returns Float,
corresponding copula parameter θ.

```jldoctest

julia> useτ(0.5, "clayton")
2.0
```
"""
function useτ(τ, copula)
  0 < τ < 1 || throw(DomainError("Kendall correlation coeficiant must fulfill 0 < τ < 1"))
  if copula == "amh"
    0 < τ < 1/3 || throw(DomainError("Kendall correlation coeficiant must fulfill 0 < τ < 1/3"))
  end
  τ2θ(τ, copula)
end

"""

    getθ4archgetθ4arch(ρ::Real, copula::String, cor::Type{SpearmanCorrelation})

    getθ4archgetθ4arch(ρ::Real, copula::String, cor::Type{KendallCorrelation})

Compute the copula parameter given the correlation, test if the parameter is in range.
Following types are supported: SpearmanCorrelation, KendallCorrelation


```jldoctest

julia> getθ4arch(0.5, "gumbel", SpearmanCorrelation)
1.541070420842913


julia> getθ4arch(0.5, "gumbel", KendallCorrelation)
2.0
```
"""
getθ4arch(ρ, copula, cor::Type{SpearmanCorrelation}) = useρ(ρ , copula)

getθ4arch(ρ, copula, cor::Type{KendallCorrelation}) = useτ(ρ , copula)
