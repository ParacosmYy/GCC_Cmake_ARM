$ErrorActionPreference = 'Stop'

$repoRoot = (& git rev-parse --show-toplevel).Trim()
if ([string]::IsNullOrWhiteSpace($repoRoot)) {
    throw 'Unable to determine repository root.'
}

Set-Location $repoRoot

$clangFormat = 'D:/DevEnv/llvm/bin/clang-format.exe'
if (-not (Test-Path $clangFormat)) {
    throw "clang-format not found: $clangFormat"
}

Write-Host '[pre-commit] Checking staged diff for whitespace issues and conflict markers...'
$diffCheck = & git diff --cached --check 2>&1
if ($LASTEXITCODE -ne 0) {
    $diffCheck | ForEach-Object { Write-Host $_ }
    throw 'Staged changes contain whitespace errors or conflict markers.'
}

$stagedFiles = @(& git diff --cached --name-only --diff-filter=ACMR --)
$stagedFiles = $stagedFiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

if ($stagedFiles.Count -eq 0) {
    Write-Host '[pre-commit] No staged files detected. Skipping quick checks.'
    exit 0
}

$formatCandidates = New-Object System.Collections.Generic.List[string]
$jsonCandidates = New-Object System.Collections.Generic.List[string]

foreach ($file in $stagedFiles) {
    $normalized = $file.Replace('\', '/')

    if ($normalized -match '^App/Inc/.+\.h$' -or $normalized -match '^App/Src/.+\.c$') {
        $formatCandidates.Add($file)
    }

    if ($normalized -eq 'CMakePresets.json' -or $normalized -match '^\.vscode/.+\.json$') {
        $jsonCandidates.Add($file)
    }
}

foreach ($file in $formatCandidates) {
    $unstaged = @(& git diff --name-only -- $file)
    $unstaged = $unstaged | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($unstaged.Count -gt 0) {
        throw "File '$file' has unstaged changes. Please stage or stash the whole file before auto-formatting."
    }
}

foreach ($file in $jsonCandidates) {
    $absolutePath = Join-Path $repoRoot $file
    Write-Host "[pre-commit] Validating JSON: $file"
    $rawContent = Get-Content -LiteralPath $absolutePath -Raw
    $null = $rawContent | ConvertFrom-Json
}

$formattedFiles = New-Object System.Collections.Generic.List[string]

foreach ($file in $formatCandidates) {
    $absolutePath = Join-Path $repoRoot $file
    if (-not (Test-Path $absolutePath)) {
        continue
    }

    $beforeHash = (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash
    & $clangFormat -i --style=file $absolutePath
    if ($LASTEXITCODE -ne 0) {
        throw "clang-format failed for '$file'."
    }

    $afterHash = (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash
    if ($beforeHash -ne $afterHash) {
        $formattedFiles.Add($file)
        & git add -- $file
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to re-stage formatted file '$file'."
        }
    }
}

foreach ($file in $formatCandidates) {
    $absolutePath = Join-Path $repoRoot $file
    if (-not (Test-Path $absolutePath)) {
        continue
    }

    & $clangFormat --dry-run --Werror --style=file $absolutePath
    if ($LASTEXITCODE -ne 0) {
        throw "Formatting verification failed for '$file'. Please review the file and try again."
    }
}

if ($formattedFiles.Count -gt 0) {
    Write-Host '[pre-commit] Auto-formatted and re-staged user-owned files:'
    $formattedFiles | ForEach-Object { Write-Host "  - $_" }
}
else {
    Write-Host '[pre-commit] No staged App files required formatting.'
}

Write-Host '[pre-commit] Quick checks passed.'
