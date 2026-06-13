param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function New-ProjectDirectory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Invoke-Download {
    param(
        [string]$Url,
        [string]$OutFile,
        [Nullable[int64]]$ExpectedSize = $null
    )
    if ((Test-Path $OutFile) -and ($null -ne $ExpectedSize) -and ((Get-Item $OutFile).Length -eq $ExpectedSize)) {
        Write-Host "Using cached installer: $OutFile"
        return
    }
    if ((Test-Path $OutFile) -and ($null -eq $ExpectedSize)) {
        Write-Host "Using cached installer: $OutFile"
        return
    }

    Write-Host "Downloading $Url"
    for ($attempt = 1; $attempt -le 8; $attempt++) {
        $resumeArgs = @()
        if (Test-Path $OutFile) {
            $resumeArgs = @('-C', '-')
        }
        & curl.exe -L --fail --retry 5 --retry-delay 2 --connect-timeout 30 @resumeArgs -o $OutFile $Url
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Download attempt $attempt failed with exit code $LASTEXITCODE."
        }

        if ($null -eq $ExpectedSize) {
            if (Test-Path $OutFile) { return }
        }
        elseif ((Test-Path $OutFile) -and ((Get-Item $OutFile).Length -eq $ExpectedSize)) {
            return
        }

        $current = if (Test-Path $OutFile) { (Get-Item $OutFile).Length } else { 0 }
        Write-Warning "Downloaded size $current does not match expected size $ExpectedSize. Retrying..."
        Start-Sleep -Seconds 3
    }

    throw "Failed to download complete file: $Url"
}

function Get-LatestRelease {
    param([string]$Repo)
    Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ 'User-Agent' = 'worldcup-ai-clip-dagu' }
}

function Assert-UnderRoot {
    param([string]$Path)
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $targetFull = [System.IO.Path]::GetFullPath($Path)
    if (-not $targetFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside project root: $targetFull"
    }
}

$installerDir = Join-Path $Root 'installers'
$toolsDir = Join-Path $Root 'tools'
New-ProjectDirectory $installerDir
New-ProjectDirectory $toolsDir

$ytDlpDir = Join-Path $toolsDir 'yt-dlp'
New-ProjectDirectory $ytDlpDir
$ytDlpExe = Join-Path $ytDlpDir 'yt-dlp.exe'
if (-not (Test-Path $ytDlpExe)) {
    $ytRelease = Get-LatestRelease 'yt-dlp/yt-dlp'
    $asset = $ytRelease.assets | Where-Object { $_.name -eq 'yt-dlp.exe' } | Select-Object -First 1
    if (-not $asset) { throw 'Could not find yt-dlp.exe release asset.' }
    $ytInstaller = Join-Path $installerDir 'yt-dlp.exe'
    Invoke-Download -Url $asset.browser_download_url -OutFile $ytInstaller -ExpectedSize $asset.size
    Copy-Item -LiteralPath $ytInstaller -Destination $ytDlpExe -Force
}

$daguDir = Join-Path $toolsDir 'dagu'
New-ProjectDirectory $daguDir
$daguExe = Join-Path $daguDir 'dagu.exe'
if (-not (Test-Path $daguExe)) {
    $daguRelease = Get-LatestRelease 'dagu-org/dagu'
    $asset = $daguRelease.assets | Where-Object { $_.name -match 'windows_amd64\.tar\.gz$' } | Select-Object -First 1
    if (-not $asset) { throw 'Could not find Dagu windows_amd64 release asset.' }
    $daguArchive = Join-Path $installerDir $asset.name
    Invoke-Download -Url $asset.browser_download_url -OutFile $daguArchive -ExpectedSize $asset.size
    tar -xzf $daguArchive -C $daguDir
}

$ffmpegDir = Join-Path $toolsDir 'ffmpeg'
$ffmpegExe = Join-Path $ffmpegDir 'bin\ffmpeg.exe'
if (-not (Test-Path $ffmpegExe)) {
    $ffmpegRelease = Get-LatestRelease 'BtbN/FFmpeg-Builds'
    $asset = $ffmpegRelease.assets |
        Where-Object { $_.name -match 'ffmpeg-master-latest-win64-gpl\.zip$' } |
        Select-Object -First 1
    if (-not $asset) { throw 'Could not find FFmpeg win64 GPL release asset.' }
    $ffmpegArchive = Join-Path $installerDir $asset.name
    Invoke-Download -Url $asset.browser_download_url -OutFile $ffmpegArchive -ExpectedSize $asset.size
    $extractDir = Join-Path $installerDir 'ffmpeg-extract'
    if (Test-Path $extractDir) {
        Assert-UnderRoot $extractDir
        Remove-Item -LiteralPath $extractDir -Recurse -Force
    }
    Expand-Archive -LiteralPath $ffmpegArchive -DestinationPath $extractDir -Force
    $inner = Get-ChildItem -LiteralPath $extractDir -Directory | Select-Object -First 1
    if (-not $inner) { throw 'FFmpeg archive did not contain an expected directory.' }
    if (Test-Path $ffmpegDir) {
        Assert-UnderRoot $ffmpegDir
        Remove-Item -LiteralPath $ffmpegDir -Recurse -Force
    }
    Assert-UnderRoot $ffmpegDir
    Move-Item -LiteralPath $inner.FullName -Destination $ffmpegDir
}

Write-Host ''
Write-Host 'Installed tools:'
& $ytDlpExe --version
& $daguExe version
& $ffmpegExe -version | Select-Object -First 1

Write-Host ''
Write-Host "Add these to PATH for this shell if needed:"
Write-Host "`$env:PATH = '$ytDlpDir;$daguDir;$(Join-Path $ffmpegDir 'bin');' + `$env:PATH"
