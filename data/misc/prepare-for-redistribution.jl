env = ENV["AHORN_ENV"]

redirect_stderr(stdout)


using Pkg
Pkg.activate(env)

ahornPath = Base.find_package("Ahorn")

infofilePath = joinpath(dirname(env), "info.txt")
open(infofilePath, "a") do info
	println(info, "")
	println(info, "Additional info:")
	println(info, "Ahorn install path: $(something(ahornPath, "?"))")
	try
		local ctx = Pkg.Types.Context()
		println(info, "Ahorn version: $(string(ctx.env.manifest[ctx.env.project.deps["Ahorn"]].tree_hash)[1:7])")
	catch e
		println(info, "Ahorn version: unknown")
	end
end

if ahornPath === nothing then
	return
end

depot = joinpath(dirname(env), "julia-depot")

rm(joinpath(depot, "clones"), force = true, recursive = true)

compiled = joinpath(depot, "v" * match(r"^\d+\.\d+", string(VERSION)).match)
rm(joinpath(compiled, "Maple"), force = true, recursive = true)
rm(joinpath(compiled, "Ahorn"), force = true, recursive = true)

packages = joinpath(depot, "packages")
rm(joinpath(packages, "Maple"), force = true, recursive = true)
rm(joinpath(packages, "Ahorn"), force = true, recursive = true)
