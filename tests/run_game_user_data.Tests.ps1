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

Describe 'tools/run-game.ps1 visible shipped-game launch' {
    BeforeEach {
        $script:fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('pipe-mania-run-game-' + [guid]::NewGuid().ToString('N'))
        $script:projectRoot = Join-Path $script:fixtureRoot 'project'
        $script:projectPath = Join-Path $script:projectRoot 'project.godot'
        $script:callerAppData = Join-Path $script:fixtureRoot 'caller-appdata'
        $script:callerLocalAppData = Join-Path $script:fixtureRoot 'caller-localappdata'
        $script:fakeGodot = Join-Path $script:fixtureRoot 'fake-godot.ps1'
        $script:fakeGodotLog = Join-Path $script:fixtureRoot 'fake-godot.json'
        $script:childScript = Join-Path $script:fixtureRoot 'invoke-run-game.ps1'
        $script:quitAfter = 5

        New-Item -ItemType Directory -Path $script:projectRoot, $script:callerAppData, $script:callerLocalAppData -Force | Out-Null

        @'
config_version=5

[application]

config/name="Pipe Mania fixture"
run/main_scene="res://scenes/main.tscn"
'@ | Set-Content -LiteralPath $script:projectPath -Encoding UTF8

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
$record | ConvertTo-Json -Compress | Set-Content -LiteralPath $env:FAKE_GODOT_LOG -Encoding UTF8
exit ([int]$env:FAKE_GODOT_EXIT)
'@ | Set-Content -LiteralPath $script:fakeGodot -Encoding UTF8

        $runGame = Join-Path $PSScriptRoot '..\tools\run-game.ps1'
        $driver = @'
$ErrorActionPreference = 'Stop'
$env:APPDATA = __CALLER_APPDATA__
$env:LOCALAPPDATA = __CALLER_LOCALAPPDATA__
$env:FAKE_GODOT_LOG = __FAKE_GODOT_LOG__
$env:FAKE_GODOT_EXIT = '23'

& __RUN_GAME__ -GodotPath __FAKE_GODOT__ -ProjectRoot __PROJECT_ROOT__ -QuitAfter __QUIT_AFTER__
exit $LASTEXITCODE
'@
        $driver = $driver.Replace('__CALLER_APPDATA__', (ConvertTo-PowerShellLiteral $script:callerAppData))
        $driver = $driver.Replace('__CALLER_LOCALAPPDATA__', (ConvertTo-PowerShellLiteral $script:callerLocalAppData))
        $driver = $driver.Replace('__FAKE_GODOT_LOG__', (ConvertTo-PowerShellLiteral $script:fakeGodotLog))
        $driver = $driver.Replace('__RUN_GAME__', (ConvertTo-PowerShellLiteral ([IO.Path]::GetFullPath($runGame))))
        $driver = $driver.Replace('__FAKE_GODOT__', (ConvertTo-PowerShellLiteral $script:fakeGodot))
        $driver = $driver.Replace('__PROJECT_ROOT__', (ConvertTo-PowerShellLiteral $script:projectRoot))
        $driver = $driver.Replace('__QUIT_AFTER__', [string]$script:quitAfter)
        $driver | Set-Content -LiteralPath $script:childScript -Encoding UTF8
    }

    It 'runs the configured main scene visibly with isolated user data and propagates Godot exit code' {
        $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:childScript 2>&1)
        $wrapperExitCode = $LASTEXITCODE

        $wrapperExitCode | Should Be 23
        (Test-Path -LiteralPath $script:fakeGodotLog -PathType Leaf) | Should Be $true

        $record = Get-Content -LiteralPath $script:fakeGodotLog -Raw | ConvertFrom-Json
        $arguments = @($record.Arguments)
        $expectedArguments = @($script:projectPath, '--quit-after', [string]$script:quitAfter)

        ($arguments -join "`n") | Should Be ($expectedArguments -join "`n")
        $arguments.Count | Should Be 3
        ($arguments -contains '--headless') | Should Be $false
        ($arguments -contains '--editor') | Should Be $false
        ($arguments -contains '-s') | Should Be $false
        @($arguments | Where-Object { $_ -match 'gut|test' }).Count | Should Be 0

        $record.AppDataExists | Should Be $true
        $record.LocalAppDataExists | Should Be $true
        (Test-PathUnderRoot $record.APPDATA $script:projectRoot) | Should Be $true
        (Test-PathUnderRoot $record.LOCALAPPDATA $script:projectRoot) | Should Be $true
        $record.APPDATA | Should Not Be $script:callerAppData
        $record.LOCALAPPDATA | Should Not Be $script:callerLocalAppData
    }

    AfterEach {
        $tempRoot = [IO.Path]::GetTempPath()
        if ($script:fixtureRoot -and
            (Test-Path -LiteralPath $script:fixtureRoot) -and
            (Test-PathUnderRoot $script:fixtureRoot $tempRoot)) {
            Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
