module BifurcationKit
	using Printf, Dates, LinearMaps, BlockArrays, RecipesBase, StructArrays, Requires
	using Setfield: setproperties, @set, @set!, Lens, get, set, @lens
	using Parameters: @with_kw, @unpack, @with_kw_noshow
	using RecursiveArrayTools: VectorOfArray
	using DocStringExtensions
	using DataStructures: CircularBuffer
	using ForwardDiff


	include("BorderedArrays.jl")
	include("LinearSolver.jl")
	include("EigSolver.jl")
	include("LinearBorderSolver.jl")
	include("Preconditioner.jl")
	include("Newton.jl")
	include("ContParameters.jl")
	include("Results.jl")
	
	include("events/Event.jl")
	
	include("Continuation.jl")
	include("events/EventDetection.jl")
	include("events/BifurcationDetection.jl")

	include("Bifurcations.jl")
	include("Predictor.jl")

	include("DeflationOperator.jl")
	include("BorderedProblem.jl")

	include("Utils.jl")

	include("codim2/codim2.jl")
	include("codim2/MinAugFold.jl")
	include("codim2/MinAugHopf.jl")

	include("BifurcationPoints.jl")

	include("bifdiagram/BranchSwitching.jl")
	include("NormalForms.jl")
	include("bifdiagram/BifurcationDiagram.jl")

	include("DeflatedContinuation.jl")

	include("periodicorbit/Sections.jl")
	include("periodicorbit/PeriodicOrbits.jl")
	include("periodicorbit/PeriodicOrbitTrapeze.jl")
	include("periodicorbit/PeriodicOrbitCollocation.jl")
	# include("periodicorbit/PeriodicOrbitMIRK.jl")
	# include("periodicorbit/PeriodicOrbitFDAdapt.jl")
	include("periodicorbit/PeriodicOrbitUtils.jl")
	include("periodicorbit/Flow.jl")
	include("periodicorbit/StandardShooting.jl")
	include("periodicorbit/PoincareShooting.jl")
	include("periodicorbit/Floquet.jl")

	include("wave/WaveProblem.jl")

	include("plotting/Recipes.jl")
	include("Diffeqwrap.jl")

	using Requires

	function __init__()
		# if Plots.jl is available, then we allow plotting of solutions
		@require Plots="91a5bcdd-55d7-5caf-9e0b-520d859cae80" begin
			using .Plots
			include("plotting/PlotCont.jl")
		end
		@require AbstractPlotting="537997a7-5e4e-5d89-9595-2241ea00577e" begin
			using .AbstractPlotting: @recipe, inline!, layoutscene, Figure, Axis, lines!
			include("plotting/RecipesMakie.jl")
		end

		@require GLMakie="e9467ef8-e4e7-5192-8a1a-b1aee30e663a" begin
			@info "Loading GLMakie code"
			using .GLMakie: @recipe, inline!, layoutscene, Figure, Axis, lines!, PointBased, Point2f0, scatter!
			include("plotting/RecipesMakie.jl")
		end

		@require JLD2 = "033835bb-8acc-5ee8-8aae-3f567f8a3819" begin
			using .JLD2
			"""
			Save solution / data in JLD2 file
			- `filename` is for example "example.jld2"
			- `sol` is the solution
			- `p` is the parameter
			- `i` is the index of the solution to be saved
			"""
			function saveToFile(iter::AbstractContinuationIterable, sol, p, i::Int64, br::ContResult)
				if iter.contParams.saveToFile == false; return nothing; end
				filename = iter.filename
				try
					# create a group in the JLD format
					jldopen(filename*".jld2", "a+") do file
						mygroup = JLD2.Group(file, "sol-$i")
						mygroup["sol"] = sol
						mygroup["param"] = p
					end

					jldopen(filename*"-branch.jld2", "w") do file
						file["branch"] = br
					end
				catch
					@error "Could not save branch in the jld2 file"
				end
			end
		end

	end


	# linear solvers
	export DefaultLS, GMRESIterativeSolvers, GMRESKrylovKit,
			DefaultEig, EigArpack, EigIterativeSolvers, EigKrylovKit, EigArnoldiMethod, geteigenvector, AbstractEigenSolver

	# bordered nonlinear problems
	export BorderedProblem, JacobianBorderedProblem, LinearSolverBorderedProblem

	# preconditioner based on deflation
	export PrecPartialSchurKrylovKit, PrecPartialSchurArnoldiMethod

	# bordered linear problems
	export MatrixBLS, BorderingBLS, MatrixFreeBLS, LSFromBLS, BorderedArray

	# nonlinear deflation
	export DeflationOperator, DeflatedProblem, DeflatedLinearSolver, scalardM

	# predictors for continuation
	export SecantPred, BorderedPred, NaturalPred, MultiplePred, PolynomialPred

	# newton methods
	export NewtonPar, newton, newtonDeflated, newtonPALC, newtonFold, newtonHopf, newtonBordered

	# continuation methods
	export ContinuationPar, ContResult, GenericBifPoint, continuation, continuation!, continuationFold, continuationHopf, continuationPOTrap, continuationBordered, eigenvec, eigenvals

	# events
	export ContinuousEvent, DiscreteEvent, PairOfEvents, SetOfEvents, SaveAtEvent, FoldDetectEvent, BifDetectEvent

	# iterators for continuation
	export ContIterable, iterate, ContState, solution, getx, getp

	# codim2 Fold continuation
	export FoldPoint, FoldProblemMinimallyAugmented, FoldLinearSolveMinAug, foldPoint

	# codim2 Hopf continuation
	export HopfPoint, HopfProblemMinimallyAugmented, HopfLinearSolveMinAug

	# normal form
	export computeNormalForm, predictor

	# automatic bifurcation diagram
	export bifurcationdiagram, bifurcationdiagram!, Branch, BifDiagNode, getBranch, getBranchesFromBP

	# Periodic orbit computation
	export generateSolution, getPeriod, getAmplitude, getMaximum, getTrajectory, sectionSS, sectionPS

	# Periodic orbit computation based on Trapeze method
	export PeriodicOrbitTrapProblem, continuationPOTrap, continuationPOTrapBPFromPO

	# Periodic orbit computation based on Shooting
	export Flow, ShootingProblem, PoincareShootingProblem, continuationPOShooting, AbstractShootingProblem, SectionPS, SectionSS

	# Periodic orbit computation based on Collocation
	export PeriodicOrbitOCollProblem

	# Floquet multipliers computation
	export FloquetQaD

	# guess for periodic orbit from Hopf bifurcation point
	export guessFromHopf
end
