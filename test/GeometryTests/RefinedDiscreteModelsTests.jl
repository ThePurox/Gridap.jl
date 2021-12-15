module RefinedDiscreteModelsTests

using Test
using Random
using Gridap.Arrays
using Gridap.Fields
using Gridap.ReferenceFEs
using Gridap.Geometry
using Gridap.Geometry: DiscreteModelMock
using Gridap.Visualization
#using TimerOutputs


# For testing only
abstract type Estimator end

struct ConstantEst <: Estimator
  val::Float64
end

struct RandomEst <: Estimator
  function RandomEst(seed)
    Random.seed!(seed)
    new()
  end
end

# For testing only
compute_estimator(est::RandomEst, ncells) = rand(ncells)
compute_estimator(est::ConstantEst, ncells) = fill(est.val, ncells)

function refine_test(domain, partition, Nsteps, θ, est)
  model = CartesianDiscreteModel(domain, partition)
  model = simplexify(model)
  model_refs = Vector{DiscreteModel}(undef, Nsteps)
  cell_map = get_cell_map(get_triangulation(model))
  ncells = length(cell_map)
  η_arr = compute_estimator(est, ncells)
  model_refs[1] = newest_vertex_bisection(model, η_arr; sort_flag = true, θ = θ)
  for i = 1:Nsteps-1
    cell_map = get_cell_map(get_triangulation(model_refs[i]))
    ncells = length(cell_map)
    η_arr = compute_estimator(est, ncells)
    writevtk(Triangulation(model_refs[i]), "refined$(i)")
    model_refs[i+1] = newest_vertex_bisection(model_refs[i], η_arr; sort_flag = false, θ = θ)
  end
  model
end

domain = (0, 1, 0, 1)
partition = (1, 1) # Initial partition
seed = 5 # Arbitrary
Nsteps = 10
  est = ConstantEst(1.0)
θ = 0.5
model_ref = refine_test(domain, partition, Nsteps, θ, est)
@test model_ref isa DiscreteModel
end
