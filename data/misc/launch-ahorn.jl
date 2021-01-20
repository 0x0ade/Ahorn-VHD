env = ENV["AHORN_ENV"]
globalenv = ENV["AHORN_GLOBALENV"]

logfilePath = joinpath(mkpath(dirname(globalenv)), "error.log")

println("Logging to " * logfilePath)

logfile = open(logfilePath, "w")

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
using Ahorn
Ahorn.displayMainWindow()
