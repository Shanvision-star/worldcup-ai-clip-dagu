import unittest

from scripts.caption_utils import (
    ass_color_from_hex,
    build_ass_document,
    parse_srt,
)


class CaptionUtilsTest(unittest.TestCase):
    def test_converts_css_hex_to_ass_bgr_color(self):
        self.assertEqual(ass_color_from_hex("#FFFFFF"), "&H00FFFFFF")
        self.assertEqual(ass_color_from_hex("#2F80ED"), "&H00ED802F")

    def test_builds_styled_ass_with_hook_and_subtitle_event(self):
        cues = parse_srt(
            "1\n"
            "00:00:01,000 --> 00:00:03,500\n"
            "English line\n"
            "中文字幕\n"
        )

        ass = build_ass_document(
            cues,
            font_size=52,
            primary_color="#FFFFFF",
            outline_color="#000000",
            hook_text="3秒看懂这个瞬间",
            hook_duration_sec=2.5,
            hook_font_size=68,
            hook_color="#FFD400",
        )

        self.assertIn("Style: Default,Microsoft YaHei,52,&H00FFFFFF", ass)
        self.assertIn("Style: Hook,Microsoft YaHei,68,&H0000D4FF", ass)
        self.assertIn("Dialogue: 0,0:00:00.00,0:00:02.50,Hook", ass)
        self.assertIn("3秒看懂这个瞬间", ass)
        self.assertIn("English line\\N中文字幕", ass)


if __name__ == "__main__":
    unittest.main()
