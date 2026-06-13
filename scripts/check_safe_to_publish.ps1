param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

Push-Location $Root
try {
    $failures = New-Object System.Collections.Generic.List[string]

    if (Test-Path '.git') {
        $tracked = git ls-files
        $blockedPathPatterns = @(
            '^\.env$',
            '^\.env\.',
            '^data/',
            '^tools/',
            '^installers/',
            '^models/',
            '(^|/)(id_rsa|.*\.pem|.*\.key|.*\.p12|.*\.pfx)$',
            '(^|/)(secrets|credentials|token)\.'
        )

        foreach ($file in $tracked) {
            $normalized = $file -replace '\\', '/'
            if ($normalized -eq '.env.example' -or $normalized -eq 'data/.gitkeep') {
                continue
            }
            foreach ($pattern in $blockedPathPatterns) {
                if ($normalized -match $pattern) {
                    $failures.Add("Blocked tracked path: $file")
                }
            }
        }
    }

    $scanFiles = Get-ChildItem -File -Recurse -Force |
        Where-Object {
            $_.FullName -notmatch '\\\.git\\' -and
            $_.FullName -notmatch '\\\.dagu\\' -and
            $_.FullName -notmatch '\\data\\' -and
            $_.FullName -notmatch '\\tools\\' -and
            $_.FullName -notmatch '\\installers\\' -and
            $_.FullName -notmatch '\\models\\'
        }

    $secretPatterns = @(
        'sk-[A-Za-z0-9_-]{20,}',
        'ghp_[A-Za-z0-9_]{20,}',
        'gho_[A-Za-z0-9_]{20,}',
        'github_pat_[A-Za-z0-9_]{20,}',
        'AKIA[0-9A-Z]{16}'
    )

    foreach ($file in $scanFiles) {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($null -eq $content) {
            continue
        }
        foreach ($pattern in $secretPatterns) {
            if ($content -match $pattern) {
                $relative = Resolve-Path -LiteralPath $file.FullName -Relative
                $failures.Add("Possible secret pattern in: $relative")
            }
        }
    }

    if ($failures.Count -gt 0) {
        $failures | ForEach-Object { Write-Error $_ }
        throw "Safe-to-publish check failed."
    }

    Write-Host "Safe-to-publish check passed."
}
finally {
    Pop-Location
}
