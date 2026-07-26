$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceTemplateArchive = Join-Path $env:APPDATA 'Godot\export_templates\4.6.2.stable\android_source.zip'
$sourceTemplateReadable = $false
try {
    $sourceTemplateReadable = Test-Path -LiteralPath $sourceTemplateArchive -PathType Leaf
} catch {
    $sourceTemplateReadable = $false
}

function Get-SectionBody {
    param(
        [string]$Content,
        [string]$Name
    )

    $header = [regex]::Match($Content, '(?m)^\[' + [regex]::Escape($Name) + '\][ \t]*\r?\n')
    if (-not $header.Success) {
        return $null
    }

    $afterHeader = $Content.Substring($header.Index + $header.Length)
    $nextHeader = [regex]::Match($afterHeader, '(?m)^\[[^\]\r\n]+\][ \t]*(?:\r?\n|$)')
    if ($nextHeader.Success) {
        return $afterHeader.Substring(0, $nextHeader.Index)
    }
    return $afterHeader
}

function Get-AssignmentValue {
    param(
        [string]$Section,
        [string]$Key
    )

    $pattern = '(?m)^[ \t]*' + [regex]::Escape($Key) + '[ \t]*=[ \t]*([^\r\n;#]+)'
    $match = [regex]::Match($Section, $pattern)
    if (-not $match.Success) {
        return $null
    }

    return $match.Groups[1].Value.Trim().Trim('"')
}

function Get-Preset {
    param(
        [string]$Content,
        [int]$Index
    )

    return [pscustomobject]@{
        Main = Get-SectionBody $Content ("preset.{0}" -f $Index)
        Options = Get-SectionBody $Content ("preset.{0}.options" -f $Index)
    }
}

function Get-QuotedValues {
    param([string]$Content)

    return @(
        [regex]::Matches($Content, '"([^"]*)"') |
            ForEach-Object { $_.Groups[1].Value }
    )
}

Describe 'Android AdMob export structure' {
    It 'preserves the existing Android preset 0 byte prefix and export contract' {
        $path = Join-Path $repoRoot 'export_presets.cfg'
        $bytes = [IO.File]::ReadAllBytes($path)

        # Captured from the current file before preset 1 production edits. Hash raw bytes, including LF bytes.
        $preset0PrefixByteLength = 7418
        $preset0PrefixSha256 = 'b6dc075deadc6126d26a5d3ee3be02ebc146c7f2891591489a43ad242b14d16b'
        ($bytes.Length -ge $preset0PrefixByteLength) | Should Be $true

        $prefix = New-Object byte[] $preset0PrefixByteLength
        [Array]::Copy($bytes, 0, $prefix, 0, $preset0PrefixByteLength)
        $hash = [Security.Cryptography.SHA256]::Create().ComputeHash($prefix)
        ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant() | Should Be $preset0PrefixSha256

        if ($bytes.Length -gt $preset0PrefixByteLength) {
            $suffix = [Text.Encoding]::UTF8.GetString($bytes, $preset0PrefixByteLength, $bytes.Length - $preset0PrefixByteLength)
            $suffix | Should Match '^\[preset\.1\]'
        }

        $content = [Text.Encoding]::UTF8.GetString($bytes)
        $preset = Get-Preset $content 0
        (Get-AssignmentValue $preset.Main 'name') | Should Be 'Android'
        (Get-AssignmentValue $preset.Main 'platform') | Should Be 'Android'
        (Get-AssignmentValue $preset.Main 'runnable') | Should Be 'true'
        (Get-AssignmentValue $preset.Main 'custom_features') | Should Be ''
        (Get-AssignmentValue $preset.Main 'export_path') | Should Be 'build/aqueduct.apk'
        (Get-AssignmentValue $preset.Options 'gradle_build/use_gradle_build') | Should Be 'false'
        (Get-AssignmentValue $preset.Options 'architectures/armeabi-v7a') | Should Be 'false'
        (Get-AssignmentValue $preset.Options 'architectures/arm64-v8a') | Should Be 'true'
        (Get-AssignmentValue $preset.Options 'architectures/x86') | Should Be 'false'
        (Get-AssignmentValue $preset.Options 'architectures/x86_64') | Should Be 'false'
        (Get-AssignmentValue $preset.Options 'package/unique_name') | Should Be 'com.tokko.aqueduct'
        (Get-AssignmentValue $preset.Options 'gradle_build/export_format') | Should Be '0'
    }

    It 'defines Android Test as a non-runnable arm64 debug APK preset' {
        $content = Get-Content -LiteralPath (Join-Path $repoRoot 'export_presets.cfg') -Raw
        $preset = Get-Preset $content 1
        $preset | Should Not Be $null
        (Get-AssignmentValue $preset.Main 'name') | Should Be 'Android Test'
        (Get-AssignmentValue $preset.Main 'platform') | Should Be 'Android'
        (Get-AssignmentValue $preset.Main 'runnable') | Should Be 'false'
        (Get-AssignmentValue $preset.Main 'custom_features') | Should Be 'admob_test'
        (Get-AssignmentValue $preset.Main 'export_path') | Should Be 'C:/Temp/aqueduct-test.apk'
        (Get-AssignmentValue $preset.Options 'gradle_build/use_gradle_build') | Should Be 'true'
        (Get-AssignmentValue $preset.Options 'architectures/armeabi-v7a') | Should Be 'false'
        (Get-AssignmentValue $preset.Options 'architectures/arm64-v8a') | Should Be 'true'
        (Get-AssignmentValue $preset.Options 'architectures/x86') | Should Be 'false'
        (Get-AssignmentValue $preset.Options 'architectures/x86_64') | Should Be 'false'
        (Get-AssignmentValue $preset.Options 'package/unique_name') | Should Be 'com.tokko.aqueduct'
        (Get-AssignmentValue $preset.Options 'gradle_build/export_format') | Should Be '0'
    }

    It 'provides a typed project override backed by the shared monetization config' {
        $overridePath = Join-Path $repoRoot 'config/admob_android_config_override_1337.gd'
        (Test-Path -LiteralPath $overridePath -PathType Leaf) | Should Be $true
        if (-not (Test-Path -LiteralPath $overridePath -PathType Leaf)) { return }

        $content = Get-Content -LiteralPath $overridePath -Raw
        $content | Should Match 'extends\s+"res://addons/admob/android/config\.gd"'
        $content | Should Match 'res://scripts/monetization_config\.gd'
        $content | Should Match 'resolve_export_ads_selection'
        $content | Should Match 'EXPORT_SELECTOR_ENV'
        $content | Should Not Match 'ca-app-pub-\d+[~/]\d+'
    }

    It 'keeps the vendor override hook pointed at the project override' {
        $content = Get-Content -LiteralPath (Join-Path $repoRoot 'addons/admob/internal/exporters/android/export_plugin.gd') -Raw
        $content | Should Match 'res://config/admob_android_config_override_1337\.gd'
        $content | Should Match '(?is)FileAccess\.file_exists\(OVERRIDE_CONFIG_PATH\).{0,240}load\(OVERRIDE_CONFIG_PATH\)'
    }

    It 'keeps production monetization IDs blank and Google demo IDs exact' {
        $content = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/monetization_config.gd') -Raw
        $expected = @{
            ADMOB_APP_ID = ''
            AD_UNIT_REWARDED = ''
            AD_UNIT_INTERSTITIAL = ''
            ADMOB_TEST_APP_ID = 'ca-app-pub-3940256099942544~3347511713'
            AD_UNIT_REWARDED_TEST = 'ca-app-pub-3940256099942544/5224354917'
            AD_UNIT_INTERSTITIAL_TEST = 'ca-app-pub-3940256099942544/1033173712'
        }

        foreach ($name in $expected.Keys) {
            $match = [regex]::Match($content, '(?m)^const\s+' + [regex]::Escape($name) + '\s*:=\s*"([^"]*)"')
            $match.Success | Should Be $true
            $match.Groups[1].Value | Should Be $expected[$name]
        }
    }

    It 'enables only the Poing AdMob editor plugin and no billing plugin in project.godot' {
        $content = Get-Content -LiteralPath (Join-Path $repoRoot 'project.godot') -Raw
        $editorPlugins = Get-SectionBody $content 'editor_plugins'
        $editorPlugins | Should Match 'res://addons/admob/plugin\.cfg'
        $editorPlugins | Should Not Match '(?i)billing'
    }

    It 'pins Google Mobile Ads and UMP dependencies without Play Billing' {
        $path = Join-Path $repoRoot 'addons/admob/android/bin/ads/poing_godot_admob_ads.gd'
        $content = Get-Content -LiteralPath $path -Raw
        $dependencyBlock = [regex]::Match($content, '(?is)_dependency_library\s*:=\s*\[(?<body>.*?)\]').Groups['body'].Value
        $dependencies = Get-QuotedValues $dependencyBlock

        (@($dependencies) -contains 'com.google.android.gms:play-services-ads:24.9.0') | Should Be $true
        (@($dependencies) -contains 'com.google.android.ump:user-messaging-platform:3.2.0') | Should Be $true
        @($dependencies | Where-Object { $_ -match '(?i)billing|play-billing' }).Count | Should Be 0
    }

    It 'makes Android preflight target-aware and keeps test-only checks under Test' {
        $path = Join-Path $repoRoot 'tools/android-preflight.ps1'
        $content = Get-Content -LiteralPath $path -Raw

        $content | Should Match 'ValidateSet\s*\(\s*["'']Android["'']\s*,\s*["'']Test["'']\s*\)'
        $content | Should Match '(?i)\$Target'
        $content | Should Match '(?is)export_presets\.cfg'
        $content | Should Match '(?is)Android Test'
        $content | Should Match '(?is)if\s*\(\s*\$Target\s*-eq\s*["'']Test["'']\s*\)'

        $testChecks = @(
            'gradle_build/use_gradle_build\s*=\s*true',
            'admob_test',
            '4\.6\.2\.stable',
            'addons/admob/plugin\.cfg',
            '28\.1\.13356709',
            '(?i)JDK.{0,20}17|java.{0,20}17',
            'ca-app-pub-3940256099942544~3347511713',
            'ADMOB_APP_ID|AD_UNIT_REWARDED|AD_UNIT_INTERSTITIAL'
        )
        foreach ($pattern in $testChecks) {
            $content | Should Match $pattern
        }
    }

    It 'exports only the Android Test APK after matching preflight and artifact checks' {
        $path = Join-Path $repoRoot 'tools/export-ads-build.ps1'
        $exists = Test-Path -LiteralPath $path -PathType Leaf
        $exists | Should Be $true
        if (-not $exists) {
            return
        }

        $content = Get-Content -LiteralPath $path -Raw
        $content | Should Match 'ValidateSet\s*\(\s*["'']Test["'']\s*\)'
        $content | Should Match '(?is)Android Test'
        $content | Should Match 'C:\\Temp\\aqueduct-test\.apk'
        $content | Should Match '(?is)android-preflight\.ps1.*-Target\s+\$Target'
        $content | Should Match '(?is)\$Target\s*-ne\s*["'']Test["'']|ValidateSet\s*\(\s*["'']Test["'']\s*\)'
        $content | Should Not Match '(?im)^\s*Remove-Item[^\r\n]*\$\w*artifact'
        $content | Should Match '(?is)LastWriteTimeUtc.{0,1000}LastWriteTimeUtc'
        $content | Should Match '(?is)--headless.{0,240}--export-debug'
        $content | Should Match '(?is)(?:Length|\.Length).{0,40}-gt\s*0'
        $content | Should Match '(?is)Get-FileHash.{0,80}SHA256'
        $content | Should Match '(?i)SHA-256'
    }

    It 'scopes the Test selector to the Godot export and restores it in finally' {
        $content = Get-Content -LiteralPath (Join-Path $repoRoot 'tools/export-ads-build.ps1') -Raw
        $content | Should Match 'AQUEDUCT_ADS_EXPORT_TARGET'
        $content | Should Match '(?is)try\s*\{.{0,1200}AQUEDUCT_ADS_EXPORT_TARGET.{0,1200}&\s*\$godot.{0,1200}\}\s*finally\s*\{.{0,800}(?:Remove-Item\s+Env:AQUEDUCT_ADS_EXPORT_TARGET|\$env:AQUEDUCT_ADS_EXPORT_TARGET\s*=)'
        $content.IndexOf('android-preflight.ps1') | Should BeLessThan $content.IndexOf('try {')
    }

    It 'restores or removes the selector when the Godot export fails' {
        $fixtureRoot = Join-Path $TestDrive 'selector-fixture'
        $toolsRoot = Join-Path $fixtureRoot 'tools'
        $fakeBin = Join-Path $fixtureRoot 'bin'
        New-Item -ItemType Directory -Path $toolsRoot, $fakeBin -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repoRoot 'tools/export-ads-build.ps1') -Destination $toolsRoot
        Set-Content -LiteralPath (Join-Path $toolsRoot 'provision-ads-build.ps1') -Value 'exit 0'
        Set-Content -LiteralPath (Join-Path $toolsRoot 'android-preflight.ps1') -Value 'exit 0'
        Set-Content -LiteralPath (Join-Path $fakeBin 'godot.cmd') -Value '@exit /b 7'

        $oldPath = $env:PATH
        $env:PATH = $fakeBin + [IO.Path]::PathSeparator + $oldPath
        try {
            $env:AQUEDUCT_ADS_EXPORT_TARGET = 'sentinel'
            { & (Join-Path $toolsRoot 'export-ads-build.ps1') -Target Test } | Should Throw
            $env:AQUEDUCT_ADS_EXPORT_TARGET | Should Be 'sentinel'

            Remove-Item Env:AQUEDUCT_ADS_EXPORT_TARGET
            { & (Join-Path $toolsRoot 'export-ads-build.ps1') -Target Test } | Should Throw
            (Test-Path Env:AQUEDUCT_ADS_EXPORT_TARGET) | Should Be $false
        } finally {
            $env:PATH = $oldPath
            Remove-Item Env:AQUEDUCT_ADS_EXPORT_TARGET -ErrorAction SilentlyContinue
        }
    }

    It 'keeps the legacy preset feature-free and Gradle-free' {
        $content = Get-Content -LiteralPath (Join-Path $repoRoot 'export_presets.cfg') -Raw
        $preset = Get-Preset $content 0
        (Get-AssignmentValue $preset.Main 'custom_features') | Should Be ''
        (Get-AssignmentValue $preset.Options 'gradle_build/use_gradle_build') | Should Be 'false'
    }

    It 'checks override resolution and App ID agreement before the Godot export' {
        $preflight = Get-Content -LiteralPath (Join-Path $repoRoot 'tools/android-preflight.ps1') -Raw
        $wrapper = Get-Content -LiteralPath (Join-Path $repoRoot 'tools/export-ads-build.ps1') -Raw
        $preflight | Should Match 'config[\\/]admob_android_config_override_1337\.gd'
        $preflight | Should Match 'admob_android_config_override_1337'
        $preflight | Should Match 'resolve_export_ads_selection'
        $preflight | Should Match 'runtime_app_id'
        $preflight | Should Match 'manifest_app_id'
        $preflight | Should Match 'ca-app-pub-3940256099942544~3347511713'
        $wrapper.IndexOf('android-preflight.ps1') | Should BeLessThan $wrapper.IndexOf('& $godot')
    }

    It 'tracks the pinned AdMob Android package and ignores generated iOS assets' {
        $requiredAar = 'addons/admob/android/bin/ads/libs/poing-godot-admob-ads-debug.aar'
        & git -c "safe.directory=$repoRoot" check-ignore -- $requiredAar 2>$null
        $LASTEXITCODE | Should Be 1

        & git -c "safe.directory=$repoRoot" check-ignore -- 'ios/' 2>$null
        $LASTEXITCODE | Should Be 0

        & git -c "safe.directory=$repoRoot" check-ignore -- 'android/.build_version' 2>$null
        $LASTEXITCODE | Should Be 0
    }

    It 'pins and verifies every shipped AdMob Android bin file' {
        $manifestPath = Join-Path $repoRoot 'addons/admob/android/bin/SHA256SUMS'
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) | Should Be $true
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            return
        }

        $entries = @{}
        foreach ($line in Get-Content -LiteralPath $manifestPath) {
            if (-not $line.Trim()) { continue }
            $match = [regex]::Match($line, '^([0-9a-f]{64})  (.+)$')
            $match.Success | Should Be $true
            if ($match.Success) {
                $entries[$match.Groups[2].Value] = $match.Groups[1].Value
            }
        }

        $entries.Count | Should Be 20
        foreach ($required in @(
            'package.gd',
            'ads/poing_godot_admob_ads.gd',
            'ads/libs/poing-godot-admob-ads-debug.aar',
            'ads/libs/poing-godot-admob-ads-release.aar',
            'ads/libs/poing-godot-admob-core-debug.aar',
            'ads/libs/poing-godot-admob-core-release.aar'
        )) {
            $entries.ContainsKey($required) | Should Be $true
        }

        foreach ($relativePath in $entries.Keys) {
            $vendorPath = Join-Path (Join-Path $repoRoot 'addons/admob/android/bin') $relativePath
            (Test-Path -LiteralPath $vendorPath -PathType Leaf) | Should Be $true
            if (Test-Path -LiteralPath $vendorPath -PathType Leaf) {
                (Get-FileHash -LiteralPath $vendorPath -Algorithm SHA256).Hash.ToLowerInvariant() | Should Be $entries[$relativePath]
            }
        }

        $preflight = Get-Content -LiteralPath (Join-Path $repoRoot 'tools/android-preflight.ps1') -Raw
        $preflight | Should Match 'SHA256SUMS'
        $preflight | Should Match 'Get-FileHash'
        $preflight | Should Match 'poing-godot-admob-ads-debug\.aar'
        $preflight | Should Match 'poing-godot-admob-core-debug\.aar'
        $preflight | Should Match 'package\.gd'
        $preflight | Should Match 'poing_godot_admob_ads\.gd'
    }

    It 'keeps the commit-visible vendored AdMob package reproducible with android/.gitignore as the intentional packaging overlay' {
        $relativePaths = @(
            & git -C $repoRoot -c "safe.directory=$repoRoot" ls-files --cached --others --exclude-standard -- 'addons/admob' 2>$null |
                Sort-Object
        )
        $LASTEXITCODE | Should Be 0
        (@($relativePaths) -contains 'addons/admob/downloads/.gitkeep') | Should Be $true
        (@($relativePaths) -contains 'addons/admob/downloads/ios/poing-godot-admob-ios-v4.6.2.zip') | Should Be $false

        $lines = $relativePaths | ForEach-Object {
            $relativePath = $_.Substring('addons/admob/'.Length)
            $hash = (Get-FileHash -LiteralPath (Join-Path $repoRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant()
            "$hash  $relativePath"
        }
        $bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
        $aggregate = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)

        $lines.Count | Should Be 357
        (([BitConverter]::ToString($aggregate) -replace '-', '').ToLowerInvariant()) | Should Be '03b15290f4b55005abb4194d577d913589a2bd2dff0074a24faff1575713e02e'

        $exporterPath = Join-Path $repoRoot 'addons/admob/internal/exporters/android/export_plugin.gd'
        (Get-FileHash -LiteralPath $exporterPath -Algorithm SHA256).Hash | Should Be 'BE3D99E98DA72FBF204D880751993C34931B8BDB024DDA3AB6762A9FF6A9FCA6'
        (Get-Content -LiteralPath $exporterPath -Raw) | Should Match 'const OVERRIDE_CONFIG_PATH := "res://config/admob_android_config_override_1337\.gd"'

        $packagingOverlay = Get-Content -LiteralPath (Join-Path $repoRoot 'addons/admob/android/.gitignore') -Raw
        $packagingOverlay | Should Match 'pinned /bin package is committed for reproducible Android exports'
    }

    It 'provisions the pinned Godot Android source template safely and idempotently' -Skip:(-not $sourceTemplateReadable) {
        $scriptPath = Join-Path $repoRoot 'tools/provision-ads-build.ps1'
        (Test-Path -LiteralPath $scriptPath -PathType Leaf) | Should Be $true
        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            return
        }

        $content = Get-Content -LiteralPath $scriptPath -Raw
        $content | Should Match '4\.6\.2\.stable'
        $content | Should Match '397467F9000B8C1FEC016B0E1E98F28315FA1B67A664FE033A718E4980238089'
        $content | Should Match 'android_source\.zip'
        $content | Should Match '\[string\]\$ProjectRoot'
        $content | Should Match '\[string\]\$TemplateArchive'
        $content | Should Match '(?is)\.tmp.{0,240}Expand-Archive.{0,500}Move-Item'
        $content | Should Match '(?i)will not (?:overwrite|delete)'

        $archive = $sourceTemplateArchive
        (Test-Path -LiteralPath $archive -PathType Leaf) | Should Be $true
        if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
            return
        }

        $projectRoot = Join-Path $TestDrive 'fresh-project'
        New-Item -ItemType Directory -Path $projectRoot | Out-Null
        & $scriptPath -ProjectRoot $projectRoot -TemplateArchive $archive
        (Test-Path -LiteralPath (Join-Path $projectRoot 'android/build/build.gradle') -PathType Leaf) | Should Be $true
        (Get-Content -LiteralPath (Join-Path $projectRoot 'android/.build_version') -Raw).Trim() | Should Be '4.6.2.stable'

        & $scriptPath -ProjectRoot $projectRoot -TemplateArchive $archive
        (Get-Content -LiteralPath (Join-Path $projectRoot 'android/.build_version') -Raw).Trim() | Should Be '4.6.2.stable'
    }

    It 'refuses to overwrite an invalid existing Android build template' {
        $scriptPath = Join-Path $repoRoot 'tools/provision-ads-build.ps1'
        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            $false | Should Be $true
            return
        }

        $projectRoot = Join-Path $TestDrive 'invalid-project'
        $buildRoot = Join-Path $projectRoot 'android/build'
        New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $buildRoot 'sentinel.txt') -Value 'keep' -NoNewline
        $archive = Join-Path $env:APPDATA 'Godot\export_templates\4.6.2.stable\android_source.zip'

        { & $scriptPath -ProjectRoot $projectRoot -TemplateArchive $archive } | Should Throw 'Move or delete'
        (Get-Content -LiteralPath (Join-Path $buildRoot 'sentinel.txt') -Raw) | Should Be 'keep'
    }

    It 'provisions before Android Test preflight and export' {
        $content = Get-Content -LiteralPath (Join-Path $repoRoot 'tools/export-ads-build.ps1') -Raw
        $provisionIndex = $content.IndexOf('provision-ads-build.ps1')
        $preflightIndex = $content.IndexOf('android-preflight.ps1')
        $provisionIndex | Should BeGreaterThan -1
        $preflightIndex | Should BeGreaterThan $provisionIndex
    }
}
