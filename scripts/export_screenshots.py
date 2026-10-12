#!/usr/bin/env python3
"""Copy explicitly named XCTest screenshot attachments into the README gallery.

First export with:
  xcrun xcresulttool export attachments --path <result.xcresult> --output-path <dir>
Then run:
  python3 scripts/export_screenshots.py <dir>
"""
import json
import re
import shutil
import sys
from pathlib import Path

source = Path(sys.argv[1]).resolve()
destination = Path(__file__).resolve().parents[1] / "docs" / "screenshots"
destination.mkdir(parents=True, exist_ok=True)
manifest = json.loads((source / "manifest.json").read_text())
index = []
for test in manifest:
    for attachment in test["attachments"]:
        name = attachment["suggestedHumanReadableName"]
        match = re.match(r"(\d{2}-[a-z-]+)_", name)
        file = source / attachment["exportedFileName"]
        if not match or file.suffix != ".png":
            continue
        target = destination / (match.group(1) + ".png")
        shutil.copyfile(file, target)
        index.append({
            "file": target.name,
            "test": test["testIdentifier"],
            "device": attachment["deviceName"],
            "timestamp": attachment["timestamp"],
            "source": "Unmodified XCTest screenshot attachment",
        })
if not index:
    raise SystemExit("No named screenshots found; nothing exported.")
(destination / "manifest.json").write_text(json.dumps(sorted(index, key=lambda x: x["file"]), indent=2) + "\n")
print(f"Exported {len(index)} original screenshots to {destination}")
