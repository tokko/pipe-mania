$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$projectText = Get-Content -Raw (Join-Path $repoRoot 'project.godot')
$runGateText = Get-Content -Raw (Join-Path $repoRoot 'tools/run-gate.ps1')
$gitignoreText = Get-Content -Raw (Join-Path $repoRoot '.gitignore')

function Get-GodotInvocationBlocks {
    param([string]$Text)

    $lines = $Text -split "`r?`n"
    $blocks = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch '^\s*&\s*\$godot\b') {
            continue
        }

        $block = $lines[$i]
        while ($block -match '`\s*$' -and ($i + 1) -lt $lines.Count) {
            $i++
            $block += "`n" + $lines[$i]
        }
        $blocks += $block
    }
    return $blocks
}

function Test-ExplicitProjectLogBeforePath {
    param(
        [string]$Invocation,
        [string]$ScriptText,
        [string]$GitIgnoreText
    )

    $normalized = $Invocation -replace '`\s*\r?\n', ' '
    $path = [regex]::Match($normalized, '(?i)--path\b')
    if (-not $path.Success) {
        return $false
    }

    $beforePath = $normalized.Substring(0, $path.Index)
    $log = [regex]::Match($beforePath, '(?i)--log-file\s+(?<value>\$[A-Za-z_][A-Za-z0-9_]*)\s*$')
    if (-not $log.Success) {
        return $false
    }

    $variable = $log.Groups['value'].Value.Substring(1)
    $definition = [regex]::Match(
        $ScriptText,
        "(?im)^\s*\$" + [regex]::Escape($variable) + "\s*=\s*(?<value>.+?)\s*$"
    )
    $proj = [regex]::Match($ScriptText, '(?im)^\s*\$proj\s*=')
    if (-not $definition.Success -or -not $proj.Success -or $definition.Index -le $proj.Index) {
        return $false
    }

    $logValue = $definition.Groups['value'].Value
    if ($logValue -notmatch '(?i)\$proj\b' -or
        $logValue -match '(?i)user://|%TEMP%|\$env:TEMP' -or
        $logValue -notmatch '(?i)\.log(?:["'')\s]|$)') {
        return $false
    }

    foreach ($line in ($GitIgnoreText -split '\r?\n')) {
        $rule = $line.Trim()
        if ($rule -match '^(?<directory>[A-Za-z0-9_.-]+)[\\/]$' -and
            $logValue -match '(?i)\$proj\b.*(?:["'']|[\\/])' + [regex]::Escape($Matches['directory']) + '[\\/]') {
            return $true
        }
    }

    return $false
}

$invocations = @(Get-GodotInvocationBlocks $runGateText)
$importInvocation = $invocations | Where-Object { $_ -match '(?i)--import\b' }
$gutInvocation = $invocations | Where-Object { $_ -match '(?i)gut_cmdln\.gd' }

Describe 'Pipe Mania Godot logging crash regression' {
    It 'disables Godot file logging in the debug section' {
        $debug = [regex]::Match($projectText, '(?ms)^\[debug\]\s*(?<body>.*?)(?=^\[[^\]]+\]|\z)')
        $debug.Success | Should Be $true
        $debug.Groups['body'].Value | Should Match '(?m)^\s*file_logging/enable_file_logging\.pc\s*=\s*false\s*$'
    }

    It 'adds a project-local log file before --path on the cold-import invocation' {
        $importInvocation | Should Not Be $null
        (Test-ExplicitProjectLogBeforePath $importInvocation $runGateText $gitignoreText) | Should Be $true
        $importInvocation | Should Match '(?i)--headless\b.*--import\b'
    }

    It 'adds a project-local log file before --path on the GUT invocation' {
        $gutInvocation | Should Not Be $null
        (Test-ExplicitProjectLogBeforePath $gutInvocation $runGateText $gitignoreText) | Should Be $true
        $gutInvocation | Should Match '(?i)--headless\b.*-s\s+res://addons/gut/gut_cmdln\.gd\s+-gdir=res://test\s+-ginclude_subdirs\s+-gexit'
    }

    It 'requires the log-file contract on every Godot invocation' {
        $invalid = @($invocations | Where-Object {
            -not (Test-ExplicitProjectLogBeforePath $_ $runGateText $gitignoreText)
        })
        $invalid.Count | Should Be 0
    }

    It 'preserves console binary discovery' {
        $runGateText | Should Match '(?ms)\$candidates\s*=\s*@\(.*?Godot_v4\.6\.2-stable_win64_console\.exe.*?\)\s*\$godot\s*=\s*\$candidates\s*\|'
    }

    It 'keeps import limited to a missing .godot cache' {
        $runGateText | Should Match '(?ms)if\s*\(-not\s*\(Test-Path\s*\(Join-Path\s+\$proj\s+["'']\.godot["'']\)\)\)\s*\{.*?--import\b'
    }

    It 'rejects a malformed invocation with no log flag' {
        (Test-ExplicitProjectLogBeforePath '& $godot --headless --path $proj --quit-after 5' $runGateText $gitignoreText) | Should Be $false
    }

    It 'rejects a malformed invocation with the log flag after --path' {
        (Test-ExplicitProjectLogBeforePath '& $godot --headless --path $proj --log-file $lateLog' @'
$proj = Split-Path -Parent $PSScriptRoot
$lateLog = Join-Path $proj ".tmp\godot-logging\late.log"
'@ $gitignoreText) | Should Be $false
    }

    It 'rejects log variables outside the project ignored directory' {
        $invalidPaths = @(
            @('& $godot --log-file $userLog --path $proj', '$userLog = "user://godot.log"'),
            @('& $godot --log-file $percentTempLog --path $proj', '$percentTempLog = "%TEMP%\\godot.log"'),
            @('& $godot --log-file $envTempLog --path $proj', '$envTempLog = Join-Path $env:TEMP "godot.log"'),
            @('& $godot --log-file $absoluteLog --path $proj', '$absoluteLog = "C:\\outside\\godot.log"')
        )

        foreach ($case in $invalidPaths) {
            (Test-ExplicitProjectLogBeforePath $case[0] ("`$proj = Split-Path -Parent `$PSScriptRoot`n" + $case[1]) $gitignoreText) | Should Be $false
        }
    }

    It 'accepts a log variable defined under the project in an ignored directory' {
        $script = @'
$proj = Split-Path -Parent $PSScriptRoot
$importLog = Join-Path $proj ".tmp\godot-import.log"
'@

        (Test-ExplicitProjectLogBeforePath '& $godot --log-file $importLog --path $proj' $script $gitignoreText) | Should Be $true
    }
}
