param(
    [ValidateSet('Android', 'Test')]
    [string]$Target = 'Android'
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$missing = @()

function Check($name, $ok, $remedy) {
    if ($ok) {
        Write-Output "  [OK]      $name"
    } else {
        Write-Output "  [MISSING] $name`n              fix: $remedy"
        $script:missing += $name
    }
}

function Get-SectionBody([string]$Content, [string]$Name) {
    $header = [regex]::Match($Content, '(?m)^\[' + [regex]::Escape($Name) + '\][ \t]*\r?\n')
    if (-not $header.Success) { return $null }
    $body = $Content.Substring($header.Index + $header.Length)
    $next = [regex]::Match($body, '(?m)^\[[^\]\r\n]+\][ \t]*(?:\r?\n|$)')
    if ($next.Success) { return $body.Substring(0, $next.Index) }
    return $body
}

function Get-AssignmentValue([string]$Section, [string]$Key) {
    if ($null -eq $Section) { return $null }
    $match = [regex]::Match($Section, '(?m)^[ \t]*' + [regex]::Escape($Key) + '[ \t]*=[ \t]*([^\r\n;#]+)')
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value.Trim().Trim('"')
}

function Get-GdStringConstant([string]$Content, [string]$Name) {
    $match = [regex]::Match($Content, '(?m)^const\s+' + [regex]::Escape($Name) + '\s*:=\s*"([^"]*)"')
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value
}

Write-Output "== Android export preflight (Aqueduct: $Target) =="

$presets = Get-Content (Join-Path $repoRoot 'export_presets.cfg') -Raw -ErrorAction SilentlyContinue
$presetIndex = if ($Target -eq 'Test') { 1 } else { 0 }
$preset = Get-SectionBody $presets ("preset.{0}" -f $presetIndex)
$options = Get-SectionBody $presets ("preset.{0}.options" -f $presetIndex)

$templatePath = Join-Path $env:APPDATA 'Godot\export_templates\4.6.2.stable'
Check 'Godot 4.6.2 Android export templates' (Test-Path $templatePath) 'Godot Editor > Manage Export Templates > Download 4.6.2-stable'

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
Check "Android SDK ($sdk)" (Test-Path $sdk) 'Install via Android Studio / cmdline-tools; set ANDROID_HOME'

$editorSettings = Join-Path $env:APPDATA 'Godot\editor_settings-4.6.tres'
$editorText = if (Test-Path $editorSettings) { Get-Content $editorSettings -Raw } else { '' }
$sdkMatch = [regex]::Match($editorText, '(?m)^export/android/android_sdk_path\s*=\s*"([^"]+)"')
$javaMatch = [regex]::Match($editorText, '(?m)^export/android/java_sdk_path\s*=\s*"([^"]+)"')
$configuredSdk = if ($sdkMatch.Success) { $sdkMatch.Groups[1].Value } else { '' }
$configuredJava = if ($javaMatch.Success) { $javaMatch.Groups[1].Value } else { '' }
Check 'Godot editor Android SDK path' ($sdkMatch.Success -and (Test-Path $configuredSdk) -and ([IO.Path]::GetFullPath($configuredSdk) -eq [IO.Path]::GetFullPath($sdk))) 'Set the 4.6.2 editor Android SDK path to the installed SDK'
Check 'Godot editor JDK path' ($javaMatch.Success -and (Test-Path (Join-Path $configuredJava 'bin\java.exe'))) 'Set the 4.6.2 editor Java SDK path'

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
Check 'JDK keytool (on PATH)' ($null -ne $keytool) 'Install a JDK and add its bin directory to PATH'
$keystore = Join-Path $env:APPDATA 'Godot\keystores\debug.keystore'
Check "Debug keystore ($keystore)" (Test-Path $keystore) 'Create the Godot debug keystore in the configured keystores directory'

$projectText = Get-Content (Join-Path $repoRoot 'project.godot') -Raw -ErrorAction SilentlyContinue
Check 'project.godot import_etc2_astc=true' ($projectText -match 'textures/vram_compression/import_etc2_astc=true') 'Enable Rendering > Textures > VRAM Compression > Import ETC2 ASTC'

Check "Selected preset name ($Target)" ((Get-AssignmentValue $preset 'name') -eq $Target -or ($Target -eq 'Test' -and (Get-AssignmentValue $preset 'name') -eq 'Android Test')) 'Define the selected Android export preset'
Check 'Selected preset package com.tokko.aqueduct' ((Get-AssignmentValue $options 'package/unique_name') -eq 'com.tokko.aqueduct') 'Set package/unique_name to com.tokko.aqueduct'
Check 'Selected preset arm64 only' ((Get-AssignmentValue $options 'architectures/arm64-v8a') -eq 'true' -and (Get-AssignmentValue $options 'architectures/armeabi-v7a') -eq 'false' -and (Get-AssignmentValue $options 'architectures/x86') -eq 'false' -and (Get-AssignmentValue $options 'architectures/x86_64') -eq 'false') 'Enable arm64 and disable all other Android architectures'

if ($Target -eq 'Test') {
    # Test preset contract: gradle_build/use_gradle_build=true.
    $buildVersion = Join-Path $repoRoot 'android\.build_version'
    $buildGradle = Join-Path $repoRoot 'android\build\build.gradle'
    $gdignore = Join-Path $repoRoot 'android\build\.gdignore'
    Check 'Android build template version 4.6.2.stable' ((Test-Path $buildVersion) -and ((Get-Content $buildVersion -Raw).Trim() -eq '4.6.2.stable')) 'Use the Godot 4.6.2 Android build template'
    Check 'Android Gradle build template files' ((Test-Path $buildGradle) -and (Test-Path $gdignore)) 'Regenerate the Android Gradle build template'

    $pluginCfg = Join-Path $repoRoot 'addons\admob\plugin.cfg'
    $exporter = Join-Path $repoRoot 'addons\admob\internal\exporters\android\export_plugin.gd'
    $override = Join-Path $repoRoot 'config\admob_android_config_override_1337.gd'
    $vendorRoot = Join-Path $repoRoot 'addons\admob\android\bin'
    $manifestPath = Join-Path $vendorRoot 'SHA256SUMS'
    $requiredVendorFiles = @(
        'package.gd',
        'ads/poing_godot_admob_ads.gd',
        'ads/libs/poing-godot-admob-ads-debug.aar',
        'ads/libs/poing-godot-admob-ads-release.aar',
        'ads/libs/poing-godot-admob-core-debug.aar',
        'ads/libs/poing-godot-admob-core-release.aar'
    )
    $vendorHashesValid = Test-Path -LiteralPath $manifestPath -PathType Leaf
    $vendorHashes = @{}
    if ($vendorHashesValid) {
        foreach ($line in Get-Content -LiteralPath $manifestPath) {
            if (-not $line.Trim()) { continue }
            $match = [regex]::Match($line, '^([0-9a-f]{64})  (.+)$')
            if (-not $match.Success -or $vendorHashes.ContainsKey($match.Groups[2].Value)) {
                $vendorHashesValid = $false
                break
            }
            $vendorHashes[$match.Groups[2].Value] = $match.Groups[1].Value
        }
    }
    $vendorFiles = if (Test-Path -LiteralPath $vendorRoot -PathType Container) {
        @(Get-ChildItem -LiteralPath $vendorRoot -File -Recurse | Where-Object { $_.FullName -ne $manifestPath })
    } else {
        @()
    }
    if ($vendorHashes.Count -ne 20 -or $vendorFiles.Count -ne 20) {
        $vendorHashesValid = $false
    }
    foreach ($relativePath in $requiredVendorFiles) {
        if (-not $vendorHashes.ContainsKey($relativePath)) {
            $vendorHashesValid = $false
        }
    }
    foreach ($vendorFile in $vendorFiles) {
        $relativePath = $vendorFile.FullName.Substring($vendorRoot.Length + 1).Replace('\', '/')
        if (-not $vendorHashes.ContainsKey($relativePath) -or (Get-FileHash -LiteralPath $vendorFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -ne $vendorHashes[$relativePath]) {
            $vendorHashesValid = $false
        }
    }
    $pluginText = if (Test-Path $pluginCfg) { Get-Content $pluginCfg -Raw } else { '' }
    $exporterText = if (Test-Path $exporter) { Get-Content $exporter -Raw } else { '' }
    $overrideText = if (Test-Path $override) { Get-Content $override -Raw } else { '' }
    $enabled = $projectText -like '*res://addons/admob/plugin.cfg*'
    Check 'Poing AdMob plugin v4.3.1 enabled' ($enabled -and $pluginText -match 'version="v4\.3\.1"') 'Enable the Poing AdMob v4.3.1 plugin'
    Check 'Poing AdMob exporter and pinned Android bin SHA-256 hashes' ((Test-Path $exporter) -and $vendorHashesValid) 'Restore the v4.3.1 exporter/bin package and SHA256SUMS manifest'
    Check 'Poing project override hook' ($exporterText -match 'res://config/admob_android_config_override_1337\.gd' -and $exporterText -match 'load\(OVERRIDE_CONFIG_PATH\)') 'Restore the Poing project override hook'
    Check 'Typed project AdMob override' ((Test-Path $override) -and $overrideText -match 'extends\s+"res://addons/admob/android/config\.gd"' -and $overrideText -match 'res://scripts/monetization_config\.gd' -and $overrideText -match 'resolve_export_ads_selection' -and $overrideText -match 'EXPORT_SELECTOR_ENV') 'Restore config/admob_android_config_override_1337.gd using the shared monetization config'
    $testGradle = $options -match '(?m)^\s*gradle_build/use_gradle_build\s*=\s*true\s*$'
    Check 'Test preset Gradle and admob_test feature' ($testGradle -and (Get-AssignmentValue $preset 'custom_features') -eq 'admob_test') 'Set Test to Gradle true with exactly admob_test'

    $ndk = Join-Path $sdk 'ndk\28.1.13356709'
    Check 'Android NDK 28.1.13356709' ((Test-Path $ndk) -or ($env:ANDROID_NDK_HOME -and (Test-Path (Join-Path $env:ANDROID_NDK_HOME 'source.properties')) -and $env:ANDROID_NDK_HOME -match '28\.1\.13356709')) 'Install NDK 28.1.13356709'
    $javaVersion = ''
    if ($javaMatch.Success -and (Test-Path (Join-Path $configuredJava 'bin\java.exe'))) {
        $javaProcess = New-Object Diagnostics.Process
        $javaProcess.StartInfo.FileName = Join-Path $configuredJava 'bin\java.exe'
        $javaProcess.StartInfo.Arguments = '-version'
        $javaProcess.StartInfo.RedirectStandardError = $true
        $javaProcess.StartInfo.UseShellExecute = $false
        $javaProcess.StartInfo.CreateNoWindow = $true
        [void]$javaProcess.Start()
        $javaVersion = $javaProcess.StandardError.ReadToEnd()
        $javaProcess.WaitForExit()
    }
    Check 'Configured Java major 17' ($javaVersion -match 'version "17\.') 'Configure a Java 17 SDK in Godot editor settings'

    $monetization = Get-Content (Join-Path $repoRoot 'scripts\monetization_config.gd') -Raw -ErrorAction SilentlyContinue
    Check 'Production monetization IDs blank' ($monetization -match '(?m)^const ADMOB_APP_ID\s*:=\s*""' -and $monetization -match '(?m)^const AD_UNIT_REWARDED\s*:=\s*""' -and $monetization -match '(?m)^const AD_UNIT_INTERSTITIAL\s*:=\s*""') 'Keep production AdMob IDs blank'
    $runtimeAppId = Get-GdStringConstant $monetization 'ADMOB_TEST_APP_ID'
    $manifestAppId = if ($overrideText -match 'selection\.manifest_app_id' -and $monetization -match '"manifest_app_id":\s*ADMOB_TEST_APP_ID') { $runtimeAppId } else { $null }
    Check 'Test runtime/export App ID agreement' ($runtimeAppId -eq 'ca-app-pub-3940256099942544~3347511713' -and $manifestAppId -eq $runtimeAppId -and $monetization -match '"runtime_app_id":\s*ADMOB_TEST_APP_ID') 'Resolve Test runtime and manifest IDs from the exact Google demo App ID'

    $liveAgreement = $monetization -match '"runtime_app_id":\s*live_app_id' -and $monetization -match '"manifest_app_id":\s*live_app_id'
    $liveFailClosed = $monetization -match 'target\s*==\s*"Live"\s+and\s+_is_valid_live_triple' -and $monetization -match '_uses_google_demo_publisher'
    Check 'Future Live selection fails closed with one App ID' ($liveAgreement -and $liveFailClosed) 'Keep Live disabled unless one complete canonical non-demo triple supplies both runtime and manifest App IDs'
}

Write-Output ''
if ($missing.Count -eq 0) {
    Write-Output "PREFLIGHT: GREEN -> $Target"
    exit 0
}
Write-Output "PREFLIGHT: BLOCKED ($($missing.Count) missing) -> resolve the [MISSING] items above, then re-run."
exit 2
