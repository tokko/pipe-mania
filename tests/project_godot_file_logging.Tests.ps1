$ErrorActionPreference = 'Stop'

Describe 'project.godot Godot file logging' {
    It 'disables PC file logging in its single debug section' {
        $projectPath = Join-Path $PSScriptRoot '..\project.godot'
        $content = Get-Content -LiteralPath $projectPath -Raw
        $sectionPattern = '(?m)^[ \t]*\[[^\]\r\n]+\][ \t]*\r?$'
        $debugPattern = '(?m)^[ \t]*\[debug\][ \t]*\r?$'
        $debugSections = [regex]::Matches($content, $debugPattern)

        $debugSections.Count | Should Be 1

        $debugSection = $debugSections[0]
        $afterDebug = $content.Substring($debugSection.Index + $debugSection.Length)
        $nextSection = [regex]::Match($afterDebug, $sectionPattern)
        $debugBody = if ($nextSection.Success) {
            $afterDebug.Substring(0, $nextSection.Index)
        } else {
            $afterDebug
        }

        $assignmentPattern = '^[ \t]*file_logging/enable_file_logging\.pc[ \t]*=[ \t]*([^\s;#]+)[ \t]*(?:[;#].*)?$'
        $activeAssignments = @(
            $debugBody -split '\r?\n' |
                Where-Object { $_ -match $assignmentPattern }
        )

        $activeAssignments.Count | Should Be 1
        ([regex]::Match($activeAssignments[0], $assignmentPattern).Groups[1].Value) | Should Be 'false'
    }
}
