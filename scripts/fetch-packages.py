#!/usr/bin/env python3
"""Fetches the app's Swift packages as source archives instead of git clones.

GitHub git transfers kept getting cut off on this network, while codeload
archives download fine. Each revision pinned in Package.resolved is unpacked
under build/LocalPackages, and build/ExcalidrawZPersonal.xcworkspace adds them
as local packages, which override the project's remote ones — so building that
workspace never clones anything (binary targets still download their zips).
"""
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

repo = pathlib.Path(__file__).resolve().parents[1]
resolved = (
    repo
    / "ExcalidrawZ.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
)
packages_dir = repo / "build/LocalPackages"
workspace = repo / "build/ExcalidrawZPersonal.xcworkspace"

pins = json.loads(resolved.read_text())["pins"]
sources = [(pin["location"], pin["state"]["revision"]) for pin in pins]

packages_dir.mkdir(parents=True, exist_ok=True)
names = []
for location, revision in sources:
    url = location.rstrip("/").removesuffix(".git")
    owner, name = url.split("/")[-2:]
    # a local package's identity is its directory's name, like a remote one's
    target = packages_dir / name
    marker = target / ".excalidrawz-revision"
    names.append(name)
    if marker.exists() and marker.read_text() == revision:
        print(f"up to date  {name}")
        continue
    with tempfile.TemporaryDirectory() as tmp:
        archive = pathlib.Path(tmp) / "source.tar.gz"
        subprocess.run(
            [
                "curl", "-sSfL", "--retry", "6", "--retry-all-errors",
                "--connect-timeout", "20", "-o", str(archive),
                f"https://codeload.github.com/{owner}/{name}/tar.gz/{revision}",
            ],
            check=True,
        )
        shutil.rmtree(target, ignore_errors=True)
        target.mkdir(parents=True)
        subprocess.run(
            ["tar", "-xzf", str(archive), "-C", str(target), "--strip-components=1"],
            check=True,
        )
    if not (target / "Package.swift").exists():
        sys.exit(f"{name}: no Package.swift at {revision}")
    marker.write_text(revision)
    print(f"fetched     {name} @ {revision[:10]}")

# Local packages are resolved like root packages, test targets included, so
# their test-only dependencies (not in Package.resolved) must resolve too.
# Nothing builds them: a stand-in with the same products is enough.
stub = packages_dir / "swift-snapshot-testing"
(stub / "Sources/SnapshotTesting").mkdir(parents=True, exist_ok=True)
(stub / "Sources/SnapshotTesting/Stub.swift").write_text(
    "// Stand-in for a test-only dependency (see scripts/fetch-packages.py).\n"
)
(stub / "Package.swift").write_text(
    "// swift-tools-version:5.5\n"
    "import PackageDescription\n\n"
    "let package = Package(\n"
    '    name: "swift-snapshot-testing",\n'
    '    products: [.library(name: "SnapshotTesting", targets: ["SnapshotTesting"])],\n'
    '    targets: [.target(name: "SnapshotTesting")]\n'
    ")\n"
)
names.append(stub.name)

workspace.mkdir(parents=True, exist_ok=True)
refs = [
    f'   <FileRef\n      location = "group:{location}">\n   </FileRef>'
    for location in ["../ExcalidrawZ.xcodeproj"] + [f"LocalPackages/{n}" for n in names]
]
(workspace / "contents.xcworkspacedata").write_text(
    '<?xml version="1.0" encoding="UTF-8"?>\n<Workspace\n   version = "1.0">\n'
    + "\n".join(refs)
    + "\n</Workspace>\n"
)
print(f"workspace   {workspace}")
