"""质检报告生成：汇总产物路径、授权状态和人工审核清单。"""

from __future__ import annotations

import argparse
import html
from pathlib import Path


def read_simple_value(config_path: Path, key: str) -> str:
    for line in config_path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith(f"{key}:"):
            return stripped.split(":", 1)[1].strip().strip("\"'")
    return ""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job-config", default="config/jobs/example_job.yaml")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    config_path = (root / args.job_config).resolve()
    slug = read_simple_value(config_path, "slug") or "job-output"
    rights_status = read_simple_value(config_path, "status") or "unknown"

    report_dir = root / "data" / "reports"
    report_dir.mkdir(parents=True, exist_ok=True)
    report_path = report_dir / f"{slug}.html"
    renders = sorted((root / "data" / "renders").glob(f"{slug}-*.mp4"))

    render_items = "\n".join(f"<li>{html.escape(str(path))}</li>" for path in renders) or "<li>No renders found</li>"
    body = f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <title>QC Report - {html.escape(slug)}</title>
  <style>
    body {{ font-family: system-ui, sans-serif; margin: 32px; line-height: 1.5; }}
    code {{ background: #f3f4f6; padding: 2px 4px; }}
  </style>
</head>
<body>
  <h1>QC Report: {html.escape(slug)}</h1>
  <p><strong>Rights status:</strong> {html.escape(rights_status)}</p>
  <h2>Renders</h2>
  <ul>{render_items}</ul>
  <h2>Manual Review</h2>
  <ul>
    <li>授权和署名已确认。</li>
    <li>原视频不是未授权赛事转播或官方集锦。</li>
    <li>版权 BGM 已移除或替换。</li>
    <li>标题、封面、口播、字幕和叙事结构已二创。</li>
    <li>发布平台内容规则已复核。</li>
  </ul>
</body>
</html>
"""
    report_path.write_text(body, encoding="utf-8")
    print(f"Wrote QC report: {report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

