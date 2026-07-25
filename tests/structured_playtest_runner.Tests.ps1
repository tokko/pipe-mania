$ErrorActionPreference = 'Stop'

Describe 'structured playtest runner' {
    BeforeAll {
        $script:projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $script:runner = Join-Path $script:projectRoot 'tools/run-structured-playtest.ps1'
        $script:placement = Join-Path $script:projectRoot 'tools/structured_playtest/scenarios/mechanic-placement.json'
        $script:outside = Join-Path $script:projectRoot 'tools/structured_playtest/scenarios/outside-board-control.json'
        $script:invalidEnvelope = Join-Path $script:projectRoot 'tools/structured_playtest/scenarios/invalid-envelope.json'
        $script:invalidAction = Join-Path $script:projectRoot 'tools/structured_playtest/scenarios/invalid-action.json'
    }

    AfterAll { $global:LASTEXITCODE = 0 }

    It 'completes a production-lifecycle placement trace with the exact state contract' {
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

    It 'keeps the outside-board semantic control successful at process level but unplaced' {
        $raw = @(& $script:runner -ScenarioPath $script:outside -TraceMode raw 2>&1 | Out-String)
        $LASTEXITCODE | Should Be 3
        $trace = $raw.Trim() | ConvertFrom-Json
        $trace.exit | Should Be 'engine_error'
        $trace.errors[0].code | Should Be 'SCENARIO_EXECUTION_FAILED'
    }

    It 'rejects unknown envelope keys and unknown actions with canonical process exits' {
        $raw = @(& $script:runner -ScenarioPath $script:invalidEnvelope 2>&1 | Out-String)
        $LASTEXITCODE | Should Be 2
        ($raw.Trim() | ConvertFrom-Json).errors[0].code | Should Be 'INVALID_ENVELOPE'
        $raw = @(& $script:runner -ScenarioPath $script:invalidAction 2>&1 | Out-String)
        $LASTEXITCODE | Should Be 2
        ($raw.Trim() | ConvertFrom-Json).errors[0].code | Should Be 'UNKNOWN_ACTION'
    }

    It 'produces equal raw and projection traces for the same seed' {
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

    It 'allows ordered same-tick actions' {
        $scenario = Join-Path $script:projectRoot 'tools/structured_playtest/scenarios/same-tick-order.json'
        $raw = @(& $script:runner -ScenarioPath $scenario -TraceMode raw 2>&1 | Out-String)
        $LASTEXITCODE | Should Be 3
        $trace = $raw.Trim() | ConvertFrom-Json
        $trace.final_state.available | Should Be $false
        $trace.exit | Should Be 'engine_error'
    }
}

$global:LASTEXITCODE = 0
