param(
  [Parameter(Mandatory = $true)]
  [string]$TargetProject,

  [ValidateSet("Install", "Upgrade", "Repair")]
  [string]$Mode,

  [switch]$Preview,
  [switch]$Force,

  [string]$ProjectName,
  [string]$ArtifactBaseName,

  [ValidateSet("H7", "G4", "F4")]
  [string]$ChipFamily,

  [ValidateSet("CmsisDap", "StLink", "JLink")]
  [string]$ProbeInterface,

  [string]$OpenOcdTargetCfg,
  [string]$OpenOcdInterfaceCfg
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Write-Step {
  param([string]$Message)
  Write-Host "[步骤] $Message" -ForegroundColor Cyan
}

function Write-Info {
  param([string]$Message)
  Write-Host "[信息] $Message" -ForegroundColor Green
}

function Write-WarnLine {
  param([string]$Message)
  Write-Host "[警告] $Message" -ForegroundColor Yellow
}

function Write-ErrorLine {
  param([string]$Message)
  Write-Host "[错误] $Message" -ForegroundColor Red
}

function Normalize-RelativePath {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return ""
  }

  $normalized = $Path.Replace("/", "\")
  while ($normalized.StartsWith(".\")) {
    $normalized = $normalized.Substring(2)
  }
  return $normalized.TrimStart("\")
}

function Get-FullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path)
}

function Ensure-Directory {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Remove-PathIfExists {
  param([string]$Path)
  if (Test-Path -LiteralPath $Path) {
    Remove-Item -LiteralPath $Path -Recurse -Force
  }
}

function Test-IsSameOrChildPath {
  param(
    [string]$ParentPath,
    [string]$ChildPath
  )

  $parent = (Get-FullPath -Path $ParentPath).TrimEnd("\")
  $child = Get-FullPath -Path $ChildPath
  return (
    $child.Equals($parent, [System.StringComparison]::OrdinalIgnoreCase) -or
    $child.StartsWith($parent + "\", [System.StringComparison]::OrdinalIgnoreCase)
  )
}

function Get-RelativePathFromRoot {
  param(
    [string]$Root,
    [string]$Child
  )

  $rootUri = [System.Uri]((Get-FullPath -Path $Root).TrimEnd("\") + "\")
  $childUri = [System.Uri](Get-FullPath -Path $Child)
  return [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($childUri).ToString()).Replace("/", "\")
}

function ConvertTo-Hashtable {
  param([object]$Value)

  if ($null -eq $Value) {
    return $null
  }

  if ($Value -is [System.Collections.IDictionary]) {
    $result = [ordered]@{}
    foreach ($key in $Value.Keys) {
      $result[[string]$key] = ConvertTo-Hashtable -Value $Value[$key]
    }
    return $result
  }

  if ($Value -is [pscustomobject]) {
    $result = [ordered]@{}
    foreach ($property in $Value.PSObject.Properties) {
      $result[$property.Name] = ConvertTo-Hashtable -Value $property.Value
    }
    return $result
  }

  if (($Value -is [System.Collections.IEnumerable]) -and -not ($Value -is [string])) {
    $items = @()
    foreach ($item in $Value) {
      $items += ,(ConvertTo-Hashtable -Value $item)
    }
    return $items
  }

  return $Value
}

function Read-JsonFile {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return [ordered]@{}
  }

  $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return [ordered]@{}
  }

  try {
    return ConvertTo-Hashtable -Value ($raw | ConvertFrom-Json)
  } catch {
    throw "JSON 文件解析失败：$Path。请先检查该文件是否是合法 JSON。"
  }
}

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Data
  )

  Ensure-Directory -Path (Split-Path -Parent $Path)
  $json = ConvertTo-Json -InputObject $Data -Depth 100
  Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
}

function Get-NestedValue {
  param(
    [object]$Root,
    [string[]]$Segments
  )

  $current = $Root
  foreach ($segment in $Segments) {
    if ($null -eq $current) {
      return $null
    }
    if ($current -is [System.Collections.IDictionary]) {
      if (-not $current.Contains($segment)) {
        return $null
      }
      $current = $current[$segment]
      continue
    }
    return $null
  }
  return $current
}

function Get-ShortHash {
  param([string]$Text)

  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = $sha.ComputeHash($bytes)
    return ([System.BitConverter]::ToString($hash)).Replace("-", "").Substring(0, 8).ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Get-ProjectSlug {
  param([string]$ProjectRoot)

  $leaf = Split-Path -Leaf $ProjectRoot
  if ([string]::IsNullOrWhiteSpace($leaf)) {
    $leaf = "target-project"
  }
  $safeLeaf = ($leaf -replace "[^A-Za-z0-9._-]", "-").Trim("-")
  if ([string]::IsNullOrWhiteSpace($safeLeaf)) {
    $safeLeaf = "target-project"
  }
  return "{0}-{1}" -f $safeLeaf, (Get-ShortHash -Text $ProjectRoot)
}

function Join-TemplatePath {
  param([string]$RelativePath)
  return Join-Path $script:TemplateRoot (Normalize-RelativePath -Path $RelativePath)
}

function Join-TargetPath {
  param([string]$RelativePath)
  return Join-Path $script:TargetRoot (Normalize-RelativePath -Path $RelativePath)
}

function Get-TemplateSourceFiles {
  param([string]$RelativeDirectory)

  $root = Join-TemplatePath -RelativePath $RelativeDirectory
  if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    return @()
  }

  $files = Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
    $_.FullName -notmatch "\\__pycache__\\" -and $_.Extension -ne ".pyc"
  }

  return @(
    foreach ($file in $files) {
      Normalize-RelativePath -Path (Get-RelativePathFromRoot -Root $script:TemplateRoot -Child $file.FullName)
    }
  )
}

function Test-NewTemplateMarker {
  param([string]$ProjectRoot)
  return Test-Path -LiteralPath (Join-Path $ProjectRoot $script:TemplateVersionRelative) -PathType Leaf
}

function Test-LegacyTemplateMarker {
  param([string]$ProjectRoot)
  return Test-Path -LiteralPath (Join-Path $ProjectRoot $script:LegacyTemplateVersionRelative) -PathType Leaf
}

function Test-PartialTemplateLayer {
  param([string]$ProjectRoot)

  foreach ($relativePath in @(
      "Scripts\ci\main.py",
      "Scripts\hooks\pre_commit.py",
      ".vscode\tasks.json",
      ".vscode\launch.json",
      ".vscode\settings.json",
      "lefthook.yml",
      ".clangd",
      ".clang-format",
      $script:LegacyConfigRelative
    )) {
    if (Test-Path -LiteralPath (Join-Path $ProjectRoot $relativePath)) {
      return $true
    }
  }

  return $false
}

function Test-LooksLikeStm32Project {
  param([string]$ProjectRoot)

  if (Test-Path -LiteralPath (Join-Path $ProjectRoot "Core") -PathType Container) { return $true }
  if (Test-Path -LiteralPath (Join-Path $ProjectRoot "Drivers") -PathType Container) { return $true }
  if (Get-ChildItem -LiteralPath $ProjectRoot -Filter "*.ioc" -File -ErrorAction SilentlyContinue | Select-Object -First 1) { return $true }
  if (Get-ChildItem -LiteralPath $ProjectRoot -Filter "startup_*.s" -File -ErrorAction SilentlyContinue | Select-Object -First 1) { return $true }
  if (Get-ChildItem -LiteralPath $ProjectRoot -Filter "STM32*.ld" -File -ErrorAction SilentlyContinue | Select-Object -First 1) { return $true }
  if (Test-Path -LiteralPath (Join-Path $ProjectRoot "CMakeLists.txt") -PathType Leaf) { return $true }

  return $false
}

function Get-TargetState {
  param([string]$ProjectRoot)

  return [pscustomobject]@{
    has_new_marker = Test-NewTemplateMarker -ProjectRoot $ProjectRoot
    has_legacy_marker = Test-LegacyTemplateMarker -ProjectRoot $ProjectRoot
    has_partial_template = Test-PartialTemplateLayer -ProjectRoot $ProjectRoot
    looks_like_stm32 = Test-LooksLikeStm32Project -ProjectRoot $ProjectRoot
  }
}

function Get-CommandAvailability {
  param([string]$Name)
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-PreflightChecks {
  param(
    [string]$ResolvedMode,
    [pscustomobject]$TargetState
  )

  $fatalMessages = New-Object System.Collections.Generic.List[string]
  $warningMessages = New-Object System.Collections.Generic.List[string]

  if (-not (Test-Path -LiteralPath $script:TargetRoot -PathType Container)) {
    $fatalMessages.Add("目标项目根目录不存在：$($script:TargetRoot)") | Out-Null
  }

  if (Test-IsSameOrChildPath -ParentPath $script:TemplateRoot -ChildPath $script:TargetRoot) {
    $fatalMessages.Add("目标项目路径不能指向当前模板仓库，也不能是模板仓库内部子目录。") | Out-Null
  }

  $leaf = Split-Path -Leaf $script:TargetRoot
  if ($leaf -in @("Core", "Drivers", "build", "Scripts", ".vscode", ".local-ci", "Middlewares", "App", "Bsp", "Board", "Service", "Config")) {
    $fatalMessages.Add("当前路径看起来像项目子目录，不是项目仓库根目录。请把路径改成整个项目的根目录。") | Out-Null
  }

  if (Test-Path -LiteralPath $script:TargetRoot -PathType Container) {
    try {
      $probePath = Join-Path $script:TargetRoot ".__stm32_local_ci_write_probe__.tmp"
      [System.IO.File]::WriteAllText($probePath, "probe", [System.Text.Encoding]::ASCII)
      [System.IO.File]::Delete($probePath)
    } catch {
      $fatalMessages.Add("目标项目目录当前不可写。请检查权限、只读属性或是否被其他工具占用。") | Out-Null
    }
  }

  if (-not $TargetState.looks_like_stm32 -and -not $Force.IsPresent) {
    $fatalMessages.Add("没有在目标目录中检测到明显的 STM32 工程骨架。请先在项目根目录生成 CubeMX / 工程层，或确认后使用 -Force。") | Out-Null
  }

  switch ($ResolvedMode) {
    "Install" {
      if ($TargetState.has_new_marker -or $TargetState.has_legacy_marker) {
        $fatalMessages.Add("目标项目已经存在模板版本标记。首次接入请使用 Install，已有项目升级请改用 Upgrade。") | Out-Null
      }
    }
    "Upgrade" {
      if (-not $TargetState.has_new_marker -and -not $TargetState.has_legacy_marker) {
        $fatalMessages.Add("目标项目还没有检测到模板版本标记。首次接入请改用 Install。") | Out-Null
      }
    }
    "Repair" {
      if (-not $TargetState.has_new_marker -and -not $TargetState.has_legacy_marker -and -not $TargetState.has_partial_template) {
        $fatalMessages.Add("当前项目既没有模板版本标记，也没有明显的模板层文件。修复模式无从下手，请改用 Install。") | Out-Null
      }
    }
  }

  if (-not (Get-CommandAvailability -Name "py")) {
    $warningMessages.Add("当前终端还找不到 py。导入可以继续，但后续 init / build / check 可能失败。") | Out-Null
  }
  if (-not (Get-CommandAvailability -Name "cmake")) {
    $warningMessages.Add("当前终端还找不到 cmake。导入可以继续，但后续 build 会失败。") | Out-Null
  }
  if (-not (Get-CommandAvailability -Name "clangd")) {
    $warningMessages.Add("当前终端还找不到 clangd。导入可以继续，但 VS Code 语义分析会受影响。") | Out-Null
  }

  return [pscustomobject]@{
    fatal_messages = @($fatalMessages)
    warning_messages = @($warningMessages)
  }
}

function Get-CMakeProjectName {
  param([string]$ProjectRoot)

  $cmakeLists = Join-Path $ProjectRoot "CMakeLists.txt"
  if (-not (Test-Path -LiteralPath $cmakeLists -PathType Leaf)) {
    return $null
  }

  $raw = Get-Content -LiteralPath $cmakeLists -Raw -Encoding UTF8
  $match = [regex]::Match($raw, "set\s*\(\s*CMAKE_PROJECT_NAME\s+([A-Za-z0-9_]+)\s*\)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if (-not $match.Success) {
    $match = [regex]::Match($raw, "project\s*\(\s*([A-Za-z0-9_]+)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  }
  if ($match.Success) {
    return $match.Groups[1].Value
  }

  return $null
}

function Get-ExistingLaunchDocument {
  $launchPath = Join-TargetPath -RelativePath ".vscode\launch.json"
  return Read-JsonFile -Path $launchPath
}

function Get-DebugLaunchConfiguration {
  param([object]$LaunchDocument)

  $configurations = Get-NestedValue -Root $LaunchDocument -Segments @("configurations")
  if ($configurations -isnot [System.Collections.IEnumerable]) {
    return $null
  }

  foreach ($configuration in $configurations) {
    if ($configuration -is [System.Collections.IDictionary] -and $configuration["name"] -eq $script:LaunchConfigurationName) {
      return $configuration
    }
  }

  return $null
}

function Get-ArtifactBaseNameFromLaunch {
  param([object]$LaunchConfiguration)

  if ($LaunchConfiguration -isnot [System.Collections.IDictionary]) {
    return $null
  }

  $executable = $LaunchConfiguration["executable"]
  if ($executable -isnot [string] -or [string]::IsNullOrWhiteSpace($executable)) {
    return $null
  }

  $fileName = Split-Path -Leaf ($executable.Replace("/", "\"))
  if ([string]::IsNullOrWhiteSpace($fileName)) {
    return $null
  }

  $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
  if ($baseName -match "__ARTIFACT_BASE_NAME__") {
    return $null
  }
  return $baseName
}

function Get-OpenOcdCfgFromLaunch {
  param(
    [object]$LaunchConfiguration,
    [string]$Category
  )

  if ($LaunchConfiguration -isnot [System.Collections.IDictionary]) {
    return $null
  }

  $configFiles = $LaunchConfiguration["configFiles"]
  if ($configFiles -isnot [System.Collections.IEnumerable]) {
    return $null
  }

  foreach ($item in $configFiles) {
    if ($item -isnot [string]) {
      continue
    }
    $match = [regex]::Match($item.Replace("/", "\"), "($Category\\[^""\s]+\.cfg)$", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($match.Success) {
      $value = $match.Groups[1].Value.Replace("\", "/")
      if ($value -notmatch "__OPENOCD_") {
        return $value
      }
    }
  }

  return $null
}

function Get-LegacyConfig {
  $legacyPath = Join-TargetPath -RelativePath $script:LegacyConfigRelative
  if (-not (Test-Path -LiteralPath $legacyPath -PathType Leaf)) {
    return [ordered]@{}
  }
  return Read-JsonFile -Path $legacyPath
}

function Resolve-TargetCfg {
  param(
    [object]$LegacyConfig,
    [object]$LaunchConfiguration
  )

  if (-not [string]::IsNullOrWhiteSpace($OpenOcdTargetCfg)) {
    return $OpenOcdTargetCfg.Trim()
  }

  $fromLaunch = Get-OpenOcdCfgFromLaunch -LaunchConfiguration $LaunchConfiguration -Category "target"
  if ($fromLaunch) {
    return $fromLaunch
  }

  $fromLegacy = Get-NestedValue -Root $LegacyConfig -Segments @("flash", "target_cfg")
  if ($fromLegacy -is [string] -and -not [string]::IsNullOrWhiteSpace($fromLegacy)) {
    return $fromLegacy.Trim()
  }

  switch ($ChipFamily) {
    "G4" { return "target/stm32g4x.cfg" }
    "F4" { return "target/stm32f4x.cfg" }
    default { return "target/stm32h7x.cfg" }
  }
}

function Resolve-InterfaceCfg {
  param(
    [object]$LegacyConfig,
    [object]$LaunchConfiguration
  )

  if (-not [string]::IsNullOrWhiteSpace($OpenOcdInterfaceCfg)) {
    return $OpenOcdInterfaceCfg.Trim()
  }

  $fromLaunch = Get-OpenOcdCfgFromLaunch -LaunchConfiguration $LaunchConfiguration -Category "interface"
  if ($fromLaunch) {
    return $fromLaunch
  }

  $fromLegacy = Get-NestedValue -Root $LegacyConfig -Segments @("flash", "interface_cfg")
  if ($fromLegacy -is [string] -and -not [string]::IsNullOrWhiteSpace($fromLegacy)) {
    return $fromLegacy.Trim()
  }

  switch ($ProbeInterface) {
    "StLink" { return "interface/stlink.cfg" }
    "JLink" { return "interface/jlink.cfg" }
    default { return "interface/cmsis-dap.cfg" }
  }
}

function Get-TemplateRenderingData {
  $legacyConfig = Get-LegacyConfig
  $launchDocument = Get-ExistingLaunchDocument
  $launchConfiguration = Get-DebugLaunchConfiguration -LaunchDocument $launchDocument

  $resolvedProjectName = if (-not [string]::IsNullOrWhiteSpace($ProjectName)) {
    $ProjectName.Trim()
  } else {
    (Get-CMakeProjectName -ProjectRoot $script:TargetRoot)
  }
  if ([string]::IsNullOrWhiteSpace($resolvedProjectName)) {
    $resolvedProjectName = Split-Path -Leaf $script:TargetRoot
  }

  $resolvedArtifactBaseName = if (-not [string]::IsNullOrWhiteSpace($ArtifactBaseName)) {
    $ArtifactBaseName.Trim()
  } else {
    (Get-ArtifactBaseNameFromLaunch -LaunchConfiguration $launchConfiguration)
  }
  if ([string]::IsNullOrWhiteSpace($resolvedArtifactBaseName)) {
    $legacyArtifact = Get-NestedValue -Root $legacyConfig -Segments @("artifacts", "base_name")
    if ($legacyArtifact -is [string] -and -not [string]::IsNullOrWhiteSpace($legacyArtifact)) {
      $resolvedArtifactBaseName = $legacyArtifact.Trim()
    }
  }
  if ([string]::IsNullOrWhiteSpace($resolvedArtifactBaseName)) {
    $resolvedArtifactBaseName = $resolvedProjectName
  }

  $notes = New-Object System.Collections.Generic.List[string]
  if ($legacyConfig.Count -gt 0) {
    $legacyQuality = Get-NestedValue -Root $legacyConfig -Segments @("quality")
    if ($null -ne $legacyQuality) {
      $notes.Add("检测到旧版 .local-ci/config.json 里有质量规则自定义。本次不会自动迁移这部分，请在升级后人工确认。") | Out-Null
    }
  }

  return [pscustomobject]@{
    project_name = $resolvedProjectName
    artifact_base_name = $resolvedArtifactBaseName
    openocd_target_cfg = Resolve-TargetCfg -LegacyConfig $legacyConfig -LaunchConfiguration $launchConfiguration
    openocd_interface_cfg = Resolve-InterfaceCfg -LegacyConfig $legacyConfig -LaunchConfiguration $launchConfiguration
    notes = @($notes)
  }
}

function Render-TemplateText {
  param(
    [string]$RelativePath,
    [string]$Text,
    [pscustomobject]$RenderData
  )

  if ((Normalize-RelativePath -Path $RelativePath) -ieq ".vscode\launch.json") {
    $Text = $Text.Replace("__ARTIFACT_BASE_NAME__", $RenderData.artifact_base_name)
    $Text = $Text.Replace("__OPENOCD_TARGET_CFG__", $RenderData.openocd_target_cfg)
    $Text = $Text.Replace("__OPENOCD_INTERFACE_CFG__", $RenderData.openocd_interface_cfg)
  }

  return $Text
}

function Merge-SettingsJson {
  param(
    [hashtable]$ExistingDocument,
    [hashtable]$TemplateDocument
  )

  $result = [ordered]@{}
  foreach ($key in $ExistingDocument.Keys) {
    $result[$key] = $ExistingDocument[$key]
  }

  foreach ($key in @("clangd.path", "clangd.arguments", "[c]", "[cpp]")) {
    if ($TemplateDocument.Contains($key)) {
      $result[$key] = $TemplateDocument[$key]
    }
  }

  return $result
}

function Merge-LaunchJson {
  param(
    [hashtable]$ExistingDocument,
    [hashtable]$TemplateDocument
  )

  $result = [ordered]@{}
  foreach ($key in $ExistingDocument.Keys) {
    $result[$key] = $ExistingDocument[$key]
  }

  if ($TemplateDocument.Contains("version")) {
    $result["version"] = $TemplateDocument["version"]
  }

  $existingConfigurations = @()
  if ($result.Contains("configurations") -and ($result["configurations"] -is [System.Collections.IEnumerable])) {
    $existingConfigurations = @($result["configurations"])
  }

  $templateConfigurations = @()
  if ($TemplateDocument.Contains("configurations") -and ($TemplateDocument["configurations"] -is [System.Collections.IEnumerable])) {
    $templateConfigurations = @($TemplateDocument["configurations"])
  }

  $templateConfiguration = $null
  foreach ($item in $templateConfigurations) {
    if ($item -is [System.Collections.IDictionary] -and $item["name"] -eq $script:LaunchConfigurationName) {
      $templateConfiguration = $item
      break
    }
  }

  $mergedConfigurations = @()
  $foundTemplateConfiguration = $false

  foreach ($configuration in $existingConfigurations) {
    if ($configuration -isnot [System.Collections.IDictionary]) {
      $mergedConfigurations += ,$configuration
      continue
    }

    if ($configuration["name"] -eq $script:LaunchConfigurationName -and $null -ne $templateConfiguration) {
      $merged = [ordered]@{}
      foreach ($key in $configuration.Keys) {
        $merged[$key] = $configuration[$key]
      }
      foreach ($key in @("name", "type", "request", "servertype", "cwd", "executable", "gdbPath", "serverpath", "configFiles", "preLaunchTask", "runToEntryPoint")) {
        if ($templateConfiguration.Contains($key)) {
          $merged[$key] = $templateConfiguration[$key]
        }
      }
      $mergedConfigurations += ,$merged
      $foundTemplateConfiguration = $true
      continue
    }

    $mergedConfigurations += ,$configuration
  }

  if (-not $foundTemplateConfiguration -and $null -ne $templateConfiguration) {
    $mergedConfigurations += ,$templateConfiguration
  }

  $result["configurations"] = $mergedConfigurations
  return $result
}

function Get-LegacyBackupCandidates {
  $candidates = New-Object System.Collections.ArrayList

  foreach ($relativePath in ($script:MergeRelativeFiles + $script:ReplaceRelativeFiles + @($script:LegacyConfigRelative, $script:LegacyTemplateVersionRelative, "Scripts\hooks\pre_push.py"))) {
    $targetPath = Join-TargetPath -RelativePath $relativePath
    $parent = Split-Path -Parent $targetPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
      continue
    }

    $leaf = Split-Path -Leaf $targetPath
    $backupFiles = Get-ChildItem -LiteralPath $parent -Force -File -ErrorAction SilentlyContinue | Where-Object {
      $_.Name -like "$leaf.bak*"
    }
    foreach ($backupFile in $backupFiles) {
      $relative = Normalize-RelativePath -Path (Get-RelativePathFromRoot -Root $script:TargetRoot -Child $backupFile.FullName)
      if (-not ($candidates -contains $relative)) {
        [void]$candidates.Add($relative)
      }
    }
  }

  return @($candidates | Sort-Object)
}

function New-PlanAction {
  param(
    [string]$Type,
    [string]$RelativePath,
    [string]$SourceRelativePath,
    [string]$Description
  )

  return [pscustomobject]@{
    type = $Type
    relative_path = Normalize-RelativePath -Path $RelativePath
    source_relative_path = Normalize-RelativePath -Path $SourceRelativePath
    description = $Description
  }
}

function Build-InstallerPlan {
  $targetState = Get-TargetState -ProjectRoot $script:TargetRoot

  if ([string]::IsNullOrWhiteSpace($Mode)) {
    if ($targetState.has_new_marker -or $targetState.has_legacy_marker) {
      $script:ResolvedMode = "Upgrade"
      Write-Info "没有显式传入模式，已根据目标项目状态自动使用 Upgrade。"
    } else {
      $script:ResolvedMode = "Install"
      Write-Info "没有显式传入模式，已根据目标项目状态自动使用 Install。"
    }
  } else {
    $script:ResolvedMode = $Mode
  }

  $preflight = Invoke-PreflightChecks -ResolvedMode $script:ResolvedMode -TargetState $targetState
  foreach ($warning in $preflight.warning_messages) {
    Write-WarnLine $warning
  }
  if ($preflight.fatal_messages.Count -gt 0) {
    throw ($preflight.fatal_messages -join [Environment]::NewLine)
  }

  $renderData = Get-TemplateRenderingData
  foreach ($note in $renderData.notes) {
    Write-WarnLine $note
  }

  $actions = New-Object System.Collections.ArrayList

  foreach ($directory in $script:ManagedRelativeDirectories) {
    foreach ($sourceRelativePath in (Get-TemplateSourceFiles -RelativeDirectory $directory)) {
      $targetPath = Join-TargetPath -RelativePath $sourceRelativePath
      $type = if (Test-Path -LiteralPath $targetPath -PathType Leaf) { "Replace" } else { "Create" }
      [void]$actions.Add((New-PlanAction -Type $type -RelativePath $sourceRelativePath -SourceRelativePath $sourceRelativePath -Description "刷新模板脚本"))
    }
  }

  foreach ($relativePath in $script:ReplaceRelativeFiles) {
    $targetPath = Join-TargetPath -RelativePath $relativePath
    $type = if (Test-Path -LiteralPath $targetPath -PathType Leaf) { "Replace" } else { "Create" }
    [void]$actions.Add((New-PlanAction -Type $type -RelativePath $relativePath -SourceRelativePath $relativePath -Description "刷新模板拥有文件"))
  }

  foreach ($relativePath in $script:MergeRelativeFiles) {
    [void]$actions.Add((New-PlanAction -Type "Merge" -RelativePath $relativePath -SourceRelativePath $relativePath -Description "合并模板与项目配置"))
  }

  foreach ($relativePath in $script:LegacyCleanupFiles) {
    $legacyPath = Join-TargetPath -RelativePath $relativePath
    if (Test-Path -LiteralPath $legacyPath -PathType Leaf) {
      [void]$actions.Add((New-PlanAction -Type "DeleteLegacy" -RelativePath $relativePath -SourceRelativePath "" -Description "清理旧版遗留文件"))
    }
  }

  foreach ($relativePath in $script:LegacyCleanupDirectories) {
    $legacyPath = Join-TargetPath -RelativePath $relativePath
    if (Test-Path -LiteralPath $legacyPath -PathType Container) {
      [void]$actions.Add((New-PlanAction -Type "DeleteLegacy" -RelativePath $relativePath -SourceRelativePath "" -Description "清理旧版遗留目录"))
    }
  }

  foreach ($relativePath in (Get-LegacyBackupCandidates)) {
    [void]$actions.Add((New-PlanAction -Type "DeleteLegacy" -RelativePath $relativePath -SourceRelativePath "" -Description "清理旧式 .bak.* 备份"))
  }

  return [pscustomobject]@{
    mode = $script:ResolvedMode
    preview = [bool]$Preview
    target_root = $script:TargetRoot
    render = $renderData
    actions = @($actions)
  }
}

function Show-InstallerPlan {
  param([pscustomobject]$Plan)

  $groups = @{
    Create = @()
    Replace = @()
    Merge = @()
    DeleteLegacy = @()
  }

  foreach ($action in $Plan.actions) {
    if ($groups.ContainsKey($action.type)) {
      $groups[$action.type] += ,$action.relative_path
    }
  }

  Write-Step ("执行模式：{0}{1}" -f $Plan.mode, $(if ($Plan.preview) { "（仅预览）" } else { "" }))
  Write-Info ("目标项目：{0}" -f $Plan.target_root)
  Write-Info ("项目名：{0}" -f $Plan.render.project_name)
  Write-Info ("产物名：{0}" -f $Plan.render.artifact_base_name)
  Write-Info ("OpenOCD target：{0}" -f $Plan.render.openocd_target_cfg)
  Write-Info ("OpenOCD interface：{0}" -f $Plan.render.openocd_interface_cfg)
  Write-Host ""
  Write-Host ("新增：{0} 个，替换：{1} 个，合并：{2} 个，清理：{3} 个" -f $groups.Create.Count, $groups.Replace.Count, $groups.Merge.Count, $groups.DeleteLegacy.Count)

  foreach ($entry in @(
      @{ title = "将新增的文件"; items = $groups.Create },
      @{ title = "将替换的文件"; items = $groups.Replace },
      @{ title = "将合并的文件"; items = $groups.Merge },
      @{ title = "将清理的旧文件"; items = $groups.DeleteLegacy }
    )) {
    if ($entry.items.Count -eq 0) {
      continue
    }
    Write-Host ""
    Write-Host $entry.title -ForegroundColor Yellow
    foreach ($item in $entry.items) {
      Write-Host ("- {0}" -f $item)
    }
  }
}

function Save-TransactionSnapshot {
  param([pscustomobject]$Plan)

  Remove-PathIfExists -Path $script:TransactionRoot
  Ensure-Directory -Path $script:TransactionFilesRoot

  $manifestEntries = New-Object System.Collections.ArrayList
  $captured = @{}

  foreach ($action in $Plan.actions) {
    if ([string]::IsNullOrWhiteSpace($action.relative_path)) {
      continue
    }
    if ($captured.ContainsKey($action.relative_path)) {
      continue
    }
    $captured[$action.relative_path] = $true

    $targetPath = Join-TargetPath -RelativePath $action.relative_path
    $state = "Missing"
    if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
      $state = "File"
      $snapshotPath = Join-Path $script:TransactionFilesRoot $action.relative_path
      Ensure-Directory -Path (Split-Path -Parent $snapshotPath)
      Copy-Item -LiteralPath $targetPath -Destination $snapshotPath -Force
    } elseif (Test-Path -LiteralPath $targetPath -PathType Container) {
      $state = "Directory"
      $snapshotPath = Join-Path $script:TransactionFilesRoot $action.relative_path
      Ensure-Directory -Path (Split-Path -Parent $snapshotPath)
      Copy-Item -LiteralPath $targetPath -Destination $snapshotPath -Recurse -Force
    }

    [void]$manifestEntries.Add([ordered]@{
        relative_path = $action.relative_path
        state = $state
      })
  }

  $manifest = [ordered]@{
    created_at = (Get-Date).ToString("s")
    mode = $Plan.mode
    entries = @($manifestEntries)
  }

  Write-JsonFile -Path (Join-Path $script:TransactionRoot "manifest.json") -Data $manifest
}

function Restore-TransactionSnapshot {
  $manifestPath = Join-Path $script:TransactionRoot "manifest.json"
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    return
  }

  $manifest = Read-JsonFile -Path $manifestPath
  $entries = Get-NestedValue -Root $manifest -Segments @("entries")
  if ($entries -isnot [System.Collections.IEnumerable]) {
    return
  }

  foreach ($entry in $entries) {
    if ($entry -isnot [System.Collections.IDictionary]) {
      continue
    }

    $relativePath = Normalize-RelativePath -Path ([string]$entry["relative_path"])
    $state = [string]$entry["state"]
    $targetPath = Join-TargetPath -RelativePath $relativePath
    $snapshotPath = Join-Path $script:TransactionFilesRoot $relativePath

    switch ($state) {
      "Missing" {
        Remove-PathIfExists -Path $targetPath
      }
      "File" {
        Remove-PathIfExists -Path $targetPath
        Ensure-Directory -Path (Split-Path -Parent $targetPath)
        Copy-Item -LiteralPath $snapshotPath -Destination $targetPath -Force
      }
      "Directory" {
        Remove-PathIfExists -Path $targetPath
        Ensure-Directory -Path (Split-Path -Parent $targetPath)
        Copy-Item -LiteralPath $snapshotPath -Destination $targetPath -Recurse -Force
      }
    }
  }
}

function Remove-EmptyLegacyDirectory {
  $legacyRoot = Join-TargetPath -RelativePath ".local-ci"
  if (-not (Test-Path -LiteralPath $legacyRoot -PathType Container)) {
    return
  }

  $children = @(Get-ChildItem -LiteralPath $legacyRoot -Force -ErrorAction SilentlyContinue)
  if ($children.Count -eq 0) {
    Remove-Item -LiteralPath $legacyRoot -Force
    return
  }

  Write-WarnLine "旧 .local-ci 目录里仍有未迁移内容，请人工检查后再决定是否删除。"
}

function Remove-EmptyManagedDirectories {
  foreach ($relativePath in @(
      "Scripts\ci",
      "Scripts\hooks",
      "Scripts",
      ".vscode",
      ".local-ci"
    )) {
    $targetPath = Join-TargetPath -RelativePath $relativePath
    if (-not (Test-Path -LiteralPath $targetPath -PathType Container)) {
      continue
    }
    $children = @(Get-ChildItem -LiteralPath $targetPath -Force -ErrorAction SilentlyContinue)
    if ($children.Count -eq 0) {
      Remove-Item -LiteralPath $targetPath -Force
    }
  }
}

function Apply-CopyAction {
  param(
    [pscustomobject]$Action,
    [pscustomobject]$RenderData
  )

  $sourcePath = Join-TemplatePath -RelativePath $Action.source_relative_path
  $targetPath = Join-TargetPath -RelativePath $Action.relative_path
  $raw = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8
  $rendered = Render-TemplateText -RelativePath $Action.relative_path -Text $raw -RenderData $RenderData
  Ensure-Directory -Path (Split-Path -Parent $targetPath)
  Set-Content -LiteralPath $targetPath -Value $rendered -Encoding UTF8
}

function Apply-MergeAction {
  param(
    [pscustomobject]$Action,
    [pscustomobject]$RenderData
  )

  $sourcePath = Join-TemplatePath -RelativePath $Action.source_relative_path
  $targetPath = Join-TargetPath -RelativePath $Action.relative_path

  $templateRaw = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8
  $templateRendered = Render-TemplateText -RelativePath $Action.relative_path -Text $templateRaw -RenderData $RenderData
  $templateDocument = ConvertTo-Hashtable -Value ($templateRendered | ConvertFrom-Json)
  $existingDocument = Read-JsonFile -Path $targetPath

  $merged = switch ((Normalize-RelativePath -Path $Action.relative_path).ToLowerInvariant()) {
    ".vscode\settings.json" { Merge-SettingsJson -ExistingDocument $existingDocument -TemplateDocument $templateDocument }
    ".vscode\launch.json" { Merge-LaunchJson -ExistingDocument $existingDocument -TemplateDocument $templateDocument }
    default { $templateDocument }
  }

  Write-JsonFile -Path $targetPath -Data $merged
}

function Apply-DeleteLegacyAction {
  param([pscustomobject]$Action)
  $targetPath = Join-TargetPath -RelativePath $Action.relative_path
  Remove-PathIfExists -Path $targetPath
}

function Execute-InstallerPlan {
  param([pscustomobject]$Plan)

  Save-TransactionSnapshot -Plan $Plan
  $script:AutoRestoreMessage = ""

  try {
    foreach ($action in $Plan.actions) {
      switch ($action.type) {
        "Create" { Apply-CopyAction -Action $action -RenderData $Plan.render }
        "Replace" { Apply-CopyAction -Action $action -RenderData $Plan.render }
        "Merge" { Apply-MergeAction -Action $action -RenderData $Plan.render }
        "DeleteLegacy" { Apply-DeleteLegacyAction -Action $action }
      }
    }
    Remove-EmptyLegacyDirectory
    Remove-EmptyManagedDirectories
  } catch {
    try {
      Restore-TransactionSnapshot
      Remove-EmptyLegacyDirectory
      Remove-EmptyManagedDirectories
      $script:AutoRestoreMessage = "脚本已自动恢复到本次执行前的状态。"
    } catch {
      $script:AutoRestoreMessage = "脚本尝试自动恢复，但恢复过程也失败了：$($_.Exception.Message)"
    }
    throw
  } finally {
    Remove-PathIfExists -Path $script:TransactionRoot
  }
}

function Write-RunLog {
  param(
    [string]$Status,
    [pscustomobject]$Plan,
    [string]$FailureMessage = "",
    [System.Management.Automation.ErrorRecord]$ExceptionRecord = $null
  )

  Ensure-Directory -Path $script:RuntimeRoot

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("time: $((Get-Date).ToString("s"))") | Out-Null
  $lines.Add("status: $Status") | Out-Null
  $lines.Add("mode: $($script:ResolvedMode)") | Out-Null
  $lines.Add("preview: $([bool]$Preview)") | Out-Null
  $lines.Add("target_project: $($script:TargetRoot)") | Out-Null
  $lines.Add("template_root: $($script:TemplateRoot)") | Out-Null
  $lines.Add("runtime_root: $($script:RuntimeRoot)") | Out-Null
  $lines.Add("template_marker: $($script:TemplateVersionRelative)") | Out-Null
  if ($Plan) {
    $lines.Add("project_name: $($Plan.render.project_name)") | Out-Null
    $lines.Add("artifact_base_name: $($Plan.render.artifact_base_name)") | Out-Null
    $lines.Add("openocd_target_cfg: $($Plan.render.openocd_target_cfg)") | Out-Null
    $lines.Add("openocd_interface_cfg: $($Plan.render.openocd_interface_cfg)") | Out-Null
    $lines.Add("action_count: $($Plan.actions.Count)") | Out-Null
    $lines.Add("actions:") | Out-Null
    foreach ($action in $Plan.actions) {
      $lines.Add("  - [$($action.type)] $($action.relative_path)") | Out-Null
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($script:AutoRestoreMessage)) {
    $lines.Add("auto_restore: $($script:AutoRestoreMessage)") | Out-Null
  }
  if (-not [string]::IsNullOrWhiteSpace($FailureMessage)) {
    $lines.Add("failure_message: $FailureMessage") | Out-Null
  }
  if ($ExceptionRecord) {
    $lines.Add("exception:") | Out-Null
    $lines.Add($ExceptionRecord.ToString()) | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($ExceptionRecord.ScriptStackTrace)) {
      $lines.Add("script_stack_trace:") | Out-Null
      $lines.Add($ExceptionRecord.ScriptStackTrace) | Out-Null
    }
    if ($ExceptionRecord.InvocationInfo -and -not [string]::IsNullOrWhiteSpace($ExceptionRecord.InvocationInfo.PositionMessage)) {
      $lines.Add("position_message:") | Out-Null
      $lines.Add($ExceptionRecord.InvocationInfo.PositionMessage) | Out-Null
    }
  }

  Set-Content -LiteralPath $script:LogPath -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
  return $script:LogPath
}

function Initialize-InstallerContext {
  $script:TemplateRoot = Get-FullPath -Path $PSScriptRoot
  $script:TargetRoot = Get-FullPath -Path $TargetProject
  $script:TemplateVersionRelative = "Scripts\ci\template-version.json"
  $script:LegacyTemplateVersionRelative = ".local-ci\template-version.json"
  $script:LegacyConfigRelative = ".local-ci\config.json"
  $script:LaunchConfigurationName = "Debug STM32 (OpenOCD)"
  $script:ManagedRelativeDirectories = @(
    "Scripts\ci",
    "Scripts\hooks"
  )
  $script:ReplaceRelativeFiles = @(
    ".clangd",
    ".clang-format",
    "lefthook.yml",
    ".vscode\tasks.json"
  )
  $script:MergeRelativeFiles = @(
    ".vscode\settings.json",
    ".vscode\launch.json"
  )
  $script:LegacyCleanupFiles = @(
    ".vscode\extensions.json",
    "Scripts\hooks\pre_push.py",
    ".local-ci\config.schema.json",
    ".local-ci\config.json",
    ".local-ci\template-version.json",
    ".local-ci\installer-state.json"
  )
  $script:LegacyCleanupDirectories = @(
    ".local-ci\backup-last",
    ".local-ci\.txn",
    ".local-ci\logs"
  )

  $runtimeParent = Join-Path ([System.IO.Path]::GetTempPath()) "stm32-local-ci"
  $runtimeLeaf = Get-ProjectSlug -ProjectRoot $script:TargetRoot
  $script:RuntimeRoot = Join-Path $runtimeParent $runtimeLeaf
  $script:TransactionRoot = Join-Path $script:RuntimeRoot "txn"
  $script:TransactionFilesRoot = Join-Path $script:TransactionRoot "files"
  $script:LogPath = Join-Path $script:RuntimeRoot "last-run.log"
  $script:ResolvedMode = $Mode
  $script:AutoRestoreMessage = ""
}

Initialize-InstallerContext

$plan = $null

try {
  $plan = Build-InstallerPlan
  Show-InstallerPlan -Plan $plan

  if ($Preview.IsPresent) {
    Write-Info "本次为预览模式，以上内容仅展示计划，不会真正修改文件。"
    $null = Write-RunLog -Status "preview" -Plan $plan
    exit 0
  }

  Write-Step "开始写入模板层，请稍候..."
  Execute-InstallerPlan -Plan $plan
  $null = Write-RunLog -Status "success" -Plan $plan

  Write-Info "模板层导入完成。"
  Write-Host ""
  Write-Host "建议你接下来在目标项目根目录执行："
  Write-Host "  py -3 Scripts/ci/main.py init"
  Write-Host "  py -3 Scripts/ci/main.py build --preset Debug"
  Write-Host "  py -3 Scripts/ci/main.py check"
  exit 0
} catch {
  $failureMessage = $_.Exception.Message
  Write-ErrorLine $failureMessage
  if (-not [string]::IsNullOrWhiteSpace($script:AutoRestoreMessage)) {
    Write-WarnLine $script:AutoRestoreMessage
  }
  $logPath = Write-RunLog -Status "failed" -Plan $plan -FailureMessage $failureMessage -ExceptionRecord $_
  Write-WarnLine "详细诊断日志已写到系统临时目录：$logPath"
  exit 1
}


