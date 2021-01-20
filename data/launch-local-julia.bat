@echo off
setlocal EnableDelayedExpansion
set "JULIA_DEPOT_PATH=%~dp0\julia-depot"
set "AHORN_GLOBALENV=%LocalAppData%\Ahorn\env"
set "AHORN_ENV=%~dp0\ahorn-env"
"%~dp0\julia\bin\julia.exe" %*
