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

function Convert-ToFfmpegFilterPath {
    param([string]$Path, [string]$Root)
    $full = [System.IO.Path]::GetFullPath($Path)
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    if ($full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return ($full.Substring($rootFull.Length) -replace '\\', '/')
    }
    return (($full -replace '\\', '/') -replace ':', '\:')
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

    $renderDir = Join-Path $Root 'data\renders'
    New-Item -ItemType Directory -Force -Path $renderDir | Out-Null
    $ffmpeg = Join-Path $Root 'tools\ffmpeg\bin\ffmpeg.exe'
    if (-not (Test-Path $ffmpeg)) { throw 'ffmpeg.exe not found. Run scripts/bootstrap.ps1 first.' }
    $captionFile = Join-Path $Root "data\transcripts\$slug.ass"
    $captionFilter = ''
    if (Test-Path $captionFile) {
        $captionPath = Convert-ToFfmpegFilterPath -Path $captionFile -Root $Root
        $captionFilter = ",subtitles='$captionPath'"
        Write-Host "Burning styled captions from data\transcripts\$slug.ass"
    }

    $out16x9 = Join-Path $renderDir "$slug-16x9.mp4"
    & $ffmpeg -y -i $input.FullName -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2$captionFilter" -c:v libx264 -crf 20 -preset veryfast -c:a aac -b:a 160k $out16x9

    $out9x16 = Join-Path $renderDir "$slug-9x16.mp4"
    & $ffmpeg -y -i $input.FullName -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920$captionFilter" -c:v libx264 -crf 22 -preset veryfast -c:a aac -b:a 160k $out9x16
}
finally {
    Pop-Location
}
