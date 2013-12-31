# We have different sources for problem functions:
#  S1 = CEC 2013 competition on large-scale optimization
#  S2 = JADE paper http://150.214.190.154/EAMHCO/pdf/JADE.pdf
#  S3 = "Test Suite for the Special Issue of Soft Computing on Scalability of 
#        Evolutionary Algorithms and other Metaheuristics for Large Scale 
#        Continuous Optimization Problems", http://sci2s.ugr.es/eamhco/functions1-19.pdf
# Our primary focus is to implement all the problems from S1 since our
# focus is on large-scale optimization but these problems also can be used
# in lower dimensions.

#####################################################################
# Base functions.
#####################################################################
function sphere(x)
  sum(x.^2)
end

function elliptic(x)
  D = length(x)
  condition = 1e+6
  coefficients = condition .^ linspace(0, 1, D)
  sum(coefficients .* x.^2)
end

function rastrigin(x)
  D = length(x)
  10 * D + sum( x.^2 ) - 10 * sum( cos( 2 * π * x ) )
end

function ackley(x)
  D = length(x)
  20 - 20.*exp(-0.2.*sqrt(sum(x.^2)/D)) - exp(sum(cos(2 * π * x))/D) + e
end

function schwefel1_2(x)
  D = length(x)
  partsums = zeros(D)
  partsum = 0
  for i in 1:D
    partsum += x[i]
    partsums[i] = partsum
  end
  sum(partsums.^2)
end

function rosenbrock(x)
  n = length(x)
  return( sum( 100*( x[2:n] - x[1:(n-1)].^2 ).^2 + ( x[1:(n-1)] - 1 ).^2 ) )
end

function step(x)
  sum(ceil(x + 0.5))
end

function griewank(x)
  n = length(x)
  1 + (1/4000)*sum(x.^2) - prod(cos(x ./ sqrt(1:n)))
end

function schwefel2_22(x)
  ax = abs(x)
  sum(ax) + prod(ax)
end

function schwefel2_21(x)
  maximum(abs(x))
end

# I'm unsure about this one since it does not return the expected minima at
# [1.0, 1.0].
function schwefel2_26(x)
  D = length(x)
  418.98288727243369 * D - sum(x .* sin(sqrt(abs(x))))
end

function cigar(x)
  x[1]^2 + 1e6 * sum(x[2:end].^2)
end

function cigtab(x)
  x[1]^2 + 1e8 * x[end]^2 + 1e4 * sum(x[2:(end-1)].^2)
end


#####################################################################
# S2 functions in addition to the base functions above. As stated
# in table II of the JADE paper: http://150.214.190.154/EAMHCO/pdf/JADE.pdf
#####################################################################

function quartic(x)
  D = length(x)
  sum( (1:D) .* x.^4 )
end

function noisy_quartic(x)
  quartic(x) + rand()
end

function s2_step(x)
  sum( ceil(x + 0.5).^2 )
end

# We skip (for now) f12 and f13 in the JADE paper since they are penalized 
# functions which are quite nonstandard. We also skip f8 since we are unsure
# about its proper implementation.
JadeFunctionSet = {
  1   => anydim_problem("Sphere",        sphere,        (-100.0, 100.0), 0.0),
  2   => anydim_problem("Schwefel2.22",  schwefel2_22,  ( -10.0,  10.0), 0.0),
  3   => anydim_problem("Schwefel1.2",   schwefel1_2,   (-100.0, 100.0), 0.0),
  4   => anydim_problem("Schwefel2.21",  schwefel2_21,  (-100.0, 100.0), 0.0),
  5   => anydim_problem("Rosenbrock",    rosenbrock,    ( -30.0,  30.0), 0.0),
  6   => anydim_problem("Step",          s2_step,       (-100.0, 100.0), 0.0),
  7   => anydim_problem("Noisy quartic", noisy_quartic, ( -30.0,  30.0)),
#  8   => anydim_problem("Schwefel2.26",  schwefel2_26,  (-500.0, 500.0)),
  9   => anydim_problem("Rastrigin",     rastrigin,     ( -5.12,  5.12), 0.0),
  10  => anydim_problem("Ackley",        ackley,        ( -32.0,  32.0), 0.0),
  11  => anydim_problem("Griewank",      griewank,      (-600.0, 600.0), 0.0)
}

# For compatibility with old default function set... (Temporary)
example_problems = {
  "Sphere" => JadeFunctionSet[1],
  "Rosenbrock" => JadeFunctionSet[5],
  "Schwefel2.22" => JadeFunctionSet[2],
  "Schwefel1.2" => JadeFunctionSet[3],
  "Schwefel2.21" => JadeFunctionSet[4]
}


#####################################################################
# S3 Base functions.
#####################################################################


#####################################################################
# S3 Transformations
#####################################################################

# A TransformedProblem just makes a few changes in a sub-problem but refers
# most func calls to it. Concrete types must implement a sub_problem func.
abstract TransformedProblem <: OptimizationProblem
search_space(tp::TransformedProblem) = search_space(sub_problem(tp))
is_fixed_dimensional(tp::TransformedProblem) = is_fixed_dimensional(sub_problem(tp))
numfuncs(tp::TransformedProblem) = numfuncs(sub_problem(tp))
numdims(tp::TransformedProblem) = numdims(sub_problem(tp))

# A ShiftedAndBiasedProblem shifts the minimum value and biases the returned 
# function values.
type ShiftedAndBiasedProblem <: TransformedProblem
  xshift::Array{Float64, 1}
  funcshift::Float64
  subp::OptimizationProblem

  ShiftedAndBiasedProblem(sub_problem::OptimizationProblem; 
    xshift = false, funcshift = 0.0) = begin
    xshift = (xshift != false) ? xshift : rand_individual(search_space(sub_problem))
    new(xshift[:], funcshift, sub_problem)
  end
end

sub_problem(sp::ShiftedAndBiasedProblem) = sp.subp

# Evaluate by first shifting x and then biasing the returned function value.
evalfunc(x, i::Int64, sp::ShiftedAndBiasedProblem) = begin
  ofunc(sub_problem(sp), i)(x - sp.xshift) + sp.funcshift
end

shifted(p::OptimizationProblem) = ShiftedAndBiasedProblem(p)

#####################################################################
# S1 Base functions. Typically slightly transformed to break symmetry
#   and introduce irregularities.
#####################################################################
s1_sphere = sphere

function s1_elliptic(x)
  xt = t_irreg(x)
  elliptic(xt)
end

function s1_rastrigin(x)
  xt = t_diag(t_asy(t_irreg(x), 0.2), 10)
  rastrigin(xt)
end

function s1_ackley(x)
  xt = t_diag(t_asy(t_irreg(x), 0.2), 10)
  ackley(xt)
end

function s1_schwefel(x)
  xt = t_asy(t_irreg(x), 0.2)
  schwefel1_2(xt)
end

s1_rosenbrock = rosenbrock


#####################################################################
# S1 Transformations
#####################################################################

# This transformation function is used to break the symmetry of symmetric 
# functions.
function t_asy(f, beta)
  D = length(f)
  g = copy(f)
  temp = beta * linspace(0, 1, D) 
  ind = collect(1:D)[f .> 0]
  t = f[ind] .^ (1 + temp[ind] .* sqrt(f[ind]))
  setindex!(g, t, ind)
  g
end

# This transformation is used to create the ill-conditioning effect.
function t_diag(f, alpha)
  D = length(f)
  scales = sqrt(alpha) .^ linspace(0, 1, D)
  scales .* f
end

# This transformation is used to create smooth local irregularities.
function t_irreg(f)
   a = 0.1
   g = copy(f)
   indices = collect(1:length(f))

   idxp = indices[f .> 0]
   t = log(f[idxp])/a
   r = exp(t + 0.49*(sin(t) + sin(0.79*t))).^a
   setindex!(g, r, idxp)

   idxn = indices[f .< 0]
   t = log(-f[idxn])/a
   r = -exp(t + 0.49*(sin(0.55*t) + sin(0.31*t))).^a
   setindex!(g, r, idxn)

   g
end

function xshifted(n, f)
  move = 10.0 * randn(n, 1)
  transformed_f(x) = f(x .- move)
end


#####################################################################
# Misc other interesting optimization functions and families.
#####################################################################

# This is a generator for the family of deceptive functions from the 
# Cuccu2011 paper on novelty-based restarts. We have vectorized it to allow
# more than 1D versions. The Cuccu2011 paper uses the following values for
# (l, w) = [(5, 0),  (15, 0),  (30, 0), 
#           (5, 2),  (15, 2),  (30, 2), 
#           (5, 10), (15, 10), (30, 10)]
# and notes that (15, 2) and (30, 2) are the most difficult instances.
function deceptive_cuccu2011(l, w)
  (x) -> begin
    absx = abs(x)
    sumabsx = sum(absx)
    if sumabsx <= 1
      return sum(x.^2)
    elseif sumabsx >= l+1
      return sum((absx - l).^2)
    else
      return (1 - 0.5 * sum(sin( (π * w * (absx - 1)) / l ).^2))
    end
  end
end

# Deceptive/hardest instances:
deceptive_cuccu2011_15_2 = deceptive_cuccu2011(15, 2)
deceptive_cuccu2011_30_2 = deceptive_cuccu2011(30, 2)
