#!/usr/bin/env python3
"""Query OSV with public package names/versions only. No project content is sent."""

import json
from pathlib import Path
import subprocess
import sys
import urllib.error
import urllib.request


try:
    graph = json.loads(subprocess.check_output(["flutter", "pub", "deps", "--json"]))
    packages = [p for p in graph["packages"] if p.get("source") == "hosted"]
    queries = [
        {"package": {"name": p["name"], "ecosystem": "Pub"}, "version": p["version"]}
        for p in packages
    ]
    if not queries:
        raise ValueError("No hosted packages found; refusing to report an empty audit")
    request = urllib.request.Request(
        "https://api.osv.dev/v1/querybatch",
        data=json.dumps({"queries": queries}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "FamilyVault-dependency-review"},
    )
    with urllib.request.urlopen(request, timeout=45) as response:
        result = json.load(response)
    if len(result["results"]) != len(queries):
        raise ValueError("Incomplete advisory response")
    report = {
        "checked_packages": len(packages),
        "findings": [
            {"name": p["name"], "version": p["version"], "ids": [v["id"] for v in r["vulns"]]}
            for p, r in zip(packages, result["results"])
            if r.get("vulns")
        ],
    }
except (OSError, ValueError, KeyError, subprocess.CalledProcessError, urllib.error.URLError) as error:
    print(f"Dependency audit unavailable ({type(error).__name__}); no security conclusion", file=sys.stderr)
    sys.exit(2)

Path(".cache/checks").mkdir(parents=True, exist_ok=True)
Path(".cache/checks/osv-resolved.json").write_text(json.dumps(report, indent=2) + "\n")
print(f"OSV Pub advisory query: {report['checked_packages']} resolved hosted packages checked")
for finding in report["findings"]:
    print(f"{finding['name']} {finding['version']}: {', '.join(finding['ids'])}")
if not report["findings"]:
    print("No advisory matches returned; native/platform vulnerabilities require separate review.")
sys.exit(1 if report["findings"] else 0)
