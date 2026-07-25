param(
    [Parameter(Mandatory = $true)] [string]$ScenarioPath,
    [ValidateSet('raw', 'projection')] [string]$TraceMode = 'raw',
    [string]$GodotPath,
    [string]$ProjectRoot,
    [ValidateRange(1, [int]::MaxValue)] [int]$TimeoutMs = 30000,
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

function Test-ExactKeys($Object, [string[]]$Expected) {
    if ($null -eq $Object) { return $false }
    $actual = @($Object.PSObject.Properties.Name | Sort-Object)
    $expected = @($Expected | Sort-Object)
    return $actual.Count -eq $expected.Count -and (($actual -join "`n") -eq ($expected -join "`n"))
}

function Test-IsInteger($Value) {
    if ($null -eq $Value) { return $false }
    if ($Value -is [byte] -or $Value -is [sbyte] -or $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or $Value -is [int64] -or $Value -is [uint64]) {
        return $true
    }
    if ($Value -is [decimal]) { return $Value -eq [math]::Floor([double]$Value) }
    if ($Value -is [single] -or $Value -is [double]) {
        $number = [double]$Value
        return -not [double]::IsNaN($number) -and -not [double]::IsInfinity($number) -and $number -eq [math]::Floor($number)
    }
    return $false
}

function Test-ScenarioEnvelope($Scenario) {
    $envelopeKeys = @('schema_version', 'scenario_id', 'seed', 'tick_hz', 'max_ticks', 'steps')
    $stepKeys = @('tick', 'action', 'args')
    if (-not (Test-ExactKeys $Scenario $envelopeKeys)) { return 'scenario envelope keys are not exact' }
    if ($Scenario.scenario_id -isnot [string] -or $Scenario.scenario_id.Length -lt 1 -or $Scenario.scenario_id.Length -gt 128) {
        return 'scenario_id must be a UTF-8 string of 1..128 characters'
    }
    if (-not (Test-IsInteger $Scenario.schema_version) -or -not (Test-IsInteger $Scenario.seed) -or
        -not (Test-IsInteger $Scenario.tick_hz) -or -not (Test-IsInteger $Scenario.max_ticks)) {
        return 'scenario envelope values must be integers'
    }
    if ([int64]$Scenario.schema_version -ne 1) { return 'scenario envelope value out of range' }
    if ($Scenario.seed -lt 0 -or $Scenario.seed -gt 2147483647 -or $Scenario.tick_hz -ne 60 -or
        $Scenario.max_ticks -lt 1 -or $Scenario.max_ticks -gt 3600) {
        return 'scenario envelope value out of range'
    }
    if ($Scenario.steps -isnot [array] -or $Scenario.steps.Count -lt 1 -or $Scenario.steps.Count -gt 256) {
        return 'steps must contain 1..256 entries'
    }
    $previous = -1
    foreach ($step in $Scenario.steps) {
        if (-not (Test-ExactKeys $step $stepKeys)) { return 'step keys are not exact' }
        if (-not (Test-IsInteger $step.tick) -or $step.tick -lt 0 -or $step.tick -ge $Scenario.max_ticks -or $step.tick -lt $previous) {
            return 'step ticks must increase within max_ticks'
        }
        if ($step.action -isnot [string]) { return 'step action is not a string' }
        if ($null -eq $step.args -or $step.args -is [array] -or $step.args -isnot [pscustomobject]) { return 'step args must be an object' }
        $previous = [int64]$step.tick
    }
    return $null
}

function Test-PathUnderRoot([string]$Path, [string]$Root) {
    $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    return $fullPath.Equals($fullRoot, [StringComparison]::OrdinalIgnoreCase) -or
        $fullPath.StartsWith($fullRoot + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Stop-SpawnedProcess($Process) {
    if ($null -eq $Process) { return }
    try {
        if (-not $Process.HasExited) {
            & taskkill.exe /PID $Process.Id /T /F 2>$null | Out-Null
            [void]$Process.WaitForExit(3000)
            if (-not $Process.HasExited) { try { $Process.Kill() } catch { } }
            [void]$Process.WaitForExit(3000)
        }
    } catch { }
    try { $Process.Dispose() } catch { }
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
$seed = 0
$envelopeError = Test-ScenarioEnvelope $scenario
if ($null -ne $envelopeError) {
    $trace = New-Trace 2 'scenario_error' 'INVALID_ENVELOPE' $envelopeError $scenarioId $seed
    $rawText = $trace | ConvertTo-Json -Compress -Depth 10
    Write-Output $rawText
    exit 2
}
$seed = [int]$scenario.seed

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
$importProcess = $null
$process = $null
$rawText = $null
$processExit = 3
$importTimedOut = $false

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
        [void]$importProcess.WaitForExit(3000)
        $trace = New-Trace 3 'engine_error' 'ENGINE_FAILED' 'Godot resource import timed out' $scenarioId $seed
        $rawText = $trace | ConvertTo-Json -Compress -Depth 10
        $processExit = 3
        $importTimedOut = $true
    }
    Stop-SpawnedProcess $importProcess
    $importProcess = $null
    if (-not $importTimedOut) {
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
        [void]$process.WaitForExit(3000)
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
    }
} finally {
    Stop-SpawnedProcess $process
    Stop-SpawnedProcess $importProcess
    if ($hadAppData) { $env:APPDATA = $oldAppData } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    if ($hadLocalAppData) { $env:LOCALAPPDATA = $oldLocalAppData } else { Remove-Item Env:LOCALAPPDATA -ErrorAction SilentlyContinue }
    if ((Test-Path -LiteralPath $profileRoot -PathType Container) -and (Test-PathUnderRoot $profileRoot $ProjectRoot)) {
        Remove-Item -LiteralPath $profileRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
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
$hashAlgorithm = [Security.Cryptography.SHA256]::Create()
try {
    $hashInput = [Text.UTF8Encoding]::new($false).GetBytes($scenarioPath + "`n" + [IO.File]::ReadAllText($scenarioPath))
    $scenarioHash = ([BitConverter]::ToString($hashAlgorithm.ComputeHash($hashInput))).Replace('-', '').ToLowerInvariant()
} finally {
    $hashAlgorithm.Dispose()
}
$artifactStem = $stem + '-' + $scenarioHash.Substring(0, 12)
$encoding = [Text.UTF8Encoding]::new($false)
$rawPath = Join-Path $OutputDirectory ($artifactStem + '.raw.json')
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
$projectionPath = Join-Path $OutputDirectory ($artifactStem + '.projection.json')
[IO.File]::WriteAllText($projectionPath, $projectionText, $encoding)
(Get-FileHash -LiteralPath $rawPath -Algorithm SHA256).Hash.ToLowerInvariant() | Set-Content -LiteralPath (Join-Path $OutputDirectory ($artifactStem + '.raw.sha256')) -Encoding ascii -NoNewline
(Get-FileHash -LiteralPath $projectionPath -Algorithm SHA256).Hash.ToLowerInvariant() | Set-Content -LiteralPath (Join-Path $OutputDirectory ($artifactStem + '.projection.sha256')) -Encoding ascii -NoNewline

if ($TraceMode -eq 'projection') { Write-Output $projectionText } else { Write-Output $rawText }
exit $processExit
