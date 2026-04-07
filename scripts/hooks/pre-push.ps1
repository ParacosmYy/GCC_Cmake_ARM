$ErrorActionPreference = 'Stop'

$repoRoot = (& git rev-parse --show-toplevel).Trim()
if ([string]::IsNullOrWhiteSpace($repoRoot)) {
    throw 'Unable to determine repository root.'
}

Set-Location $repoRoot

$just = 'D:/DevEnv/just/just.exe'
if (-not (Test-Path $just)) {
    throw "just executable not found: $just"
}

Write-Host '[pre-push] Running static analysis gate (cppcheck on App/*)...'
& $just --justfile (Join-Path $repoRoot 'Justfile') check-static
if ($LASTEXITCODE -ne 0) {
    throw 'Static analysis gate failed.'
}

Write-Host '[pre-push] Static analysis gate passed.'
