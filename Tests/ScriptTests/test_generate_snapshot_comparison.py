import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[2] / "Scripts/generate_snapshot_comparison.py"
SPEC = importlib.util.spec_from_file_location("alert_snapshot_report", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class SnapshotComparisonTests(unittest.TestCase):
    def test_union_keeps_blank_opposite_side(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            png = b"\x89PNG\r\n\x1a\nfixture"
            (root / "testEveryUIKitExample.both.png").write_bytes(png)
            (root / "testEverySwiftUIExample.both.png").write_bytes(png)
            (root / "testEveryUIKitExample.uikit-only.png").write_bytes(png)
            pairs = MODULE.discover(root)
            self.assertEqual([pair.key for pair in pairs], ["both", "uikit-only"])
            self.assertIsNone(pairs[1].swiftui)
            report = MODULE.build_html(pairs)
            self.assertIn('class="blank"', report)
            self.assertIn("data:image/png;base64,", report)

    def test_html_escapes_keys(self):
        report = MODULE.build_html([MODULE.Pair("<unsafe>", None, None)])
        self.assertIn("&lt;unsafe&gt;", report)
        self.assertNotIn("<unsafe>", report)


if __name__ == "__main__":
    unittest.main()
