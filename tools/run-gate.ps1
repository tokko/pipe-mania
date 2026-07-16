# Headless GUT gate for the project. Exit 0 = all tests pass.
# Driven inline by crunch (out-of-sandbox); never from a spawned subagent.
param(
  [string]$GodotPath,
  [string]$ProjectRoot
)

$ErrorActionPreference = "Stop"

if ($PSBoundParameters.ContainsKey('GodotPath')) {
  if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    Write-Error "Godot binary not found: $GodotPath"
    exit 97
  }
  $godot = $GodotPath
} else {
  $candidates = @(
    "C:\Program Files\godot4\Godot_v4.6.2-stable_win64_console.exe",
    "C:\Users\andre\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
  )
  $godot = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $godot) { Write-Error "Godot console binary not found in known locations"; exit 97 }
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

$profileRoot = Join-Path $proj ('.tmp\run-gate-user-data-' + [guid]::NewGuid().ToString('N'))
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

  # First run on a fresh checkout: import so GUT class_names register.
  if (-not (Test-Path (Join-Path $proj ".godot"))) {
    & $godot --path $proj --headless --import | Out-Null
  }

  & $godot --path $proj --headless -s res://addons/gut/gut_cmdln.gd '-gdir=res://test' -ginclude_subdirs -gexit
  exit $LASTEXITCODE
} finally {
  if ($hadAppData) { $env:APPDATA = $oldAppData } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
  if ($hadLocalAppData) { $env:LOCALAPPDATA = $oldLocalAppData } else { Remove-Item Env:LOCALAPPDATA -ErrorAction SilentlyContinue }
}
