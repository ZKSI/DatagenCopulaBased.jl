α = 0.025

@testset "helpers" begin
  Random.seed!(43)
  @test pvalue(ExactOneSampleKSTest(rand2cop(rand(500000), 0.5, "clayton"), Uniform(0,1))) > α
  Random.seed!(43)
  @test pvalue(ExactOneSampleKSTest(rand2cop(rand(500000), 0.5, "frank"), Uniform(0,1))) > α
  Random.seed!(42)
  @test pvalue(ExactOneSampleKSTest(rand2cop(rand(500000), 0.5, "amh"), Uniform(0,1))) > α
  Random.seed!(43)
  @test rand2cop([0.815308, 0.894269], 0.5, "clayton") ≈ [0.292041, 0.836167] atol=1.0e-5
end

@testset "exceptions" begin
  @test_throws DomainError testbivθ(-2., "clayton")
  @test_throws DomainError usebivρ(-.9, "amh", "Spearman")
  @test_throws DomainError usebivρ(-.25, "amh", "Kendall")
  @test_throws AssertionError chaincopulagen(100000, [1.1, 1.6], "gumbel")
  @test_throws AssertionError Chain_of_Archimedeans([2., 3.], ["frank", "gumbel"])
  @test_throws BoundsError Chain_of_Archimedeans([2., 3., 4.], ["frank", "frank"])
  @test_throws DomainError Chain_of_Archimedeans([2., -3.], ["frank", "clayton"])
  @test_throws AssertionError Chain_of_Archimedeans([2., 3., 4.], "gumbel")
  @test_throws DomainError Chain_of_Archimedeans([2., -3.], "clayton")
end

@testset "chain of Archimedean copulas" begin
  Random.seed!(43)
  @test chain_archimedeans(1, [4., 11.], "frank") ≈ [0.180975  0.492923  0.679345] atol=1.0e-5
  Random.seed!(43)
  @test chain_archimedeans(1, [4., 11.], ["frank", "clayton"]) ≈ [0.180975  0.492923  0.600322] atol=1.0e-5
  Random.seed!(43)
  @test rev_chain_archimedeans(1, [4., 11.], ["frank", "clayton"]) ≈ [0.819025  0.507077  0.399678] atol=1.0e-5

  cops = ["clayton", "clayton", "clayton", "frank", "amh", "amh"]
  Random.seed!(43)
  x = simulate_copula(500000, chain_archimedeans, [-0.9, 3., 2, 4., -0.3, 1.], cops)
  #test obsolete implemntation
  Random.seed!(43)
  x1 = chaincopulagen(500000, [-0.9, 3., 2, 4., -0.3, 1.], cops)
  @test norm(x-x1) ≈ 0.

  @test pvalue(ExactOneSampleKSTest(x[:,1], Uniform(0,1))) > α
  @test pvalue(ExactOneSampleKSTest(x[:,2], Uniform(0,1))) > α
  @test pvalue(ExactOneSampleKSTest(x[:,3], Uniform(0,1))) > α
  @test pvalue(ExactOneSampleKSTest(x[:,4], Uniform(0,1))) > α
  @test pvalue(ExactOneSampleKSTest(x[:,5], Uniform(0,1))) > α
  @test pvalue(ExactOneSampleKSTest(x[:,6], Uniform(0,1))) > α
  @test pvalue(ExactOneSampleKSTest(x[:,7], Uniform(0,1))) > α
  @test tail(x[:,1], x[:,2], "l", 0.0001) ≈ 0
  @test tail(x[:,6], x[:,7], "l") ≈ 0.5 atol=1.0e-1
  @test tail(x[:,5], x[:,6], "r", 0.0001) ≈ 0
  @test tail(x[:,3], x[:,4], "l") ≈ 1/(2^(1/2)) atol=1.0e-1
  @test tail(x[:,3], x[:,4], "r", 0.0001) ≈ 0
  @test corkendall(x)[1,2] ≈ -0.9/(2-0.9) atol=1.0e-3
  @test corkendall(x)[2,3] ≈ 3/(2+3) atol=1.0e-3
end
@testset "correlations" begin
  Random.seed!(43)
  x = simulate_copula(500000, chain_archimedeans, [0.6, -0.2], "clayton"; cor = "Spearman")
  @test corspearman(x[:,1], x[:,2]) ≈ 0.6 atol=1.0e-2
  @test corspearman(x[:,2], x[:,3]) ≈ -0.2 atol=1.0e-2
  Random.seed!(43)
  x = simulate_copula(500000, chain_archimedeans, [0.6, -0.2], "clayton"; cor = "Kendall")
  @test corkendall(x[:,1], x[:,2]) ≈ 0.6 atol=1.0e-3
  @test corkendall(x[:,2], x[:,3]) ≈ -0.2 atol=1.0e-3
end
@testset "rev copula" begin
  Random.seed!(43)
  x = simulate_copula(500000, rev_chain_archimedeans, [-0.9, 3., 2.], "clayton")
  # test obsolete dispatching
  Random.seed!(43)
  x1 = chaincopulagen(500000, [-0.9, 3., 2.], "clayton"; rev = true)
  @test norm(x - x1) ≈ 0.
  @test pvalue(ExactOneSampleKSTest(x[:,2], Uniform(0,1))) > α
  @test tail(x[:,3], x[:,4], "r") ≈ 1/(2^(1/2)) atol=1.0e-1
  @test tail(x[:,3], x[:,4], "l", 0.0001) ≈ 0
end

@testset "chain of Frechet copulas" begin
  @test fncopulagen([0.2, 0.4], [0.1, 0.1], [0.2 0.4 0.6; 0.3 0.5 0.7]) == [0.6 0.4 0.2; 0.7 0.5 0.3]
  Random.seed!(43)
  @test chain_frechet(1, [0.6, 0.4], [0.3, 0.5]) ≈ [0.888934  0.775377  0.180975] atol=1.0e-5
  Random.seed!(43)
  x = simulate_copula(500000, chain_frechet, [0.9, 0.6, 0.2])
  # test obsolete dispatching
  Random.seed!(43)
  x1 = chainfrechetcopulagen(500000, [0.9, 0.6, 0.2])
  @test norm(x - x1) ≈ 0.
  @test pvalue(ExactOneSampleKSTest(x[:,1], Uniform(0,1))) > α
  @test pvalue(ExactOneSampleKSTest(x[:,2], Uniform(0,1))) > α
  @test pvalue(ExactOneSampleKSTest(x[:,3], Uniform(0,1))) > α
  @test corspearman(x) ≈ [1. 0.9 0.6 0.2; 0.9 1. 0.6 0.2; 0.6 0.6 1. 0.2; 0.2 0.2 0.2 1.] atol=1.0e-2
  @test tail(x[:,1], x[:,2], "r") ≈ 0.9 atol=1.0e-1
  @test tail(x[:,1], x[:,2], "l") ≈ 0.9 atol=1.0e-1
  @test tail(x[:,1], x[:,4], "r") ≈ 0.2 atol=1.0e-1
  Random.seed!(43)
  x = simulate_copula(500000, chain_frechet, [0.8, 0.5], [0.2, 0.3]);
  @test pvalue(ExactOneSampleKSTest(x[:,1], Uniform(0,1))) > α
  @test pvalue(ExactOneSampleKSTest(x[:,2], Uniform(0,1))) > α
  @test pvalue(ExactOneSampleKSTest(x[:,3], Uniform(0,1))) > α
  @test corspearman(x) ≈ [1. 0.6 0.2; 0.6 1. 0.2; 0.2 0.2 1.] atol=1.0e-3
  @test tail(x[:,1], x[:,2], "r") ≈ 0.8 atol=1.0e-1
  @test tail(x[:,2], x[:,3], "r") ≈ 0.5 atol=1.0e-1
end
