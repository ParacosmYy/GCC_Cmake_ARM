param()

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Write-Title {
  Write-Host ""
  Write-Host "==========================================" -ForegroundColor Cyan
  Write-Host "        STM32 本地 CI 模板导入向导" -ForegroundColor Cyan
  Write-Host "==========================================" -ForegroundColor Cyan
  Write-Host ""
}

function Write-Section {
  param([string]$Message)
  Write-Host ""
  Write-Host $Message -ForegroundColor Yellow
}

function Write-Info {
  param([string]$Message)
  Write-Host $Message -ForegroundColor Green
}

function Write-Warn {
  param([string]$Message)
  Write-Host $Message -ForegroundColor Yellow
}

function Read-RequiredInput {
  param([string]$Prompt)
  while ($true) {
    $value = Read-Host $Prompt
    if (-not [string]::IsNullOrWhiteSpace($value)) {
      return $value.Trim()
    }
    Write-Warn "你还没有输入内容，请重新填写。"
  }
}

function Read-ChoiceOrDefault {
  param([string]$Prompt, [string]$Default)
  $value = Read-Host $Prompt
  if ([string]::IsNullOrWhiteSpace($value)) {
    return $Default
  }
  return $value.Trim()
}

function Confirm-YesNo {
  param([string]$Prompt, [bool]$Default = $false)
  while ($true) {
    $suffix = if ($Default) { "[Y/n]" } else { "[y/N]" }
    $answer = Read-Host "$Prompt $suffix"
    if ([string]::IsNullOrWhiteSpace($answer)) {
      return $Default
    }
    switch -Regex ($answer.Trim()) {
      '^(y|yes|是)$' { return $true }
      '^(n|no|否)$' { return $false }
      default { Write-Warn "请输入 y 或 n，或者直接回车使用默认值。" }
    }
  }
}

function Get-NormalizedFullPath {
  param([string]$PathText)
  try {
    return [System.IO.Path]::GetFullPath($PathText)
  } catch {
    return $PathText
  }
}

function Test-NewTemplateMarker {
  param([string]$ProjectRoot)
  return Test-Path -LiteralPath (Join-Path $ProjectRoot "Scripts\ci\template-version.json")
}

function Test-LegacyTemplateMarker {
  param([string]$ProjectRoot)
  return Test-Path -LiteralPath (Join-Path $ProjectRoot ".local-ci\template-version.json")
}

function Test-PartialTemplateLayer {
  param([string]$ProjectRoot)

  foreach ($relativePath in @(
      "Scripts\ci\main.py",
      ".vscode\tasks.json",
      ".vscode\launch.json",
      ".vscode\settings.json",
      "lefthook.yml",
      ".clangd",
      ".clang-format"
    )) {
    if (Test-Path -LiteralPath (Join-Path $ProjectRoot $relativePath)) {
      return $true
    }
  }

  return $false
}

function Get-ModeGuidance {
  param(
    [string]$Mode,
    [string]$TargetProject
  )

  if (-not (Test-Path -LiteralPath $TargetProject)) {
    return [pscustomobject]@{
      message = "当前路径还不存在，向导暂时无法提前判断模式是否匹配。后续会交给执行层继续检查。"
      suggested_mode = $null
      severity = "info"
    }
  }

  $hasMarker = (Test-NewTemplateMarker -ProjectRoot $TargetProject) -or (Test-LegacyTemplateMarker -ProjectRoot $TargetProject)
  $hasPartial = Test-PartialTemplateLayer -ProjectRoot $TargetProject

  switch ($Mode) {
    "Install" {
      if ($hasMarker) {
        return [pscustomobject]@{
          message = "这个项目已经接入过模板，建议改用 Upgrade，而不是继续使用 Install。"
          suggested_mode = "Upgrade"
          severity = "warn"
        }
      }
    }
    "Upgrade" {
      if (-not $hasMarker) {
        return [pscustomobject]@{
          message = "这个项目还没有检测到模板版本标记，更像是首次接入，建议改用 Install。"
          suggested_mode = "Install"
          severity = "warn"
        }
      }
    }
    "Repair" {
      if ((-not $hasMarker) -and (-not $hasPartial)) {
        return [pscustomobject]@{
          message = "这个项目既没有模板版本标记，也没有明显的模板层文件。修复模式通常无从下手，建议改用 Install。"
          suggested_mode = "Install"
          severity = "warn"
        }
      }
    }
  }

  return $null
}

function Resolve-ModeChoice {
  while ($true) {
    Write-Section "请选择本次模式"
    Write-Host "1. Install  安装：首次把模板层接入项目"
    Write-Host "2. Upgrade  升级：把模板层更新到当前版本"
    Write-Host "3. Repair   修复：补回缺失或损坏的模板层文件"
    $choice = Read-ChoiceOrDefault -Prompt "请选择模式 [1/2/3，默认 1]" -Default "1"
    switch ($choice) {
      "1" { return "Install" }
      "2" { return "Upgrade" }
      "3" { return "Repair" }
      default { Write-Warn "输入无效，请重新选择。" }
    }
  }
}

function Resolve-ModeWithGuidance {
  param(
    [string]$InitialMode,
    [string]$TargetProject
  )

  $resolvedMode = $InitialMode
  while ($true) {
    $guidance = Get-ModeGuidance -Mode $resolvedMode -TargetProject $TargetProject
    if ($null -eq $guidance) {
      return $resolvedMode
    }

    if ($guidance.severity -eq "info") {
      Write-Info $guidance.message
      return $resolvedMode
    }

    Write-Warn $guidance.message
    if (-not [string]::IsNullOrWhiteSpace($guidance.suggested_mode)) {
      if (Confirm-YesNo -Prompt ("是否现在改用 {0}？" -f $guidance.suggested_mode) -Default:$true) {
        $resolvedMode = $guidance.suggested_mode
        continue
      }
    }

    if (Confirm-YesNo -Prompt "是否重新选择模式？" -Default:$true) {
      $resolvedMode = Resolve-ModeChoice
      continue
    }

    return $resolvedMode
  }
}

function Resolve-ChipChoice {
  while ($true) {
    Write-Section "请选择芯片族"
    Write-Host "1. H7 系列（默认）"
    Write-Host "2. G4 系列"
    Write-Host "3. F4 系列"
    Write-Host "9. 其他芯片（我自己输入 OpenOCD target 配置）"
    $choice = Read-ChoiceOrDefault -Prompt "请选择芯片族 [1/2/3/9，默认 1]" -Default "1"
    switch ($choice) {
      "1" { return @{ chip = "H7"; target = $null } }
      "2" { return @{ chip = "G4"; target = $null } }
      "3" { return @{ chip = "F4"; target = $null } }
      "9" { return @{ chip = $null; target = (Read-RequiredInput -Prompt "请输入 OpenOCD target 配置路径") } }
      default { Write-Warn "输入无效，请重新选择。" }
    }
  }
}

function Resolve-ProbeChoice {
  while ($true) {
    Write-Section "请选择调试器 / 下载器接口"
    Write-Host "1. CMSIS-DAP（默认）"
    Write-Host "2. ST-Link"
    Write-Host "3. J-Link"
    Write-Host "9. 其他接口（我自己输入 OpenOCD interface 配置）"
    $choice = Read-ChoiceOrDefault -Prompt "请选择接口 [1/2/3/9，默认 1]" -Default "1"
    switch ($choice) {
      "1" { return @{ probe = "CmsisDap"; interface = $null } }
      "2" { return @{ probe = "StLink"; interface = $null } }
      "3" { return @{ probe = "JLink"; interface = $null } }
      "9" { return @{ probe = $null; interface = (Read-RequiredInput -Prompt "请输入 OpenOCD interface 配置路径") } }
      default { Write-Warn "输入无效，请重新选择。" }
    }
  }
}

$templateRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$importScript = Join-Path $templateRoot "install-local-ci.ps1"
if (-not (Test-Path -LiteralPath $importScript)) {
  throw "找不到导入脚本：$importScript"
}

Write-Title
Write-Host "这个向导面向团队新人使用，会一步一步帮助你把本地 CI 模板层导入到目标 STM32 项目里。"
Write-Host ""
Write-Host "使用前请先确认："
Write-Host "1. 你已经拿到团队统一的 DevEnv 压缩包。"
Write-Host "2. 你已经执行过 D:\DevEnv\install_env.ps1。"
Write-Host "3. 目标项目最好已经在仓库根目录生成了 CubeMX / 工程层。"
Write-Host "4. 不要把当前这个模板仓库本身当成目标项目路径。"
Write-Host ""
Write-Host "下面是目标 STM32 项目仓库根目录的两个完整路径示例："
Write-Host "- 示例 1：D:\Workplace\STM32\MotorCtrl_H743"
Write-Host "- 示例 2：C:\Users\EDY\Desktop\G4_Board_Test"
Write-Host ""
Write-Host "注意："
Write-Host "- 这里填写的是项目仓库根目录。"
Write-Host "- 不要填到 Core、Drivers、build、Scripts 这些子目录里。"
Write-Host "- 正确目录里通常会有 .ioc、Core、Drivers、CMakeLists.txt 等内容。"

$mode = Resolve-ModeChoice
Write-Section "请输入目标项目根目录"
$targetProject = Get-NormalizedFullPath -PathText (Read-RequiredInput -Prompt "请输入目标 STM32 项目仓库根目录的完整路径")
$mode = Resolve-ModeWithGuidance -InitialMode $mode -TargetProject $targetProject
$previewOnly = Confirm-YesNo -Prompt "本次是否只做预览，不真正修改文件？" -Default:$false
$forceImport = Confirm-YesNo -Prompt "如果目标项目还没有明显的 STM32 工程骨架，是否仍然继续并使用 -Force？" -Default:$false
$chipSelection = Resolve-ChipChoice
$probeSelection = Resolve-ProbeChoice

Write-Section "本次执行摘要"
Write-Host "模式：$mode"
Write-Host "目标项目根目录：$targetProject"
Write-Host ("是否仅预览：{0}" -f $(if ($previewOnly) { "是" } else { "否" }))
Write-Host ("工程骨架检查：{0}" -f $(if ($forceImport) { "放宽检查，使用 -Force" } else { "正常检查" }))
if ($null -ne $chipSelection.chip) {
  Write-Host "芯片族：$($chipSelection.chip)"
} else {
  Write-Host "OpenOCD target 配置：$($chipSelection.target)"
}
if ($null -ne $probeSelection.probe) {
  Write-Host "调试器接口：$($probeSelection.probe)"
} else {
  Write-Host "OpenOCD interface 配置：$($probeSelection.interface)"
}

if (-not (Confirm-YesNo -Prompt "如果以上信息都正确，现在是否继续？" -Default:$true)) {
  Write-Warn "你已取消本次操作。"
  Write-Host ""
  Write-Host "按回车键退出。"
  [void](Read-Host)
  exit 1
}

Write-Section "开始执行，请稍候..."
$arguments = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", $importScript,
  "-Mode", $mode,
  "-TargetProject", $targetProject
)

if ($previewOnly) { $arguments += "-Preview" }
if ($forceImport) { $arguments += "-Force" }
if ($null -ne $chipSelection.chip) {
  $arguments += @("-ChipFamily", $chipSelection.chip)
} else {
  $arguments += @("-OpenOcdTargetCfg", $chipSelection.target)
}
if ($null -ne $probeSelection.probe) {
  $arguments += @("-ProbeInterface", $probeSelection.probe)
} else {
  $arguments += @("-OpenOcdInterfaceCfg", $probeSelection.interface)
}

& powershell.exe @arguments
$exitCode = $LASTEXITCODE

Write-Host ""
if ($exitCode -ne 0) {
  Write-Warn "执行失败。请先根据上方中文提示检查模式、路径、工程骨架和环境命令。"
  Write-Host ""
  Write-Host "按回车键退出。"
  [void](Read-Host)
  exit $exitCode
}

if ($previewOnly) {
  Write-Info "预览已经完成，本次没有真正修改文件。"
} else {
  Write-Info "操作已经完成。"
}

Write-Host ""
Write-Host "按回车键退出。"
[void](Read-Host)
exit 0


