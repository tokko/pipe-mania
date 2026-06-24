# Android export toolchain preflight for the Aqueduct APK build.
# Reports each prerequisite + an overall verdict with remediation. The APK export only runs when
# this is GREEN; otherwise crunch parks the build (the prerequisites need a human to install/config).
#   PREFLIGHT: GREEN  -> exit 0   ·   PREFLIGHT: BLOCKED -> exit 2

$missing = @()
function Check($name, $ok, $remedy) {
	if ($ok) { Write-Output "  [OK]      $name" }
	else { Write-Output "  [MISSING] $name`n              fix: $remedy"; $script:missing += $name }
}

Write-Output "== Android export preflight (Aqueduct) =="

# 1. Godot Android export templates (the hard blocker for a headless export)
$tpl = "$env:APPDATA\Godot\export_templates"
$hasTpl = (Test-Path $tpl) -and ((Get-ChildItem $tpl -Directory -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)
Check "Godot Android export templates" $hasTpl "Godot Editor > Manage Export Templates > Download (4.6.2-stable)"

# 2. Android SDK
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { "$env:LOCALAPPDATA\Android\Sdk" }
$hasSdk = Test-Path $sdk
Check "Android SDK ($sdk)" $hasSdk "Install via Android Studio / cmdline-tools; set ANDROID_HOME"

# 3. Godot editor Android SDK + JDK paths configured (SDK on disk != Godot can use it)
$es = Get-ChildItem "$env:APPDATA\Godot" -Filter "editor_settings-*.tres" -ErrorAction SilentlyContinue | Select-Object -First 1
$hasEditorPaths = $false
if ($es) {
	$txt = Get-Content $es.FullName -Raw
	$hasEditorPaths = ($txt -match "android_sdk_path") -and ($txt -match "java_sdk_path")
}
Check "Godot editor android_sdk_path + java_sdk_path" $hasEditorPaths "Editor Settings > Export > Android: set Android SDK Path + Java SDK Path"

# 4. NDK — ONLY required for gradle custom builds; the prebuilt-template export (use_gradle_build=false) does not need it
$presets = Get-Content "$PSScriptRoot\..\export_presets.cfg" -Raw -ErrorAction SilentlyContinue
$gradle = $presets -match "gradle_build/use_gradle_build=true"
if ($gradle) {
	$hasNdk = ($env:ANDROID_NDK_HOME -and (Test-Path $env:ANDROID_NDK_HOME)) -or ($hasSdk -and (Test-Path "$sdk\ndk"))
	Check "Android NDK (gradle build)" $hasNdk "sdkmanager 'ndk;<version>' (installs under <SDK>\ndk) or set ANDROID_NDK_HOME"
} else {
	Write-Output "  [n/a]     Android NDK - not needed (use_gradle_build=false, prebuilt template)"
}

# 5. JDK keytool on PATH
$hasKeytool = $null -ne (Get-Command keytool -ErrorAction SilentlyContinue)
Check "JDK keytool (on PATH)" $hasKeytool "Install a JDK (17+) and add its bin\ to PATH"

# 6. Debug keystore (Godot uses the editor-configured one; ~/.android/debug.keystore is the common default)
$ks = "$env:USERPROFILE\.android\debug.keystore"
Check "Debug keystore ($ks)" (Test-Path $ks) "keytool -genkey -v -keystore `"$ks`" -storepass android -alias androiddebugkey -keypass android -dname CN=Android,O=Android,C=US -keyalg RSA -validity 10000"

# 7. ETC2/ASTC VRAM import (Godot fails the Android export — silently, in headless — without this)
$pg = Get-Content "$PSScriptRoot\..\project.godot" -Raw -ErrorAction SilentlyContinue
$etc2 = $pg -match "textures/vram_compression/import_etc2_astc=true"
Check "project.godot import_etc2_astc=true" $etc2 "Project Settings > Rendering > Textures > VRAM Compression > Import ETC2 ASTC = On (or add the line under [rendering])"

Write-Output ""
if ($missing.Count -eq 0) {
	Write-Output "PREFLIGHT: GREEN -> godot --headless --export-debug Android build/aqueduct.apk"
	exit 0
}
Write-Output "PREFLIGHT: BLOCKED ($($missing.Count) missing) -> resolve the [MISSING] items above, then re-run."
exit 2
