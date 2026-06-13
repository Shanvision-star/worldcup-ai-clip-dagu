"""字幕转录入口：优先调用本地 ASR 命令，未配置时生成可审查的占位字幕。"""

from __future__ import annotations

import argparse
import os
import subprocess
from pathlib import Path


def read_slug(config_path: Path) -> str:
    for line in config_path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("slug:"):
            return stripped.split(":", 1)[1].strip().strip("\"'")
    return "job-output"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job-config", default="config/jobs/example_job.yaml")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    config_path = (root / args.job_config).resolve()
    slug = read_slug(config_path)
    audio_path = root / "data" / "audio" / f"{slug}.wav"
    out_dir = root / "data" / "transcripts"
    out_dir.mkdir(parents=True, exist_ok=True)
    srt_path = out_dir / f"{slug}.srt"

    if not audio_path.exists():
        raise FileNotFoundError(f"Audio not found: {audio_path}")

    command_template = os.environ.get("LOCAL_ASR_COMMAND", "").strip()
    if command_template:
        # 允许用户把 faster-whisper、whisperx 或自有 ASR CLI 接进来；密钥和模型路径留在环境变量。
        command = command_template.format(audio=str(audio_path), out_dir=str(out_dir), slug=slug)
        subprocess.run(command, shell=True, check=True)
        return 0

    srt_path.write_text(
        "1\n00:00:00,000 --> 00:00:02,000\n[ASR not configured] 请配置 LOCAL_ASR_COMMAND 后重新转录。\n",
        encoding="utf-8",
    )
    print(f"Wrote placeholder transcript: {srt_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

