module DatagenCopulaBased
  using HypothesisTests
  using Distributions

  include("copulagendat.jl")
  include("subcopgendat.jl")
  include("helpers.jl")

  export claytoncopulagen, tstudentcopulagen, gausscopulagen, convertmarg!
  export subcopdatagen, cormatgen, g2clsubcopula, g2tsubcopula!, claytonsubcopulagen
end
