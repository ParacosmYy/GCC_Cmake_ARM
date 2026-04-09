param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Command
)

$ErrorActionPreference = 'Stop'

if (-not $Command -or $Command.Count -eq 0) {
    throw "No command was provided."
}

$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

if ([string]::IsNullOrWhiteSpace($machinePath)) {
    $env:Path = $userPath
} elseif ([string]::IsNullOrWhiteSpace($userPath)) {
    $env:Path = $machinePath
} else {
    $env:Path = "$machinePath;$userPath"
}

$openocdScripts = [Environment]::GetEnvironmentVariable('OPENOCD_SCRIPTS', 'User')
if (-not [string]::IsNullOrWhiteSpace($openocdScripts)) {
    $env:OPENOCD_SCRIPTS = $openocdScripts
}

$commandName = $Command[0]
$commandArgs = @()
if ($Command.Count -gt 1) {
    $commandArgs = $Command[1..($Command.Count - 1)]
}

& $commandName @commandArgs
exit $LASTEXITCODE
