# Manages the objective function evaluation
# P is the optimization problem it is used for
abstract Evaluator{P <: OptimizationProblem}

fitness_scheme(e::Evaluator) = fitness_scheme(problem(e))
worst_fitness(e::Evaluator) = worst_fitness(fitness_scheme(e))
numdims(e::Evaluator) = numdims(problem(e))
search_space(e::Evaluator) = search_space(problem(e))
describe(e::Evaluator) = "Problem: $(name(e.problem)) (dimensions = $(numdims(e)))"
problem_summary(e::Evaluator) = "$(name(e.problem))_$(numdims(e))d"

# Default implementation of the evaluator
# FIXME F is the fitness type of the problem, but with current Julia it's
# not possible to get and use it at declaration type
type ProblemEvaluator{F, P<:OptimizationProblem} <: Evaluator{P}
  problem::P
  archive::Archive
  num_evals::Int
  last_fitness::F
end

function ProblemEvaluator{P<:OptimizationProblem}(
        problem::P;
        archiveCapacity::Int = 10 )
    ProblemEvaluator{fitness_type(fitness_scheme(problem)), P}(problem,
        TopListArchive(numdims(problem), archiveCapacity),
        0, nafitness(fitness_scheme(problem)))
end

problem(e::Evaluator) = e.problem
num_evals(e::ProblemEvaluator) = e.num_evals

# evaluates the fitness (and implicitly updates the stats)
function fitness(params::Individual, e::ProblemEvaluator)
  e.last_fitness = fitness(params, e.problem)
  e.num_evals += 1
  add_candidate!(e.archive, e.last_fitness, params, e.num_evals)
  e.last_fitness
end

# A way to get the fitness of the last evaluated candidate. Leads to nicer
# code if we can first test if better than or worse than existing candidates
# and only want the fitness itself if the criteria fulfilled.
last_fitness(e::Evaluator) = e.last_fitness

is_better{F}(f1::F, f2::F, e::Evaluator) = is_better(f1, f2, fitness_scheme(e))

is_better(candidate, f, e::Evaluator) = is_better(fitness(candidate, e), f, fitness_scheme(e))

function best_of(candidate1::Individual, candidate2::Individual, e::Evaluator)
  f1 = fitness(candidate1, e)
  f2 = fitness(candidate2, e)
  if is_better(f1, f2, e)
    return candidate1, f1
  else
    return candidate2, f2
  end
end

# Candidate for the introduction into the population
type Candidate{F}
    params::Individual
    index::Int           # index of individual in the population, -1 if unassigned
    fitness::F           # fitness

    Candidate(params::Individual, index::Int = -1,
              fitness::F = NaN) = new(params, index, fitness)
end

Base.copy{F}(c::Candidate{F}) = Candidate{F}(copy(c.params), c.index, c.fitness)

function Base.copy!{F}(c::Candidate{F}, o::Candidate{F})
  copy!(c.params, o.params)
  c.index = o.index
  c.fitness = o.fitness # FIXME if vector?
  return c
end

function rank_by_fitness!{F,P<:OptimizationProblem}(e::Evaluator{P}, candidates::Vector{Candidate{F}})
  fs = fitness_scheme(e)
  for i in eachindex(candidates)
      # evaluate fitness if not known yet
      if isnafitness(candidates[i].fitness, fs)
          candidates[i].fitness = fitness(candidates[i].params, e)
      end
  end

  sort!(candidates; by = c -> c.fitness, lt = (x, y) -> is_better(x, y, fs))
end

fitness_is_within_ftol(e::Evaluator, atol) = fitness_is_within_ftol(problem(e), best_fitness(e.archive), atol)
