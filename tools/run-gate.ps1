# Headless GUT gate for the project. Exit 0 = all tests pass.
# Driven inline by crunch (out-of-sandbox); never from a spawned subagent.
$ErrorActionPreference = "Stop"

$candidates = @(
  "C:\Program Files\godot4\Godot_v4.6.2-stable_win64_console.exe",
  "C:\Users\andre\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
)
$godot = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $godot) { Write-Error "Godot console binary not found in known locations"; exit 97 }

$proj = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $proj ".tmp\godot-logging"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$importLog = Join-Path $proj ".tmp\godot-logging\import.log"
$gutLog = Join-Path $proj ".tmp\godot-logging\gut.log"

# First run on a fresh checkout: import so GUT class_names register.
if (-not (Test-Path (Join-Path $proj ".godot"))) {
  & $godot --log-file $importLog --path $proj --headless --import | Out-Null
}

& $godot --log-file $gutLog --path $proj --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
exit $LASTEXITCODE
