param(
    [Parameter(Mandatory = $true)] [string]$ScenarioPath,
    [ValidateSet('raw', 'projection')] [string]$TraceMode = 'raw',
    [string]$GodotPath,
    [string]$ProjectRoot,
    [int]$TimeoutMs = 30000,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

function Quote-Arg([string]$Value) {
    return '"' + $Value.Replace('"', '\"') + '"'
}

function New-Trace([int]$ExitCode, [string]$ExitName, [string]$Code, [string]$Message, [string]$ScenarioId = 'invalid-scenario', [int]$Seed = 0) {
    return [ordered]@{
        schema_version = 1
        scenario_id = $ScenarioId
        engine = [ordered]@{ name = 'Aqueduct'; version = 'structured-playtest-1' }
        seed = $Seed
        ticks_executed = 0
        exit = $ExitName
        events = @()
        final_state = [ordered]@{ available = $false; screen = $null; phase = $null; occupied_count = $null }
        errors = @([ordered]@{ code = $Code; message = $Message })
    }
}

if (-not (Test-Path -LiteralPath $ScenarioPath -PathType Leaf)) {
    $trace = New-Trace 2 'scenario_error' 'MISSING_TRACE' 'scenario file was not found'
    $rawText = $trace | ConvertTo-Json -Compress -Depth 10
    Write-Output $rawText
    exit 2
}
$scenarioPath = (Resolve-Path -LiteralPath $ScenarioPath).Path
$scenario = $null
try { $scenario = Get-Content -LiteralPath $scenarioPath -Raw | ConvertFrom-Json } catch {
    $trace = New-Trace 2 'scenario_error' 'MALFORMED_TRACE' 'scenario is not valid JSON'
    $rawText = $trace | ConvertTo-Json -Compress -Depth 10
    Write-Output $rawText
    exit 2
}
$scenarioId = if ($scenario.scenario_id -is [string] -and $scenario.scenario_id.Length -ge 1 -and $scenario.scenario_id.Length -le 128) { [string]$scenario.scenario_id } else { 'invalid-scenario' }
$seed = if ($scenario.seed -is [int] -or $scenario.seed -is [long] -or $scenario.seed -is [double]) { [int]$scenario.seed } else { 0 }
if ($scenarioId -eq 'invalid-scenario' -or $seed -eq 0 -and $scenario.seed -ne 0) { $scenarioId = 'invalid-scenario'; $seed = 0 }

if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
if (-not $GodotPath) {
    $candidates = @(
        'C:\Program Files\godot4\Godot_v4.6.2-stable_win64_console.exe',
        'C:\Users\andre\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
    )
    $GodotPath = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    $trace = New-Trace 3 'engine_error' 'ENGINE_FAILED' 'Godot console binary was not found' $scenarioId $seed
    $rawText = $trace | ConvertTo-Json -Compress -Depth 10
    Write-Output $rawText
    exit 3
}

$profileRoot = Join-Path $ProjectRoot ('.tmp\structured-playtest-user-data-' + [guid]::NewGuid().ToString('N'))
$appData = Join-Path $profileRoot 'APPDATA'
$localAppData = Join-Path $profileRoot 'LOCALAPPDATA'
$hadAppData = Test-Path Env:APPDATA
$hadLocalAppData = Test-Path Env:LOCALAPPDATA
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
$process = $null
$rawText = $null
$processExit = 3

try {
    New-Item -ItemType Directory -Path $appData, $localAppData -Force | Out-Null
    $env:APPDATA = $appData
    $env:LOCALAPPDATA = $localAppData
    # A fresh isolated profile must still import the shipped icon/resource cache before loading main.tscn.
    $importPsi = [Diagnostics.ProcessStartInfo]::new()
    $importPsi.FileName = (Resolve-Path -LiteralPath $GodotPath).Path
    $importPsi.Arguments = '--headless --path ' + (Quote-Arg $ProjectRoot) + ' --import'
    $importPsi.UseShellExecute = $false
    $importPsi.CreateNoWindow = $true
    $importPsi.RedirectStandardOutput = $true
    $importPsi.RedirectStandardError = $true
    $importProcess = [Diagnostics.Process]::new()
    $importProcess.StartInfo = $importPsi
    [void]$importProcess.Start()
    $importProcess.StandardOutput.ReadToEndAsync() | Out-Null
    $importProcess.StandardError.ReadToEndAsync() | Out-Null
    if (-not $importProcess.WaitForExit($TimeoutMs)) {
        & taskkill.exe /PID $importProcess.Id /T /F 2>$null | Out-Null
        $importProcess.WaitForExit(3000)
        $importProcess.Dispose()
        $trace = New-Trace 3 'engine_error' 'ENGINE_FAILED' 'Godot resource import timed out' $scenarioId $seed
        $rawText = $trace | ConvertTo-Json -Compress -Depth 10
        $processExit = 3
        throw 'structured-playtest import timed out'
    }
    $importProcess.Dispose()
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = (Resolve-Path -LiteralPath $GodotPath).Path
    $psi.Arguments = '--headless --path ' + (Quote-Arg $ProjectRoot) + ' -s res://scripts/structured_playtest_runner.gd --scenario ' + (Quote-Arg $scenarioPath)
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutMs)) {
        & taskkill.exe /PID $process.Id /T /F 2>$null | Out-Null
        $process.WaitForExit(3000)
        $remaining = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
        if ($remaining) { try { $remaining.Kill() } catch { } }
        $process.WaitForExit()
        $trace = New-Trace 4 'timeout' 'WALL_TIMEOUT' ('process exceeded %d ms' -f $TimeoutMs) $scenarioId $seed
        $rawText = $trace | ConvertTo-Json -Compress -Depth 10
        $processExit = 4
    } else {
        $processExit = $process.ExitCode
        $stdoutText = $stdoutTask.Result
        $jsonLines = @($stdoutText -split "`r?`n" | Where-Object { $_.TrimStart().StartsWith('{') })
        $rawText = if ($jsonLines.Count -gt 0) { $jsonLines[$jsonLines.Count - 1].Trim() } else { '' }
        if ([string]::IsNullOrWhiteSpace($rawText)) {
            $trace = New-Trace 3 'engine_error' 'MISSING_TRACE' 'runner produced no trace' $scenarioId $seed
            $rawText = $trace | ConvertTo-Json -Compress -Depth 10
            $processExit = 3
        }
    }
} finally {
    if ($process) { $process.Dispose() }
    if ($hadAppData) { $env:APPDATA = $oldAppData } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    if ($hadLocalAppData) { $env:LOCALAPPDATA = $oldLocalAppData } else { Remove-Item Env:LOCALAPPDATA -ErrorAction SilentlyContinue }
}

$traceObject = $null
try { $traceObject = $rawText | ConvertFrom-Json } catch {
    $traceObject = New-Trace 3 'engine_error' 'MALFORMED_TRACE' 'runner output was not a JSON trace' $scenarioId $seed
    $rawText = $traceObject | ConvertTo-Json -Compress -Depth 10
    $processExit = 3
}

if (-not $OutputDirectory) { $OutputDirectory = Join-Path $ProjectRoot '.tmp\structured-playtest-traces' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$stem = [IO.Path]::GetFileNameWithoutExtension($scenarioPath)
$encoding = [Text.UTF8Encoding]::new($false)
$rawPath = Join-Path $OutputDirectory ($stem + '.raw.json')
[IO.File]::WriteAllText($rawPath, $rawText, $encoding)

$projection = [ordered]@{
    schema_version = [int]$traceObject.schema_version
    scenario_id = [string]$traceObject.scenario_id
    engine = [ordered]@{ name = [string]$traceObject.engine.name }
    seed = [int]$traceObject.seed
    ticks_executed = [int]$traceObject.ticks_executed
    exit = [string]$traceObject.exit
    events = @($traceObject.events)
    final_state = [ordered]@{ available = [bool]$traceObject.final_state.available; screen = $traceObject.final_state.screen; phase = $traceObject.final_state.phase; occupied_count = $traceObject.final_state.occupied_count }
    errors = @($traceObject.errors)
}
$projectionText = $projection | ConvertTo-Json -Compress -Depth 20
$projectionPath = Join-Path $OutputDirectory ($stem + '.projection.json')
[IO.File]::WriteAllText($projectionPath, $projectionText, $encoding)
(Get-FileHash -LiteralPath $rawPath -Algorithm SHA256).Hash.ToLowerInvariant() | Set-Content -LiteralPath (Join-Path $OutputDirectory ($stem + '.raw.sha256')) -Encoding ascii -NoNewline
(Get-FileHash -LiteralPath $projectionPath -Algorithm SHA256).Hash.ToLowerInvariant() | Set-Content -LiteralPath (Join-Path $OutputDirectory ($stem + '.projection.sha256')) -Encoding ascii -NoNewline

if ($TraceMode -eq 'projection') { Write-Output $projectionText } else { Write-Output $rawText }
exit $processExit
