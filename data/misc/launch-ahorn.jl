env = ENV["AHORN_ENV"]
globalenv = ENV["AHORN_GLOBALENV"]

logfilePath = joinpath(mkpath(dirname(globalenv)), "error.log")

println("Logging to " * logfilePath)

logfile = open(logfilePath, "w")
println(logfile, "Running Ahorn from a virtual disk image.")

flush(stdout)
flush(stderr)

stdoutReal = stdout
(rd, wr) = redirect_stdout()
redirect_stderr(stdout)

@async while !eof(rd)
    data = String(readavailable(rd))
    print(stdoutReal, data)
    flush(stdoutReal)
    print(logfile, data)
    flush(logfile)
end

using Pkg
Pkg.activate(env)

install_or_update(url::String, pkg::String) = if "Ahorn" ∈ keys(Pkg.Types.Context().env.project.deps)
    println("Updating $pkg...")
    Pkg.update(pkg)
else
    println("Adding $pkg...")
    Pkg.add(PackageSpec(url = url))
end

if Base.find_package("Ahorn") === nothing
    Pkg.instantiate()

    install_or_update("https://github.com/CelestialCartographers/Maple.git", "Maple")
    install_or_update("https://github.com/CelestialCartographers/Ahorn.git", "Ahorn")

    Pkg.instantiate()
    Pkg.API.precompile()
end

using Ahorn
Ahorn.displayMainWindow()
