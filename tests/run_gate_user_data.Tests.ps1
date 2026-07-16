$ErrorActionPreference = 'Stop'

function ConvertTo-PowerShellLiteral {
    param([string]$Value)

    return "'" + $Value.Replace("'", "''") + "'"
}

function Test-PathUnderRoot {
    param(
        [string]$Path,
        [string]$Root
    )

    $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')

    return $fullPath.Equals($fullRoot, [StringComparison]::OrdinalIgnoreCase) -or
        $fullPath.StartsWith($fullRoot + '\', [StringComparison]::OrdinalIgnoreCase)
}

Describe 'tools/run-gate.ps1 user-data isolation' {
    BeforeEach {
        $script:fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('pipe-mania-run-gate-' + [guid]::NewGuid().ToString('N'))
        $script:projectRoot = Join-Path $script:fixtureRoot 'project'
        $script:callerAppData = Join-Path $script:fixtureRoot 'caller-appdata'
        $script:callerLocalAppData = Join-Path $script:fixtureRoot 'caller-localappdata'
        $script:fakeGodot = Join-Path $script:fixtureRoot 'fake-godot.ps1'
        $script:fakeGodotLog = Join-Path $script:fixtureRoot 'fake-godot.jsonl'
        $script:childScript = Join-Path $script:fixtureRoot 'invoke-run-gate.ps1'

        New-Item -ItemType Directory -Path $script:projectRoot, $script:callerAppData, $script:callerLocalAppData -Force | Out-Null

        @'
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$record = [ordered]@{
    Arguments = @($Arguments)
    APPDATA = $env:APPDATA
    LOCALAPPDATA = $env:LOCALAPPDATA
    AppDataExists = Test-Path -LiteralPath $env:APPDATA -PathType Container
    LocalAppDataExists = Test-Path -LiteralPath $env:LOCALAPPDATA -PathType Container
}
$record | ConvertTo-Json -Compress | Add-Content -LiteralPath $env:FAKE_GODOT_LOG

if (@($Arguments) -contains '-s') {
    exit ([int]$env:FAKE_GUT_EXIT)
}
exit 0
'@ | Set-Content -LiteralPath $script:fakeGodot -Encoding UTF8

        $runGate = Join-Path $PSScriptRoot '..\tools\run-gate.ps1'
        $realCandidateOne = ConvertTo-PowerShellLiteral 'C:\Program Files\godot4\Godot_v4.6.2-stable_win64_console.exe'
        $realCandidateTwo = ConvertTo-PowerShellLiteral 'C:\Users\andre\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
        $driver = @'
$ErrorActionPreference = 'Continue'
$env:APPDATA = __CALLER_APPDATA__
$env:LOCALAPPDATA = __CALLER_LOCALAPPDATA__
$env:FAKE_GODOT_LOG = __FAKE_GODOT_LOG__
$env:FAKE_GUT_EXIT = '23'

function Test-Path {
    param(
        [Parameter(Position = 0)]
        [string]$Path,
        [string]$LiteralPath,
        [ValidateSet('Any', 'Container', 'Leaf')]
        [string]$PathType
    )

    $target = if ($PSBoundParameters.ContainsKey('LiteralPath')) { $LiteralPath } else { $Path }
    if ($target -eq __REAL_CANDIDATE_ONE__ -or $target -eq __REAL_CANDIDATE_TWO__) {
        return $false
    }

    $testParameters = @{}
    if ($PSBoundParameters.ContainsKey('LiteralPath')) {
        $testParameters.LiteralPath = $LiteralPath
    } else {
        $testParameters.Path = $Path
    }
    if ($PSBoundParameters.ContainsKey('PathType')) {
        $testParameters.PathType = $PathType
    }
    return Microsoft.PowerShell.Management\Test-Path @testParameters
}

& __RUN_GATE__ -GodotPath __FAKE_GODOT__ -ProjectRoot __PROJECT_ROOT__
exit $LASTEXITCODE
'@
        $driver = $driver.Replace('__CALLER_APPDATA__', (ConvertTo-PowerShellLiteral $script:callerAppData))
        $driver = $driver.Replace('__CALLER_LOCALAPPDATA__', (ConvertTo-PowerShellLiteral $script:callerLocalAppData))
        $driver = $driver.Replace('__FAKE_GODOT_LOG__', (ConvertTo-PowerShellLiteral $script:fakeGodotLog))
        $driver = $driver.Replace('__REAL_CANDIDATE_ONE__', $realCandidateOne)
        $driver = $driver.Replace('__REAL_CANDIDATE_TWO__', $realCandidateTwo)
        $driver = $driver.Replace('__RUN_GATE__', (ConvertTo-PowerShellLiteral ([IO.Path]::GetFullPath($runGate))))
        $driver = $driver.Replace('__FAKE_GODOT__', (ConvertTo-PowerShellLiteral $script:fakeGodot))
        $driver = $driver.Replace('__PROJECT_ROOT__', (ConvertTo-PowerShellLiteral $script:projectRoot))
        $driver | Set-Content -LiteralPath $script:childScript -Encoding UTF8
    }

    It 'isolates APPDATA and LOCALAPPDATA for import and GUT invocations' {
        $null = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:childScript 2>&1)
        $wrapperExitCode = $LASTEXITCODE

        $wrapperExitCode | Should Be 23
        (Test-Path -LiteralPath $script:fakeGodotLog -PathType Leaf) | Should Be $true

        $records = @(
            Get-Content -LiteralPath $script:fakeGodotLog |
                Where-Object { $_.Trim().Length -gt 0 } |
                ForEach-Object { $_ | ConvertFrom-Json }
        )
        $records.Count | Should Be 2

        $importRecords = @($records | Where-Object { @($_.Arguments) -notcontains '-s' })
        $gutRecords = @($records | Where-Object { @($_.Arguments) -contains '-s' })
        $importRecords.Count | Should Be 1
        $gutRecords.Count | Should Be 1

        foreach ($record in $records) {
            $record.AppDataExists | Should Be $true
            $record.LocalAppDataExists | Should Be $true
            (Test-PathUnderRoot $record.APPDATA $script:projectRoot) | Should Be $true
            (Test-PathUnderRoot $record.LOCALAPPDATA $script:projectRoot) | Should Be $true
            $record.APPDATA | Should Not Be $script:callerAppData
            $record.LOCALAPPDATA | Should Not Be $script:callerLocalAppData
        }

        $expectedGutArguments = @(
            '--path', $script:projectRoot,
            '--headless',
            '-s', 'res://addons/gut/gut_cmdln.gd',
            '-gdir=res://test',
            '-ginclude_subdirs',
            '-gexit'
        )
        ($gutRecords[0].Arguments -join "`n") | Should Be ($expectedGutArguments -join "`n")
    }

    AfterEach {
        if ($script:fixtureRoot -and (Test-Path -LiteralPath $script:fixtureRoot)) {
            Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
