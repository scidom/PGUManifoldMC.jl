using Distributions
using Klara

CURRENTDIR, CURRENTFILE = splitdir(@__FILE__)
ROOTDIR = splitdir(splitdir(splitdir(CURRENTDIR)[1])[1])[1]
SRCDIR = joinpath(ROOTDIR, "src")
DATADIR = joinpath(ROOTDIR, "data")
OUTDIR = joinpath(ROOTDIR, "output", "two_planets")

# SRCDIR = "../../src"
# DATADIR = "../../data"
# OUTDIR = "../../output/two_planets"

SUBOUTDIR = "AM"

include(joinpath(SRCDIR, "rv_model.jl"))
include(joinpath(SRCDIR, "utils_ex.jl"))

using RvModelKeplerian

nchains = 10
nmcmc = 110000
nburnin = 10000

dataset = readdlm(joinpath(DATADIR, "two_planets.csv"), ',', header=false); # read observational data
obs_times = dataset[:, 1]
obs_rv = dataset[:, 2]
sigma_obs = dataset[:, 3]
set_times(obs_times); # set data to use for model evaluation
set_obs(obs_rv);
set_sigma_obs(sigma_obs);

param_true = make_param_true_ex2()
param_perturb_scale = make_param_perturb_scale(param_true)

p = BasicContMuvParameter(:p, logtarget=plogtarget, diffopts=DiffOptions(mode=:forward))

model = likelihood_model(p, false)

sampler = AM(0.02, 11, minorscale=0.001, c=0.01)

mcrange = BasicMCRange(nsteps=nmcmc, burnin=nburnin)

outopts = Dict{Symbol, Any}(:monitor=>[:value], :diagnostics=>[:accept])

times = Array{Float64}(nchains)
stepsizes = Array{Float64}(nchains)
i = 1

while i <= nchains
  param_init = param_true.+0.01*param_perturb_scale.*randn(length(param_true))
  v0 = Dict(:p=>param_init)

  job = BasicMCJob(model, sampler, mcrange, v0, outopts=outopts)

  tic()
  run(job)
  runtime = toc()

  chain = output(job)
  ratio = acceptance(chain)

  if 0.00001 < ratio < 0.37
    writedlm(joinpath(OUTDIR, SUBOUTDIR, "chain"*lpad(string(i), 2, 0)*".csv"), chain.value, ',')
    writedlm(joinpath(OUTDIR, SUBOUTDIR, "diagnostics"*lpad(string(i), 2, 0)*".csv"), vec(chain.diagnosticvalues), ',')

    times[i] = runtime
    stepsizes[i] = job.sstate.tune.step

    println("Iteration ", i, " of ", nchains, " completed with acceptance ratio ", ratio)
    i += 1
  end
end

writedlm(joinpath(OUTDIR, SUBOUTDIR, "times.csv"), times, ',')
writedlm(joinpath(OUTDIR, SUBOUTDIR, "stepsizes.csv"), stepsizes, ',')
