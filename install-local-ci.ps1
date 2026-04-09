param(
    [Parameter(Mandatory = $true)]
    [string]$TargetProject,

    [switch]$Force,
    [string]$ProjectName,
    [string]$ArtifactBaseName,
    [string]$OpenOcdInterfaceCfg = "interface/cmsis-dap.cfg",
    [string]$OpenOcdTargetCfg = "target/stm32h7x.cfg"
)

$ErrorActionPreference = "Stop"

$templateRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$templateVersionPath = Join-Path $templateRoot ".local-ci\template-version.json"

$strongFiles = @(
    ".clangd",
    ".clang-format",
    "lefthook.yml",
    ".local-ci\template-version.json"
)

$copyManagedFiles = @(
    ".vscode\tasks.json",
    ".vscode\settings.json"
)

$managedDirectories = @(
    "Scripts\ci",
    "Scripts\hooks"
)

$legacyPaths = @(
    ".vscode\extensions.json",
    ".local-ci\config.schema.json",
    "Scripts\hooks\pre_push.py"
)

function Write-Step {
    param([string]$Message)

    Write-Host "[local-ci] $Message" -ForegroundColor Cyan
}

function Write-Notice {
    param([string]$Message)

    Write-Host "[info] $Message" -ForegroundColor Green
}

function Write-WarningLine {
    param([string]$Message)

    Write-Host "[warning] $Message" -ForegroundColor Yellow
}

function Backup-IfExists {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$Path.bak.$timestamp"
    Move-Item -LiteralPath $Path -Destination $backupPath -Force
    Write-Host "[backup] $Path -> $backupPath" -ForegroundColor Yellow
}

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Write-Utf8NoBomFile {
    param(
        [string]$Path,
        [string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Read-JsonFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Should-CopyTemplateRelativePath {
    param([string]$RelativePath)

    $normalized = $RelativePath.Replace("/", "\")
    if ($normalized -like "*\__pycache__\*") {
        return $false
    }
    if ($normalized.EndsWith(".pyc")) {
        return $false
    }
    return $true
}

function Copy-TemplateFile {
    param(
        [string]$RelativePath,
        [bool]$BackupExisting = $true
    )

    $sourcePath = Join-Path $templateRoot $RelativePath
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Template file not found: $RelativePath"
    }

    $targetPath = Join-Path $targetRoot $RelativePath
    Ensure-Directory (Split-Path -Parent $targetPath)
    if ($BackupExisting -and (Test-Path -LiteralPath $targetPath)) {
        Backup-IfExists $targetPath
    }
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
    Write-Step "Copied $RelativePath"
}

function Sync-TemplateDirectory {
    param(
        [string]$RelativePath,
        [bool]$BackupExisting = $true
    )

    $sourceDir = Join-Path $templateRoot $RelativePath
    if (-not (Test-Path -LiteralPath $sourceDir)) {
        throw "Template directory not found: $RelativePath"
    }

    $sourceFiles = Get-ChildItem -LiteralPath $sourceDir -Recurse -File
    foreach ($sourceFile in $sourceFiles) {
        $relativeFile = $sourceFile.FullName.Substring($templateRoot.Length).TrimStart("\", "/")
        if (-not (Should-CopyTemplateRelativePath -RelativePath $relativeFile)) {
            continue
        }
        Copy-TemplateFile -RelativePath $relativeFile -BackupExisting:$BackupExisting
    }

    Write-Step "Synced $RelativePath"
}

function Read-CMakeProjectName {
    param([string]$ProjectRoot)

    $cmakeLists = Join-Path $ProjectRoot "CMakeLists.txt"
    if (-not (Test-Path -LiteralPath $cmakeLists)) {
        return $null
    }

    $content = Get-Content -LiteralPath $cmakeLists -Raw
    $setMatch = [regex]::Match($content, "set\s*\(\s*CMAKE_PROJECT_NAME\s+([A-Za-z0-9_]+)\s*\)")
    if ($setMatch.Success) {
        return $setMatch.Groups[1].Value
    }

    $projectMatch = [regex]::Match($content, "project\s*\(\s*([A-Za-z0-9_]+)")
    if ($projectMatch.Success) {
        return $projectMatch.Groups[1].Value
    }

    return $null
}

function Test-CommandAvailable {
    param([string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    return $null -ne $command
}

function Show-EnvironmentHints {
    foreach ($commandName in @("py", "cmake", "clangd")) {
        if (Test-CommandAvailable -Name $commandName) {
            Write-Notice "Detected command in PATH: $commandName"
        } else {
            Write-WarningLine "Command not found in PATH: $commandName"
        }
    }
}

function Get-Stm32ProjectMarkers {
    param([string]$ProjectRoot)

    $markers = @()
    if (Get-ChildItem -LiteralPath $ProjectRoot -Filter "*.ioc" -File -ErrorAction SilentlyContinue) {
        $markers += "*.ioc"
    }
    if (Test-Path -LiteralPath (Join-Path $ProjectRoot "Core")) {
        $markers += "Core/"
    }
    if (Test-Path -LiteralPath (Join-Path $ProjectRoot "Drivers")) {
        $markers += "Drivers/"
    }
    if (Get-ChildItem -LiteralPath $ProjectRoot -Filter "startup_*.s" -File -ErrorAction SilentlyContinue) {
        $markers += "startup_*.s"
    }
    if (Get-ChildItem -LiteralPath $ProjectRoot -Filter "STM32*.ld" -File -ErrorAction SilentlyContinue) {
        $markers += "STM32*.ld"
    }

    return $markers | Select-Object -Unique
}

function Render-TemplateContent {
    param([string]$Content)

    $rendered = $Content.Replace("__PROJECT_NAME__", $resolvedProjectName)
    $rendered = $rendered.Replace("__ARTIFACT_BASE_NAME__", $resolvedArtifactBaseName)
    $rendered = $rendered.Replace("__OPENOCD_INTERFACE_CFG__", $OpenOcdInterfaceCfg)
    $rendered = $rendered.Replace("__OPENOCD_TARGET_CFG__", $OpenOcdTargetCfg)
    return $rendered
}

if (-not (Test-Path -LiteralPath $templateVersionPath)) {
    throw "Template version file not found: $templateVersionPath"
}

if (-not (Test-Path -LiteralPath $TargetProject)) {
    throw "Target project does not exist: $TargetProject"
}

$targetRoot = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $TargetProject).Path)

if ($targetRoot -eq $templateRoot) {
    throw "Target project must be an existing STM32 project, not the template repository itself."
}

$templateVersion = Read-JsonFile -Path $templateVersionPath
if ($null -eq $templateVersion) {
    throw "Unable to read template version file: $templateVersionPath"
}

$targetConfigPath = Join-Path $targetRoot ".local-ci\config.json"
$targetVersionPath = Join-Path $targetRoot ".local-ci\template-version.json"
$existingTargetVersion = Read-JsonFile -Path $targetVersionPath

$markers = Get-Stm32ProjectMarkers -ProjectRoot $targetRoot
if (-not $markers -or $markers.Count -eq 0) {
    if ($Force) {
        Write-WarningLine "Target does not look like an STM32 project yet. Continuing because -Force was supplied."
    } else {
        throw "Target does not look like an STM32 project. Expected one of: *.ioc, Core/, Drivers/, startup_*.s, STM32*.ld. Re-run with -Force to continue anyway."
    }
} else {
    Write-Notice ("Detected STM32 project markers: " + ($markers -join ", "))
}

$resolvedProjectName = $ProjectName
if ([string]::IsNullOrWhiteSpace($resolvedProjectName)) {
    $resolvedProjectName = Read-CMakeProjectName -ProjectRoot $targetRoot
}
if ([string]::IsNullOrWhiteSpace($resolvedProjectName)) {
    $resolvedProjectName = Split-Path -Leaf $targetRoot
}

$resolvedArtifactBaseName = $ArtifactBaseName
if ([string]::IsNullOrWhiteSpace($resolvedArtifactBaseName)) {
    $resolvedArtifactBaseName = $resolvedProjectName
}

Write-Step "Template root : $templateRoot"
Write-Step "Target root   : $targetRoot"
Write-Step "Project name  : $resolvedProjectName"
Write-Step "Artifact name : $resolvedArtifactBaseName"
Write-Step "OpenOCD iface : $OpenOcdInterfaceCfg"
Write-Step "OpenOCD target: $OpenOcdTargetCfg"
Write-Step "Template name : $($templateVersion.template_name)"
Write-Step "Template ver  : $($templateVersion.template_version)"

if ($null -ne $existingTargetVersion) {
    Write-Notice "Detected existing template marker in target project."
    Write-Notice "Target template version : $($existingTargetVersion.template_version)"
    Write-Notice "Incoming template version: $($templateVersion.template_version)"
}

if (Test-Path -LiteralPath $targetConfigPath) {
    Write-WarningLine "Detected existing local CI config. This run will upgrade the template layer and back up overwritten local-entry files."
}

Show-EnvironmentHints

if (-not (Test-Path -LiteralPath (Join-Path $targetRoot "CMakeLists.txt"))) {
    Write-WarningLine "Target project does not contain CMakeLists.txt yet. Build commands will not work until the project layer is ready."
}

if (-not (Test-Path -LiteralPath (Join-Path $targetRoot "CMakePresets.json"))) {
    Write-WarningLine "Target project does not contain CMakePresets.json yet. VS Code build tasks will not work until the project layer is ready."
}

foreach ($relativePath in $strongFiles) {
    Copy-TemplateFile -RelativePath $relativePath -BackupExisting:$true
}

foreach ($relativePath in $managedDirectories) {
    Sync-TemplateDirectory -RelativePath $relativePath -BackupExisting:$true
}

foreach ($relativePath in $copyManagedFiles) {
    Copy-TemplateFile -RelativePath $relativePath -BackupExisting:$true
}

$configTemplatePath = Join-Path $templateRoot ".local-ci\config.json"
Ensure-Directory (Split-Path -Parent $targetConfigPath)
if (Test-Path -LiteralPath $targetConfigPath) {
    Backup-IfExists $targetConfigPath
}
$configContent = Get-Content -LiteralPath $configTemplatePath -Raw
Write-Utf8NoBomFile -Path $targetConfigPath -Content (Render-TemplateContent -Content $configContent)
Write-Step "Generated .local-ci/config.json"

$launchTemplatePath = Join-Path $templateRoot ".vscode\launch.json"
$launchTargetPath = Join-Path $targetRoot ".vscode\launch.json"
Ensure-Directory (Split-Path -Parent $launchTargetPath)
if (Test-Path -LiteralPath $launchTargetPath) {
    Backup-IfExists $launchTargetPath
}
$launchContent = Get-Content -LiteralPath $launchTemplatePath -Raw
Write-Utf8NoBomFile -Path $launchTargetPath -Content (Render-TemplateContent -Content $launchContent)
Write-Step "Generated .vscode/launch.json"

foreach ($relativePath in $legacyPaths) {
    $legacyPath = Join-Path $targetRoot $relativePath
    if (Test-Path -LiteralPath $legacyPath) {
        Remove-Item -LiteralPath $legacyPath -Force
        Write-Step "Removed legacy file $relativePath"
    }
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "1. Run D:\DevEnv\install_env.ps1 if this machine is not prepared yet."
Write-Host "2. Reopen your terminal or VS Code."
Write-Host "3. Review .local-ci/config.json, .local-ci/template-version.json, and .vscode/launch.json in the target project."
Write-Host "4. In the target project run:"
Write-Host "   py -3 Scripts/ci/main.py init"
Write-Host "   py -3 Scripts/ci/main.py build --preset Debug"
Write-Host "   py -3 Scripts/ci/main.py check"
