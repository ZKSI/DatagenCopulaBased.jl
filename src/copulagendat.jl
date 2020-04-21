"""
    simulate_copula(t::Int, copula::Function, args...)

    returns t samples of the given copula function with args...

    supports following copulas:
        elliptical
        - gaussian_cop,
                args: Σ::Matrix{Float} (the correlation matrix, the covariance one will be normalised)
        - tstudent_cop,
                args: Σ::Matrix{Float}, ν::Int

        - frechet,
            args: n::Int, α::Union{Int, Float} (number of marginals, parameter of maximal copula α ∈ [0,1])
             or
            args: n::Int, α::Union{Int, Float}, β::Union{Int, Float}, supported only for n = 2 and α, β, α+β ∈ [0,1]

        - chain_frechet, simulates a chain of bivariate frechet copulas
            args: α::Vector{Float64}, β::Vector{Float64} = zero(α) - vectors of
            parameters of subsequent bivariate copulas. Each element must fulfill
            conditions of the frechet copula. n.o. marginals = length(α)+1.
            We require length(α) = length(β).


        - marshalolkin,
            args: λ::Vector{Float64} λ = [λ₁, λ₂, ..., λₙ, λ₁₂, λ₁₃, ..., λ₁ₙ, λ₂₃, ..., λₙ₋₁ₙ, λ₁₂₃, ..., λ₁₂...ₙ]
              n.o. margs = ceil(Int, log(2, length(λ)-1)), params:

        - archimedean: gumbel, clayton, amh (Ali-Mikhail-Haq), frank.
            args: n::Int - n.o. margs, θ::Float - copula parameter, cor::String, keyword.
              if cor = ["Spearman", "Kendall"] uses these correlations in place of θ
        - rev_gumbel, rev_clayton, rev_amh - the same but the output is reversed: u →  1 .- u

        - nested archimedean
            - nested_gumbel nested_clayton, nested_amh, nested_frank
              args:  - n::Vector{Int}, ϕ::Vector{Float64} (sizes and params of children copulas)
                     - θ::Float64, m::Int = 0 (param and additional size of parent copula)
        - double nested (only Gumbel)
            - nested_gumbel
             args:  - n::Vector{Vector{Int}} (sizes of ground children copulas)
                    - Ψ::Vector{Vector{Float64}}, ϕ::Vector{Float64}, θ::Float64 (params of ground childeren, children and parent copulas)
        - hierarchical nested (only Gumbel)
            - nested_gumbel
                args: θ::Vector{Float64} - vector of parameters from ground ground child to parent
                                    all copuals are bivariate n = length(θ)+1

        - chain_archimedeans  simulate the chain of bivariate archimedean copula,

            args: - θ::Union{Vector{Float64}, Vector{Int}} - parameters of subsequent bivariate copulas
                  - copula::Union{Vector{String}, String}, indicates a bivariate copulas
                        or their sequence, supported are supports: clayton, frank and amh famillies
                 - keyword cor, if cor = ["Spearman", "Kendall"] uses these correlations in place of parameters
                        of subsequent buvariate copulas
        - rev_chain_archimedeans reversed version of the chain_archimedeans

"""

function simulate_copula(t::Int, copula::Function, args...; cor = "")
    if cor != ""
        return copula(t, args...; cor = cor)
    else
        return copula(t, args...)
    end
end


# Obsolete implemnetations

gausscopulagen(t::Int, Σ::Matrix{Float64}) = simulate_copula1(t, Gaussian_cop(Σ))

tstudentcopulagen(t::Int, Σ::Matrix{Float64}, ν::Int) = simulate_copula1(t, Student_cop(Σ, ν))

frechetcopulagen(t::Int, args...) = simulate_copula1(t, Frechet_cop(args...))

marshallolkincopulagen(t::Int, λ::Vector{Float64}) = simulate_copula1(t, Marshall_Olkin_cop(λ))


function archcopulagen(t::Int, n::Int, θ::Union{Float64, Int}, copula::String;
                                                              rev::Bool = false,
                                                              cor::String = "")

    args = (n, θ)
    if cor != ""
        args = (n, θ, cor)
    end
    if copula == "gumbel"
        if !rev
            simulate_copula1(t, Gumbel_cop(args...))
        else
            simulate_copula1(t, Gumbel_cop_rev(args...))
        end
    elseif copula == "clayton"
        if !rev
            simulate_copula1(t, Clayton_cop(args...))
        else
            simulate_copula1(t, Clayton_cop_rev(args...))
        end
    elseif copula == "amh"
        if !rev
            simulate_copula1(t, AMH_cop(args...))
        else
            simulate_copula1(t, AMH_cop_rev(args...))
        end
    elseif copula == "frank"
           simulate_copula1(t, Frank_cop(args...))

    else
        throw(AssertionError("$(copula) copula is not supported"))
    end
end


function nestedarchcopulagen(t::Int, n::Vector{Int}, ϕ::Vector{Float64}, θ::Float64, copula::String, m::Int = 0)
    if copula == "gumbel"
        children = [Gumbel_cop(n[i], ϕ[i]) for i in 1:length(n)]
        simulate_copula1(t, Nested_Gumbel_cop(children, m, θ))
    elseif copula == "clayton"
        children = [Clayton_cop(n[i], ϕ[i]) for i in 1:length(n)]
        simulate_copula1(t, Nested_Clayton_cop(children, m, θ))
    elseif copula == "amh"
        children = [AMH_cop(n[i], ϕ[i]) for i in 1:length(n)]
        simulate_copula1(t, Nested_AMH_cop(children, m, θ))
    elseif copula == "frank"
        children = [Frank_cop(n[i], ϕ[i]) for i in 1:length(n)]
        simulate_copula1(t, Nested_Frank_cop(children, m, θ))
    else
        throw(AssertionError("$(copula) copula is not supported"))
    end
end


function nestedarchcopulagen(t::Int, n::Vector{Vector{Int}}, Ψ::Vector{Vector{Float64}},
                                                             ϕ::Vector{Float64}, θ::Float64,
                                                             copula::String = "gumbel")
  copula == "gumbel" || throw(AssertionError("generator supported only for gumbel familly"))
  length(n) == length(Ψ) == length(ϕ) || throw(AssertionError("parameter vector must be of the sam size"))
  parents = Nested_Gumbel_cop[]
  for i in 1:length(n)
      length(n[i]) == length(Ψ[i]) || throw(AssertionError("parameter vector must be of the sam size"))
      child = [Gumbel_cop(n[i][j], Ψ[i][j])  for j in 1:length(n[i])]
      push!(parents, Nested_Gumbel_cop(child, 0, ϕ[i]))
  end
  simulate_copula1(t, Double_Nested_Gumbel_cop(parents, θ))
end


function nestedarchcopulagen(t::Int, θ::Vector{Float64}, copula::String = "gumbel")
    copula == "gumbel" || throw(AssertionError("generator supported only for gumbel familly"))
    simulate_copula1(t, Hierarchical_Gumbel_cop(θ))
end


function chainfrechetcopulagen(t::Int, α::Vector{Float64}, β::Vector{Float64} = zero(α))
    simulate_copula(t, chain_frechet, α, β)
end

VFI = Union{Vector{Float64}, Vector{Int}}

function chaincopulagen(t::Int, θ::VFI, copula::Union{Vector{String}, String};
                                        rev::Bool = false, cor::String = "")
    if rev == false
      return simulate_copula(t, chain_archimedeans, θ, copula, cor = cor)
    else
      return simulate_copula(t, rev_chain_archimedeans, θ, copula, cor = cor)
    end
 end
