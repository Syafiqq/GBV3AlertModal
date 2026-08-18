#!/usr/bin/env python3
"""Build a self-contained UIKit / SwiftUI catalog snapshot comparison."""

from __future__ import annotations

import argparse
import base64
import html
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SNAPSHOTS = ROOT / "Examples/GBV3AlertModalExample/GBV3AlertModalExampleTests/__Snapshots__/CatalogSnapshotComparisonTests"
OUTPUT = ROOT / ".build/reports/alert-modal-snapshot-comparison.html"
TEST_PROJECT = ROOT / "Examples/GBV3AlertModalExample/GBV3AlertModalExample.xcodeproj"
DERIVED_DATA = ROOT / ".build/catalog-snapshot-derived-data"


@dataclass(frozen=True)
class Pair:
    key: str
    uikit: Path | None
    swiftui: Path | None


def discover(snapshot_dir: Path = SNAPSHOTS) -> list[Pair]:
    sides: dict[str, dict[str, Path]] = {}
    pattern = re.compile(r"testEvery(?P<side>UIKit|SwiftUI)Example\.(?P<key>.+)\.png$")
    for path in snapshot_dir.glob("*.png"):
        match = pattern.fullmatch(path.name)
        if match:
            sides.setdefault(match["key"], {})[match["side"].lower()] = path
    if not sides:
        raise SystemExit(f"No catalog snapshots found in {snapshot_dir}")
    return [Pair(key, value.get("uikit"), value.get("swiftui")) for key, value in sorted(sides.items())]


def image(path: Path | None, label: str, key: str) -> str:
    if path is None:
        return f'<figure class="blank" aria-label="No {html.escape(label)} example"></figure>'
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return (f'<figure><figcaption>{html.escape(label)}</figcaption>'
            f'<img alt="{html.escape(label)} {html.escape(key)}" src="data:image/png;base64,{encoded}"></figure>')


def build_html(pairs: list[Pair]) -> str:
    cards = "".join(
        f'<article><header><h2>{html.escape(pair.key.replace("-", " ").title())}</h2>'
        f'<code>{html.escape(pair.key)}</code></header><div class="two">'
        f'{image(pair.uikit, "UIKit", pair.key)}{image(pair.swiftui, "SwiftUI", pair.key)}</div></article>'
        for pair in pairs
    )
    return f'''<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width"><title>Alert modal snapshot comparison</title>
<style>:root{{font:15px system-ui;color-scheme:dark;background:#101217;color:#f6f7fb}}body{{margin:0;padding:28px}}main{{max-width:1500px;margin:auto}}article{{padding:16px;margin:0 0 22px;background:#1a1e27;border:1px solid #303746;border-radius:14px}}header{{display:flex;justify-content:space-between;align-items:baseline;gap:12px}}h2{{font-size:16px;margin:0 0 12px}}code,figcaption{{font-size:12px;color:#aab4c8}}.two{{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}}figure{{margin:0;padding:10px;min-height:140px;border:1px solid #303746;border-radius:9px;background:#141922}}figcaption{{font-weight:700;margin-bottom:8px}}img{{display:block;width:100%;height:auto}}.blank{{background:transparent;border-style:dashed}}@media(max-width:800px){{body{{padding:14px}}.two{{grid-template-columns:1fr}}}}</style></head>
<body><main><h1>Alert modal renderer comparison</h1><p>UIKit on the left, SwiftUI on the right. A blank panel means that example is absent from that renderer.</p>{cards}</main></body></html>'''


def run_tests(destination: str) -> None:
    subprocess.run(["xcodebuild", "test", "-project", str(TEST_PROJECT), "-scheme", "GBV3AlertModalExample",
                    "-destination", destination, "-derivedDataPath", str(DERIVED_DATA),
                    "-only-testing:GBV3AlertModalExampleTests/CatalogSnapshotComparisonTests",
                    "-skip-testing:GBV3AlertModalExampleUITests",
                    "-parallel-testing-enabled", "NO"], cwd=ROOT, check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-tests", action="store_true")
    parser.add_argument("--destination", default="platform=iOS Simulator,name=iPhone 17")
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    if not args.skip_tests:
        run_tests(args.destination)
    pairs = discover()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(build_html(pairs), encoding="utf-8")
    print(f"Wrote {len(pairs)} comparisons to {args.output}")


if __name__ == "__main__":
    main()
