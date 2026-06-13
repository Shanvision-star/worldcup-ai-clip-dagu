# WorldCup AI Clip Dagu

授权素材的 AI 二创切片流水线。项目目标是整合成熟工具，而不是自研下载器、转码器、转录器或工作流平台。

## Mainline

当前主线是 MVP 0.1：

1. 从明确授权或可复用来源导入单条视频。
2. 使用 `yt-dlp` 下载视频、字幕或音频。
3. 使用 `FFmpeg` 抽音频、转码、生成横版和竖版素材。
4. 使用 ASR 工具生成字幕草稿。
5. 生成剪辑计划和质检报告。
6. 在 Dagu Web UI 查看每一步状态。
7. 人工审核后再上传平台。

本项目不把“纯搬运世界杯内容”作为产品边界。世界杯赛事、官方转播、集锦、BGM 和封面通常有高版权风险，默认只处理授权素材、公共领域、CC 授权素材、自有素材或已获得转载许可的内容。

## Authority Order

1. `README.md`
2. `docs/CONTENT_POLICY.md`
3. `workflows/worldcup_clip.yaml`
4. `config/*.yaml`
5. `scripts/*`

如果执行计划和代码现实冲突，先核代码与配置，再决定是代码缺口、文档缺口、验证缺口还是产品边界问题。

## Local Install

在 PowerShell 中运行：

```powershell
cd D:\Shanvisorin_platform\worldcup
.\scripts\bootstrap.ps1
```

脚本会把便携工具下载到本项目目录：

- `tools\yt-dlp\yt-dlp.exe`
- `tools\ffmpeg\bin\ffmpeg.exe`
- `tools\dagu\dagu.exe`

安装包缓存放在 `installers\`。这些目录都被 `.gitignore` 排除，不会上传到公开仓库。

## Run Dagu

```powershell
cd D:\Shanvisorin_platform\worldcup
.\scripts\start_dagu.ps1
```

默认地址是 `http://127.0.0.1:8088`。脚本会把 Dagu UI 指向 `workflows/`，并把 Dagu runtime state 放在本项目 `.dagu/` 目录下。

也可以用 CLI 直接跑 smoke：

```powershell
.\tools\dagu\dagu.exe start .\workflows\worldcup_clip.yaml -- JOB_CONFIG=config/jobs/local_smoke.yaml
```

`local_smoke.yaml` 是本机测试任务，默认被 Git 忽略，不会上传。

## Job Config

复制示例任务：

```powershell
Copy-Item .\config\jobs\example_job.yaml .\config\jobs\local_job.yaml
```

修改 `local_job.yaml` 中的来源、授权状态和输出名称。真实账号、密钥、代理和内部素材路径放到 `.env`，不要提交。

`config/jobs/local_*.yaml` 和 `config/jobs/*.local.yaml` 默认被 Git 忽略，适合放真实任务配置。

## Security Rules

公开仓库前必须运行：

```powershell
.\scripts\check_safe_to_publish.ps1
```

检查目标：

- 不跟踪 `.env`、key、token、credential。
- 不跟踪 `data/` 产物、`tools/` 二进制、`installers/` 安装包、`models/` 模型。
- 不把真实 API key 写进 README、配置或脚本。

## Verification

最小验收不需要真实世界杯素材：

1. 使用授权样例或自有样例视频。
2. 跑通下载或本地导入。
3. 抽音频。
4. 生成字幕草稿。
5. 生成横版和竖版渲染产物。
6. 生成 `data\reports\*.html`。
7. Dagu 中每步状态可见。

真实平台发布、真实 LLM/ASR 调用和声音克隆都属于受控 smoke，不进入默认 CI。
