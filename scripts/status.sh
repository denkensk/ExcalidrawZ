#!/bin/bash
python3 - << 'PY'
import glob, re, os
rows = []
for f in sorted(glob.glob("tasks/*.md")):
    meta = {}
    text = open(f, encoding="utf-8").read()
    m = re.match(r"^---\n(.*?)\n---", text, re.S)
    if m:
        for line in m.group(1).splitlines():
            if ":" in line:
                k, v = line.split(":", 1)
                meta[k.strip()] = v.strip()
    rows.append((meta.get("status", "?"), os.path.basename(f),
                 meta.get("title", ""), meta.get("updated", "")))
order = {"active": 0, "blocked": 1, "paused": 2, "done": 3}
for status, fname, title, updated in sorted(rows, key=lambda r: order.get(r[0], 9)):
    print(f"  [{status:<7}] {fname:<24} {title}  ({updated})")
print(f"\n{len(rows)} workstream(s)")
PY
