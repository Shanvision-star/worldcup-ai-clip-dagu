"""字幕样式工具：把 SRT 转成可控字号、颜色和开场 Hook 的 ASS 字幕。"""

from __future__ import annotations

import re
from dataclasses import dataclass


@dataclass(frozen=True)
class CaptionCue:
    start: str
    end: str
    lines: tuple[str, ...]


def ass_color_from_hex(value: str) -> str:
    cleaned = value.strip().lstrip("#")
    if len(cleaned) != 6 or not re.fullmatch(r"[0-9A-Fa-f]{6}", cleaned):
        raise ValueError(f"Invalid hex color: {value}")
    rr, gg, bb = cleaned[0:2], cleaned[2:4], cleaned[4:6]
    return f"&H00{bb.upper()}{gg.upper()}{rr.upper()}"


def parse_srt(content: str) -> list[CaptionCue]:
    blocks = re.split(r"\r?\n\r?\n+", content.strip())
    cues: list[CaptionCue] = []
    for block in blocks:
        lines = [line.strip("\ufeff") for line in block.splitlines() if line.strip()]
        if len(lines) < 2:
            continue
        timing_line = next((line for line in lines if "-->" in line), "")
        if not timing_line:
            continue
        start, end = [part.strip() for part in timing_line.split("-->", 1)]
        text_start = lines.index(timing_line) + 1
        text_lines = tuple(lines[text_start:])
        if text_lines:
            cues.append(CaptionCue(start=start, end=end, lines=text_lines))
    return cues


def srt_time_to_ass(value: str) -> str:
    match = re.fullmatch(r"(\d{2}):(\d{2}):(\d{2}),(\d{3})", value.strip())
    if not match:
        raise ValueError(f"Invalid SRT timestamp: {value}")
    hours, minutes, seconds, millis = match.groups()
    centiseconds = int(millis[:2])
    return f"{int(hours)}:{minutes}:{seconds}.{centiseconds:02d}"


def seconds_to_ass(value: float) -> str:
    if value < 0:
        raise ValueError("Duration cannot be negative.")
    total_centiseconds = int(round(value * 100))
    hours, remainder = divmod(total_centiseconds, 360000)
    minutes, remainder = divmod(remainder, 6000)
    seconds, centiseconds = divmod(remainder, 100)
    return f"{hours}:{minutes:02d}:{seconds:02d}.{centiseconds:02d}"


def escape_ass_text(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace("{", r"\{")
        .replace("}", r"\}")
        .replace("\n", r"\N")
    )


def build_ass_document(
    cues: list[CaptionCue],
    *,
    font_size: int = 52,
    primary_color: str = "#FFFFFF",
    outline_color: str = "#000000",
    outline: int = 3,
    margin_v: int = 110,
    hook_text: str = "",
    hook_duration_sec: float = 3.0,
    hook_font_size: int = 68,
    hook_color: str = "#FFD400",
) -> str:
    primary = ass_color_from_hex(primary_color)
    outline_ass = ass_color_from_hex(outline_color)
    hook_primary = ass_color_from_hex(hook_color)
    events: list[str] = []

    if hook_text.strip():
        events.append(
            "Dialogue: 0,0:00:00.00,"
            f"{seconds_to_ass(hook_duration_sec)},Hook,,0,0,0,,{escape_ass_text(hook_text.strip())}"
        )

    for cue in cues:
        text = r"\N".join(escape_ass_text(line) for line in cue.lines)
        events.append(
            "Dialogue: 0,"
            f"{srt_time_to_ass(cue.start)},{srt_time_to_ass(cue.end)},Default,,0,0,0,,{text}"
        )

    return "\n".join(
        [
            "[Script Info]",
            "ScriptType: v4.00+",
            "PlayResX: 1080",
            "PlayResY: 1920",
            "WrapStyle: 0",
            "ScaledBorderAndShadow: yes",
            "",
            "[V4+ Styles]",
            "Format: Name,Fontname,Fontsize,PrimaryColour,SecondaryColour,OutlineColour,BackColour,"
            "Bold,Italic,Underline,StrikeOut,ScaleX,ScaleY,Spacing,Angle,BorderStyle,Outline,Shadow,"
            "Alignment,MarginL,MarginR,MarginV,Encoding",
            f"Style: Default,Microsoft YaHei,{font_size},{primary},{primary},{outline_ass},&H80000000,"
            f"-1,0,0,0,100,100,0,0,1,{outline},1,2,60,60,{margin_v},1",
            f"Style: Hook,Microsoft YaHei,{hook_font_size},{hook_primary},{hook_primary},{outline_ass},&H80000000,"
            f"-1,0,0,0,100,100,0,0,1,{outline + 1},1,8,70,70,130,1",
            "",
            "[Events]",
            "Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text",
            *events,
            "",
        ]
    )
