param(
    [string]$JobConfig = 'config/jobs/example_job.yaml',
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Read-SimpleYamlValue {
    param(
        [string]$Path,
        [string]$Key
    )
    $line = Select-String -Path $Path -Pattern "^\s*$Key\s*:" | Select-Object -First 1
    if (-not $line) { return '' }
    return (($line.Line -replace "^\s*$Key\s*:\s*", '').Trim().Trim('"').Trim("'"))
}

Push-Location $Root
try {
    $configPath = Resolve-Path $JobConfig
    $slug = Read-SimpleYamlValue -Path $configPath -Key 'slug'
    if (-not $slug) { $slug = 'job-output' }

    $sourceType = Read-SimpleYamlValue -Path $configPath -Key 'type'
    $url = Read-SimpleYamlValue -Path $configPath -Key 'url'
    $localFile = Read-SimpleYamlValue -Path $configPath -Key 'local_file'
    $rightsStatus = Read-SimpleYamlValue -Path $configPath -Key 'status'

    if ($rightsStatus -ne 'verified') {
        throw "Rights status must be 'verified' before download/render. Current: '$rightsStatus'."
    }

    $rawDir = Join-Path $Root 'data\raw'
    New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
    $target = Join-Path $rawDir "$slug.%(ext)s"

    if ($sourceType -eq 'local') {
        if (-not $localFile) { throw 'local_file is required for local source jobs.' }
        $resolvedLocal = Resolve-Path $localFile
        Copy-Item -LiteralPath $resolvedLocal -Destination (Join-Path $rawDir "$slug.mp4") -Force
        Write-Host "Imported local source to data\raw\$slug.mp4"
        exit 0
    }

    if (-not $url) { throw 'url is required for non-local source jobs.' }
    $ytDlp = Join-Path $Root 'tools\yt-dlp\yt-dlp.exe'
    if (-not (Test-Path $ytDlp)) { throw 'yt-dlp.exe not found. Run scripts/bootstrap.ps1 first.' }

    $args = @(
        '--no-playlist',
        '--write-subs',
        '--write-auto-subs',
        '--sub-lang', 'en,zh.*',
        '--merge-output-format', 'mp4',
        '-o', $target,
        $url
    )

    if ($env:YTDLP_PROXY) {
        $args = @('--proxy', $env:YTDLP_PROXY) + $args
    }

    & $ytDlp @args
}
finally {
    Pop-Location
}

