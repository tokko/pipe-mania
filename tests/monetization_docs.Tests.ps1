$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$documentPaths = @(
    'docs/MONETIZATION_SETUP.md'
    'docs/HANDOFF.md'
    'docs/store-listing.md'
)
$documents = @{}
foreach ($relativePath in $documentPaths) {
    $documents[$relativePath] = Get-Content -LiteralPath (Join-Path $repoRoot $relativePath) -Raw
}

function Get-ActiveLines {
    param(
        [string]$Content,
        [string]$RequiredPattern
    )

    return @(
        $Content -split '\r?\n' |
            Where-Object {
                $_ -match $RequiredPattern -and
                    $_ -notmatch '(?i)defer|out of scope|separate plan|not implemented|not available'
            }
    )
}

Describe 'Monetization documentation contract' {
    It 'reads exactly the three governed documentation files' {
        @($documents.Keys | Sort-Object) | Should Be @($documentPaths | Sort-Object)
    }

    It 'does not instruct installing or wiring GodotGooglePlayBilling' {
        foreach ($relativePath in $documentPaths) {
            $documents[$relativePath] | Should Not Match '(?i)GodotGooglePlayBilling'
        }
    }

    It 'does not offer remove_ads or direct purchase_remove_ads wiring' {
        foreach ($relativePath in $documentPaths) {
            $activeRemoveAds = Get-ActiveLines $documents[$relativePath] '(?i)remove[-_ ]ads|purchase[-_ ]remove[-_ ]ads'
            @($activeRemoveAds).Count | Should Be 0
        }
    }

    It 'does not instruct implementing an online leaderboard in the ads scope' {
        foreach ($relativePath in $documentPaths) {
            $activeLeaderboard = Get-ActiveLines $documents[$relativePath] '(?i)online[- ]leaderboard|online backend|LeaderboardServiceReal|signal-based async wrapper'
            @($activeLeaderboard).Count | Should Be 0
        }
    }

    It 'documents the installed AdMob integration and Android Test workflow' {
        $content = $documents['docs/MONETIZATION_SETUP.md']
        $content | Should Match '(?i)Poing(?: Studios)?\s+AdMob(?: plugin)?\s+v?4\.3\.1'
        $content | Should Match '(?is)android-preflight\.ps1.{0,80}(?:-Target\s+Test|Android Test)'
        $content | Should Match '(?is)export-ads-build\.ps1.{0,80}(?:-Target\s+Test|Android Test)'
    }

    It 'documents TEST demo IDs and connected-device UMP debug registration' {
        $content = $documents['docs/MONETIZATION_SETUP.md']
        $content | Should Match 'ca-app-pub-3940256099942544~3347511713'
        $content | Should Match 'ca-app-pub-3940256099942544/5224354917'
        $content | Should Match 'ca-app-pub-3940256099942544/1033173712'
        $content | Should Match '(?i)connected[- ]device'
        $content | Should Match '(?i)UMP'
        $content | Should Match '(?i)debug'
    }

    It 'documents blank account-gated production IDs and fail-closed LIVE behavior' {
        $content = $documents['docs/MONETIZATION_SETUP.md']
        $content | Should Match '(?is)production.{0,120}(?:ID|identifier)s?.{0,80}(?:blank|empty)'
        $content | Should Match '(?i)account-gated'
        $content | Should Match '(?is)LIVE.{0,240}fail[s]? closed'
        $content | Should Match '(?is)(?:complete.{0,120}non-demo|non-demo.{0,120}complete)'
    }

    It 'describes HANDOFF scope as rewarded revive plus between-run interstitials' {
        $content = $documents['docs/HANDOFF.md']
        $content | Should Match '(?i)rewarded\s+revive'
        $content | Should Match '(?i)between[- ]run(?:s)?\s+interstitials?'
        $activeScope = Get-ActiveLines $content '(?i)current|scope|monetization|rewarded|interstitial'
        @($activeScope | Where-Object { $_ -match '(?i)billing|cosmetic' }).Count | Should Be 0
    }

    It 'describes store-listing scope as rewarded revive plus between-run interstitials' {
        $content = $documents['docs/store-listing.md']
        $content | Should Match '(?i)rewarded\s+revive'
        $content | Should Match '(?i)between[- ]run(?:s)?\s+interstitials?'
        $activeScope = Get-ActiveLines $content '(?i)current|scope|monetization|rewarded|interstitial'
        @($activeScope | Where-Object { $_ -match '(?i)billing|cosmetic' }).Count | Should Be 0
    }
}
