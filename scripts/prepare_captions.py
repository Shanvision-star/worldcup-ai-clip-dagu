"""字幕准备入口：根据任务配置生成双语 ASS 字幕文件。"""

from __future__ import annotations

import argparse
from pathlib import Path

from caption_utils import build_ass_document, merge_bilingual_cues, parse_srt, parse_vtt


def read_simple_value(config_path: Path, key: str) -> str:
    for line in config_path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith(f"{key}:"):
            return stripped.split(":", 1)[1].strip().strip("\"'")
    return ""


def read_int(config_path: Path, key: str, default: int) -> int:
    raw = read_simple_value(config_path, key)
    if not raw:
        return default
    return int(raw)


def read_float(config_path: Path, key: str, default: float) -> float:
    raw = read_simple_value(config_path, key)
    if not raw:
        return default
    return float(raw)


def load_cues(path: Path):
    content = path.read_text(encoding="utf-8")
    if path.suffix.lower() == ".vtt":
        return parse_vtt(content)
    return parse_srt(content)


def first_existing(paths: list[Path]) -> Path | None:
    for path in paths:
        if path.exists():
            return path
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job-config", default="config/jobs/example_job.yaml")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    config_path = (root / args.job_config).resolve()
    slug = read_simple_value(config_path, "slug") or "job-output"
    transcripts_dir = root / "data" / "transcripts"
    srt_path = transcripts_dir / f"{slug}.srt"
    ass_path = transcripts_dir / f"{slug}.ass"

    english_path = first_existing(
        [
            transcripts_dir / f"{slug}.en.srt",
            transcripts_dir / f"{slug}.en.vtt",
        ]
    )
    chinese_path = first_existing(
        [
            transcripts_dir / f"{slug}.zh-Hans.srt",
            transcripts_dir / f"{slug}.zh-Hans.vtt",
            transcripts_dir / f"{slug}.zh.srt",
            transcripts_dir / f"{slug}.zh.vtt",
        ]
    )

    if english_path:
        cues = load_cues(english_path)
        if chinese_path:
            cues = merge_bilingual_cues(cues, load_cues(chinese_path))
            print(f"Using bilingual captions: {english_path.name} + {chinese_path.name}")
        else:
            print(f"Using English captions only: {english_path.name}")
    else:
        if not srt_path.exists():
            raise FileNotFoundError(f"SRT transcript not found: {srt_path}")
        cues = load_cues(srt_path)
        print(f"Using fallback captions: {srt_path.name}")

    ass = build_ass_document(
        cues,
        font_size=read_int(config_path, "subtitle_font_size", 52),
        primary_color=read_simple_value(config_path, "subtitle_primary_color") or "#FFFFFF",
        outline_color=read_simple_value(config_path, "subtitle_outline_color") or "#000000",
        outline=read_int(config_path, "subtitle_outline", 3),
        margin_v=read_int(config_path, "subtitle_margin_v", 110),
        hook_text=read_simple_value(config_path, "hook_text"),
        hook_duration_sec=read_float(config_path, "hook_duration_sec", 3.0),
        hook_font_size=read_int(config_path, "hook_font_size", 68),
        hook_color=read_simple_value(config_path, "hook_color") or "#FFD400",
    )
    ass_path.write_text(ass, encoding="utf-8")
    print(f"Wrote styled ASS captions: {ass_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
