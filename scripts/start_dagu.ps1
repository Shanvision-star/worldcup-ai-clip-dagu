param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$HostName = '127.0.0.1',
    [int]$Port = 8088,
    [switch]$KeepAuth
)

$ErrorActionPreference = 'Stop'

$dagu = Join-Path $Root 'tools\dagu\dagu.exe'
if (-not (Test-Path $dagu)) {
    throw 'dagu.exe not found. Run scripts/bootstrap.ps1 first.'
}

$workflows = Join-Path $Root 'workflows'
$daguHome = Join-Path $Root '.dagu'
New-Item -ItemType Directory -Force -Path $daguHome | Out-Null

# 覆盖机器上的全局 Dagu 环境变量，避免 UI 误读其他项目的 DAG 目录。
$env:DAGU_HOME = $daguHome
$env:DAGU_DAGS_DIR = $workflows

$configPath = Join-Path $daguHome 'local-config.yaml'
$authMode = if ($KeepAuth) { 'builtin' } else { 'none' }
$normalizedWorkflows = $workflows -replace '\\', '/'
$normalizedDaguHome = $daguHome -replace '\\', '/'
$normalizedDagu = $dagu -replace '\\', '/'

@"
host: "$HostName"
port: $Port
auth:
  mode: "$authMode"
coordinator:
  enabled: false
paths:
  dags_dir: "$normalizedWorkflows"
  data_dir: "$normalizedDaguHome/data"
  log_dir: "$normalizedDaguHome/logs"
  dag_runs_dir: "$normalizedDaguHome/data/dag-runs"
  queue_dir: "$normalizedDaguHome/data/queue"
  proc_dir: "$normalizedDaguHome/data/proc"
  service_registry_dir: "$normalizedDaguHome/data/service-registry"
  suspend_flags_dir: "$normalizedDaguHome/suspend"
  admin_logs_dir: "$normalizedDaguHome/logs/admin"
  executable: "$normalizedDagu"
"@ | Set-Content -LiteralPath $configPath -Encoding UTF8

& $dagu start-all --config $configPath --dagu-home $daguHome
