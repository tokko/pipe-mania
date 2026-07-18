param(
    [string]$ProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')),
    [string]$TemplateArchive = (Join-Path $env:APPDATA 'Godot\export_templates\4.6.2.stable\android_source.zip')
)

$ErrorActionPreference = 'Stop'
$templateVersion = '4.6.2.stable'
$templateSha256 = '397467F9000B8C1FEC016B0E1E98F28315FA1B67A664FE033A718E4980238089'
$projectPath = [IO.Path]::GetFullPath($ProjectRoot)
$androidRoot = Join-Path $projectPath 'android'
$buildPath = Join-Path $androidRoot 'build'
$versionPath = Join-Path $androidRoot '.build_version'
$requiredFiles = @(
    'build.gradle',
    'config.gradle',
    'settings.gradle',
    'gradlew',
    'gradlew.bat',
    'gradle\wrapper\gradle-wrapper.jar',
    'gradle\wrapper\gradle-wrapper.properties',
    '.gdignore'
)

function Test-TemplateFiles([string]$Root) {
    foreach ($relativePath in $requiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $relativePath) -PathType Leaf)) {
            return $false
        }
    }
    return $true
}

if (-not (Test-Path -LiteralPath $projectPath -PathType Container)) {
    throw "Project root does not exist: $projectPath"
}

$hasBuild = Test-Path -LiteralPath $buildPath
$hasVersion = Test-Path -LiteralPath $versionPath
if ($hasBuild -or $hasVersion) {
    $validVersion = $hasVersion -and ((Get-Content -LiteralPath $versionPath -Raw).Trim() -eq $templateVersion)
    if ($hasBuild -and $validVersion -and (Test-TemplateFiles $buildPath)) {
        Write-Output "Android build template already provisioned: $buildPath ($templateVersion)"
        return
    }

    throw "Existing Android build template is invalid or not $templateVersion. Move or delete '$buildPath' and '$versionPath' manually, then rerun. This provisioner will not overwrite or delete them."
}

$archivePath = [IO.Path]::GetFullPath($TemplateArchive)
if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
    throw "Godot Android source template archive not found: $archivePath. Install the Godot $templateVersion export templates."
}
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $templateSha256) {
    throw "Godot Android source template SHA-256 mismatch for '$archivePath'. Expected $templateSha256; got $archiveHash."
}

$tmpRoot = Join-Path $projectPath '.tmp'
$stagingRoot = Join-Path $tmpRoot ("ads-android-build-{0}" -f [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
Expand-Archive -LiteralPath $archivePath -DestinationPath $stagingRoot
New-Item -ItemType File -Path (Join-Path $stagingRoot '.gdignore') | Out-Null
if (-not (Test-TemplateFiles $stagingRoot)) {
    throw "Godot Android source template archive is missing required Gradle files. Staging was left at '$stagingRoot'."
}

New-Item -ItemType Directory -Path $androidRoot -Force | Out-Null
Move-Item -LiteralPath $stagingRoot -Destination $buildPath
Set-Content -LiteralPath $versionPath -Value $templateVersion -NoNewline
if (-not (Test-TemplateFiles $buildPath) -or ((Get-Content -LiteralPath $versionPath -Raw).Trim() -ne $templateVersion)) {
    throw "Provisioned Android build template failed verification at '$buildPath'."
}

Write-Output "Provisioned Android build template: $buildPath ($templateVersion, SHA-256 $archiveHash)"
