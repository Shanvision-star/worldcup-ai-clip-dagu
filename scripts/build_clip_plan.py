"""剪辑计划生成：先产出可人工审核的 JSON 草稿，后续再接 LLM 或规则引擎。"""

from __future__ import annotations

import argparse
import json
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
    transcript = root / "data" / "transcripts" / f"{slug}.srt"
    clips_dir = root / "data" / "clips"
    clips_dir.mkdir(parents=True, exist_ok=True)

    plan = {
        "slug": slug,
        "status": "needs_human_review",
        "transcript": str(transcript),
        "clips": [
            {
                "id": "clip-001",
                "start": "00:00:00.000",
                "end": "00:00:30.000",
                "reason": "MVP placeholder. Replace with reviewed narrative segment.",
            }
        ],
        "review_checklist": [
            "rights verified",
            "source attribution checked",
            "copyright music removed or replaced",
            "title and cover are original",
            "domestic platform compliance reviewed",
        ],
    }

    out_path = clips_dir / f"{slug}.clip-plan.json"
    out_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote clip plan: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

