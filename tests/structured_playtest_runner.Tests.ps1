$ErrorActionPreference = 'Stop'

Describe 'structured playtest runner (parked: headless UI criteria require visible shipped-UI evidence)' {
    BeforeAll {
        $script:projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $script:runner = Join-Path $script:projectRoot 'tools/run-structured-playtest.ps1'
        $script:placement = Join-Path $script:projectRoot 'tools/structured_playtest/scenarios/mechanic-placement.json'
        $script:outside = Join-Path $script:projectRoot 'tools/structured_playtest/scenarios/outside-board-control.json'
        $script:invalidEnvelope = Join-Path $script:projectRoot 'tools/structured_playtest/scenarios/invalid-envelope.json'
        $script:invalidAction = Join-Path $script:projectRoot 'tools/structured_playtest/scenarios/invalid-action.json'
    }

    AfterAll { $global:LASTEXITCODE = 0 }

    It 'parks the production-lifecycle placement criterion because headless execution cannot prove shipped UI input' {
        $raw = @(& $script:runner -ScenarioPath $script:placement -TraceMode raw 2>&1 | Out-String)
        $LASTEXITCODE | Should Be 3
        $trace = $raw.Trim() | ConvertFrom-Json
        $trace.schema_version | Should Be 1
        $trace.scenario_id | Should Be 'mechanic-placement'
        $trace.exit | Should Be 'engine_error'
        $trace.errors[0].code | Should Be 'SCENARIO_EXECUTION_FAILED'
        @($trace.events).Count | Should Be 0
        $trace.final_state.available | Should Be $false
        foreach ($event in @($trace.events)) {
            @($event.PSObject.Properties.Name | Sort-Object) -join ',' | Should Be 'data,tick,type'
        }
    }

    It 'parks the outside-board shipped-UI criterion while retaining its headless semantic control' {
        $raw = @(& $script:runner -ScenarioPath $script:outside -TraceMode raw 2>&1 | Out-String)
        $LASTEXITCODE | Should Be 3
        $trace = $raw.Trim() | ConvertFrom-Json
        $trace.exit | Should Be 'engine_error'
        $trace.errors[0].code | Should Be 'SCENARIO_EXECUTION_FAILED'
    }

    It 'rejects unknown envelope keys and unknown actions with canonical process exits (headless contract only)' {
        $raw = @(& $script:runner -ScenarioPath $script:invalidEnvelope 2>&1 | Out-String)
        $LASTEXITCODE | Should Be 2
        ($raw.Trim() | ConvertFrom-Json).errors[0].code | Should Be 'INVALID_ENVELOPE'
        $raw = @(& $script:runner -ScenarioPath $script:invalidAction 2>&1 | Out-String)
        $LASTEXITCODE | Should Be 2
        ($raw.Trim() | ConvertFrom-Json).errors[0].code | Should Be 'UNKNOWN_ACTION'
    }

    It 'produces equal raw and projection traces for the same seed (headless projection criterion parked)' {
        $raw = @(& $script:runner -ScenarioPath $script:placement -TraceMode raw 2>&1 | Out-String)
        $rawExit = $LASTEXITCODE
        $projection = @(& $script:runner -ScenarioPath $script:placement -TraceMode projection 2>&1 | Out-String)
        $projectionExit = $LASTEXITCODE
        $rawExit | Should Be 3
        $projectionExit | Should Be 3
        $a = $raw.Trim() | ConvertFrom-Json
        $b = $projection.Trim() | ConvertFrom-Json
        $a.final_state.available | Should Be $b.final_state.available
        $a.final_state.screen | Should Be $b.final_state.screen
        $a.final_state.phase | Should Be $b.final_state.phase
        $a.final_state.occupied_count | Should Be $b.final_state.occupied_count
        $a.events.Count | Should Be $b.events.Count
        $a.seed | Should Be $b.seed
    }

    It 'allows ordered same-tick actions (headless ordering criterion parked pending visible UI proof)' {
        $scenario = Join-Path $script:projectRoot 'tools/structured_playtest/scenarios/same-tick-order.json'
        $raw = @(& $script:runner -ScenarioPath $scenario -TraceMode raw 2>&1 | Out-String)
        $LASTEXITCODE | Should Be 3
        $trace = $raw.Trim() | ConvertFrom-Json
        $trace.final_state.available | Should Be $false
        $trace.exit | Should Be 'engine_error'
    }

    It 'serializes a canonical failure trace when resource import times out (headless failure contract)' {
        $fakeGodot = Join-Path $TestDrive 'fake-godot.exe'
        Add-Type -TypeDefinition 'using System.Threading; public static class FakeGodot { public static void Main(string[] args) { Thread.Sleep(5000); } }' -OutputAssembly $fakeGodot -OutputType ConsoleApplication
        $outputDirectory = Join-Path $TestDrive 'traces'
        $raw = @(& $script:runner -ScenarioPath $script:placement -GodotPath $fakeGodot -TimeoutMs 20 -OutputDirectory $outputDirectory 2>&1 | Out-String)

        $LASTEXITCODE | Should Be 3
        $trace = $raw.Trim() | ConvertFrom-Json
        $trace.schema_version | Should Be 1
        $trace.scenario_id | Should Be 'mechanic-placement'
        $trace.exit | Should Be 'engine_error'
        $trace.errors[0].code | Should Be 'ENGINE_FAILED'
        $trace.errors[0].message | Should Be 'Godot resource import timed out'
        @(Get-ChildItem -LiteralPath $outputDirectory -Filter 'mechanic-placement-*.raw.json').Count | Should Be 1
        @(Get-ChildItem -LiteralPath $outputDirectory -Filter 'mechanic-placement-*.projection.json').Count | Should Be 1
        @(Get-ChildItem -LiteralPath $outputDirectory -Filter 'mechanic-placement-*.raw.sha256').Count | Should Be 1
        @(Get-ChildItem -LiteralPath $outputDirectory -Filter 'mechanic-placement-*.projection.sha256').Count | Should Be 1
    }

    It 'rejects a non-positive timeout through canonical parameter validation before launching Godot' {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:runner `
                -ScenarioPath $script:placement -GodotPath (Join-Path $TestDrive 'missing-godot.exe') -TimeoutMs 0 2>&1 | Out-String)
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        $LASTEXITCODE | Should Not Be 0
        ($output -join "`n") | Should Match 'TimeoutMs'
        ($output -join "`n") | Should Match 'minimum allowed range of 1'
    }

    It 'rejects a fractional seed before import with INVALID_ENVELOPE and process exit 2' {
        $fractionalPath = Join-Path $TestDrive 'fractional-seed.json'
        $scenario = Get-Content -LiteralPath $script:placement -Raw | ConvertFrom-Json
        $scenario.seed = 12.5
        $scenario | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $fractionalPath -Encoding UTF8
        $fakeGodot = Join-Path $TestDrive 'fake-godot.exe'
        Add-Type -TypeDefinition 'using System.Threading; public static class FakeGodot { public static void Main(string[] args) { Thread.Sleep(5000); } }' -OutputAssembly $fakeGodot -OutputType ConsoleApplication

        $raw = @(& $script:runner -ScenarioPath $fractionalPath -GodotPath $fakeGodot -TimeoutMs 20 -OutputDirectory (Join-Path $TestDrive 'traces') 2>&1 | Out-String)

        $LASTEXITCODE | Should Be 2
        ($raw.Trim() | ConvertFrom-Json).errors[0].code | Should Be 'INVALID_ENVELOPE'
    }

    It 'removes the isolated profile after spawned processes are stopped' {
        $fakeGodot = Join-Path $TestDrive 'fake-godot.exe'
        Add-Type -TypeDefinition 'using System.Threading; public static class FakeGodot { public static void Main(string[] args) { Thread.Sleep(5000); } }' -OutputAssembly $fakeGodot -OutputType ConsoleApplication
        $outputDirectory = Join-Path $TestDrive 'traces'
        $profileDirectory = Join-Path $script:projectRoot '.tmp'
        New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
        $before = @(Get-ChildItem -LiteralPath $profileDirectory -Directory -Filter 'structured-playtest-user-data-*' | ForEach-Object Name)

        $null = @(& $script:runner -ScenarioPath $script:placement -GodotPath $fakeGodot -TimeoutMs 20 -OutputDirectory $outputDirectory 2>&1 | Out-String)

        $LASTEXITCODE | Should Be 3
        $after = @(Get-ChildItem -LiteralPath $profileDirectory -Directory -Filter 'structured-playtest-user-data-*' | ForEach-Object Name)
        ($after -join "`n") | Should Be ($before -join "`n")
    }

    It 'uses distinct deterministic sidecars for same-basename scenarios' {
        $scenarioDirectoryA = Join-Path $TestDrive 'a'
        $scenarioDirectoryB = Join-Path $TestDrive 'b'
        New-Item -ItemType Directory -Path $scenarioDirectoryA, $scenarioDirectoryB -Force | Out-Null
        $scenarioA = Join-Path $scenarioDirectoryA 'shared.json'
        $scenarioB = Join-Path $scenarioDirectoryB 'shared.json'
        $first = Get-Content -LiteralPath $script:placement -Raw | ConvertFrom-Json
        $second = Get-Content -LiteralPath $script:placement -Raw | ConvertFrom-Json
        $second.seed = 8
        $first | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $scenarioA -Encoding UTF8
        $second | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $scenarioB -Encoding UTF8
        $fakeGodot = Join-Path $TestDrive 'fake-godot.exe'
        Add-Type -TypeDefinition 'using System.Threading; public static class FakeGodot { public static void Main(string[] args) { Thread.Sleep(5000); } }' -OutputAssembly $fakeGodot -OutputType ConsoleApplication
        $outputDirectory = Join-Path $TestDrive 'traces'

        $null = @(& $script:runner -ScenarioPath $scenarioA -GodotPath $fakeGodot -TimeoutMs 20 -OutputDirectory $outputDirectory 2>&1 | Out-String)
        $null = @(& $script:runner -ScenarioPath $scenarioB -GodotPath $fakeGodot -TimeoutMs 20 -OutputDirectory $outputDirectory 2>&1 | Out-String)

        @(Get-ChildItem -LiteralPath $outputDirectory -Filter 'shared-*.raw.json').Count | Should Be 2
        @(Get-ChildItem -LiteralPath $outputDirectory -Filter 'shared-*.projection.json').Count | Should Be 2
        @(Get-ChildItem -LiteralPath $outputDirectory -Filter 'shared-*.raw.sha256').Count | Should Be 2
        @(Get-ChildItem -LiteralPath $outputDirectory -Filter 'shared-*.projection.sha256').Count | Should Be 2
    }
}

$global:LASTEXITCODE = 0
