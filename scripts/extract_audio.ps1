param(
    [string]$JobConfig = 'config/jobs/example_job.yaml',
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Read-SimpleYamlValue {
    param([string]$Path, [string]$Key)
    $line = Select-String -Path $Path -Pattern "^\s*$Key\s*:" | Select-Object -First 1
    if (-not $line) { return '' }
    return (($line.Line -replace "^\s*$Key\s*:\s*", '').Trim().Trim('"').Trim("'"))
}

Push-Location $Root
try {
    $configPath = Resolve-Path $JobConfig
    $slug = Read-SimpleYamlValue -Path $configPath -Key 'slug'
    if (-not $slug) { $slug = 'job-output' }

    $input = Get-ChildItem -LiteralPath (Join-Path $Root 'data\raw') -File |
        Where-Object { $_.BaseName -eq $slug -and $_.Extension -match '\.(mp4|mkv|mov|webm)$' } |
        Select-Object -First 1
    if (-not $input) { throw "No raw video found for slug '$slug'." }

    $audioDir = Join-Path $Root 'data\audio'
    New-Item -ItemType Directory -Force -Path $audioDir | Out-Null
    $out = Join-Path $audioDir "$slug.wav"
    $ffmpeg = Join-Path $Root 'tools\ffmpeg\bin\ffmpeg.exe'
    if (-not (Test-Path $ffmpeg)) { throw 'ffmpeg.exe not found. Run scripts/bootstrap.ps1 first.' }

    & $ffmpeg -y -i $input.FullName -vn -ac 1 -ar 16000 -c:a pcm_s16le $out
}
finally {
    Pop-Location
}

