@echo off
setlocal EnableDelayedExpansion
"%~dp0\launch-local-julia.bat" "%~dp0\misc\update-ahorn.jl" %*
