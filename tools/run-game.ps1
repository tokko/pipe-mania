# Visible shipped-game launcher with per-run Godot user data.
param(
  [string]$GodotPath,
  [string]$ProjectRoot,
  [ValidateRange(0, [int]::MaxValue)]
  [int]$QuitAfter = 0
)

$ErrorActionPreference = 'Stop'

if ($PSBoundParameters.ContainsKey('GodotPath')) {
  if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    Write-Error "Godot binary not found: $GodotPath"
    exit 97
  }
  $godot = (Resolve-Path -LiteralPath $GodotPath).Path
} else {
  $candidates = @(
    'C:\Program Files\godot4\Godot_v4.6.2-stable_win64_console.exe',
    'C:\Users\andre\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
  )
  $godot = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
  if (-not $godot) {
    Write-Error 'Godot console binary not found in known locations'
    exit 97
  }
}

if ($PSBoundParameters.ContainsKey('ProjectRoot')) {
  if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    Write-Error "Project root not found: $ProjectRoot"
    exit 97
  }
  $proj = (Resolve-Path -LiteralPath $ProjectRoot).Path
} else {
  $proj = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
}

$projectFile = Join-Path $proj 'project.godot'
if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
  Write-Error "Project file not found: $projectFile"
  exit 97
}
$projectFile = (Resolve-Path -LiteralPath $projectFile).Path

$profileRoot = Join-Path $proj ('.tmp\run-game-user-data-' + [guid]::NewGuid().ToString('N'))
$appData = Join-Path $profileRoot 'APPDATA'
$localAppData = Join-Path $profileRoot 'LOCALAPPDATA'
$hadAppData = Test-Path Env:APPDATA
$hadLocalAppData = Test-Path Env:LOCALAPPDATA
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA

try {
  New-Item -ItemType Directory -Path $appData, $localAppData -Force | Out-Null
  $env:APPDATA = $appData
  $env:LOCALAPPDATA = $localAppData

  $arguments = @($projectFile)
  if ($QuitAfter -gt 0) {
    $arguments += @('--quit-after', [string]$QuitAfter)
  }
  & $godot @arguments
  $godotExitCode = $LASTEXITCODE
} finally {
  if ($hadAppData) { $env:APPDATA = $oldAppData } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
  if ($hadLocalAppData) { $env:LOCALAPPDATA = $oldLocalAppData } else { Remove-Item Env:LOCALAPPDATA -ErrorAction SilentlyContinue }
}

exit $godotExitCode
