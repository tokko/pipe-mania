param(
    [ValidateSet('Test')]
    [string]$Target = 'Test'
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$artifact = 'C:\Temp\aqueduct-test.apk'
$artifactRoot = [IO.Path]::GetFullPath('C:\Temp')
$resolvedArtifact = [IO.Path]::GetFullPath($artifact)
if (-not $resolvedArtifact.StartsWith($artifactRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing artifact outside C:\Temp: $resolvedArtifact"
}

& (Join-Path $PSScriptRoot 'provision-ads-build.ps1') -ProjectRoot $repoRoot
& (Join-Path $PSScriptRoot 'android-preflight.ps1') -Target $Target
if ($LASTEXITCODE -ne 0) { throw "Android $Target preflight failed with exit code $LASTEXITCODE." }

$godotCandidates = @(
    (Get-Command godot -ErrorAction SilentlyContinue).Source,
    (Get-Command godot4 -ErrorAction SilentlyContinue).Source,
    'C:\Program Files\Godot\godot.exe',
    'C:\Program Files\Godot\Godot.exe',
    'C:\Users\andre\Downloads\Godot_v4.6.2-stable_win64.exe\godot.cmd'
)
$godot = $godotCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $godot) { throw 'Godot 4.6.2 was not found in PATH or repository build candidates.' }

$beforeWriteTime = if (Test-Path -LiteralPath $artifact -PathType Leaf) {
    (Get-Item -LiteralPath $artifact).LastWriteTimeUtc
} else {
    $null
}

$selectorWasSet = Test-Path Env:AQUEDUCT_ADS_EXPORT_TARGET
$previousSelector = $env:AQUEDUCT_ADS_EXPORT_TARGET
try {
    $env:AQUEDUCT_ADS_EXPORT_TARGET = $Target
    Write-Output "Exporting Android Test to $artifact"
    & $godot --headless --path $repoRoot --export-debug 'Android Test' $artifact
    if ($LASTEXITCODE -ne 0) { throw "Godot Android Test export failed with exit code $LASTEXITCODE." }
} finally {
    if ($selectorWasSet) {
        $env:AQUEDUCT_ADS_EXPORT_TARGET = $previousSelector
    } else {
        Remove-Item Env:AQUEDUCT_ADS_EXPORT_TARGET -ErrorAction SilentlyContinue
    }
}
if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) { throw "Export did not create $artifact" }
$file = Get-Item -LiteralPath $artifact
if ($null -ne $beforeWriteTime -and $file.LastWriteTimeUtc -le $beforeWriteTime) { throw "Export did not refresh $artifact" }
if ($file.Length -gt 0) { } else { throw "Export created an empty APK: $artifact" }
$hash = Get-FileHash -LiteralPath $artifact -Algorithm SHA256
Write-Output "APK: $artifact"
Write-Output "Size: $($file.Length) bytes"
Write-Output "SHA-256: $($hash.Hash)"
