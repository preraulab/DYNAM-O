# Run benchmark_runDYNAMO in headless MATLAB (no desktop GUI, no CEF).
# Windows parity to run_benchmark.sh — same CLI surface, same defaults.
# The JSON is written without changing the Git index or history.
#
# Usage (from this dir or anywhere):
#     powershell -ExecutionPolicy Bypass -File run_benchmark.ps1
#     powershell -ExecutionPolicy Bypass -File run_benchmark.ps1 segment
#     powershell -ExecutionPolicy Bypass -File run_benchmark.ps1 night rust
#
# On Windows the MATLAB R2025b + Qt/CEF font bug observed on macOS 26
# hasn't been reported, but API parity with the shell script matters.

param(
    [string]$Fixture  = 'night',
    [string]$Backends = 'both'
)

$ErrorActionPreference = 'Stop'

switch ($Backends) {
    'rust'   { $backendsArg = "{'rust'}" }
    'matlab' { $backendsArg = "{'matlab'}" }
    default  { $backendsArg = "{'rust','matlab'}" }
}

$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$devRoot = Split-Path -Parent $here

# Find matlab.exe.
$matlab = Get-Command matlab -ErrorAction SilentlyContinue
if (-not $matlab) {
    $candidates = Get-ChildItem 'C:\Program Files\MATLAB\*\bin\matlab.exe' -ErrorAction SilentlyContinue |
                  Sort-Object FullName -Descending
    if ($candidates) { $matlab = $candidates[0] }
}
if (-not $matlab) {
    Write-Error 'matlab.exe not found on PATH or in C:\Program Files\MATLAB\*\bin\.'
    exit 1
}
$matlabPath = if ($matlab -is [System.IO.FileInfo]) { $matlab.FullName } else { $matlab.Source }
Write-Host "MATLAB: $matlabPath"
Write-Host "Fixture: $Fixture"
Write-Host "Backends: $backendsArg"

$cmd = "addpath(genpath('$devRoot')); " +
       "cd('$here'); " +
       "benchmark_runDYNAMO('fixture','$Fixture','backends',$backendsArg,'push','no'); " +
       "exit"

& $matlabPath -batch $cmd
exit $LASTEXITCODE
