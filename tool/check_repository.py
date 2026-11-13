#!/usr/bin/env python3
"""Inspect indexed files without printing their content. No third-party modules."""

from pathlib import PurePosixPath
import re
import subprocess
import sys


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", *args])


files = [p.decode() for p in git("ls-files", "-z").split(b"\0") if p]
problems: list[str] = []
private_dirs = {"private", "documents", "uploads", "scans", "exports", "backups", "recovery", "secrets", ".secrets", ".ssh", ".aws"}
private_extensions = {".pdf", ".csv", ".xlsx", ".xls", ".db", ".sqlite", ".sqlite3", ".pem", ".key", ".jks", ".keystore", ".p12", ".pfx", ".enc", ".age", ".dump", ".mobileprovision", ".provisionprofile", ".apk", ".aab", ".ipa"}
secret_patterns = [
    re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(rb"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b"),
    re.compile(rb"\bsb_secret_[A-Za-z0-9_-]{15,}\b"),
    re.compile(rb"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(rb"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"),
]
for file in files:
    path = PurePosixPath(file)
    approved_image = (
        path.parts[0] == "assets"
        or re.fullmatch(r"android/app/src/main/res/mipmap-[^/]+/ic_launcher\.png", file)
        or re.fullmatch(r"ios/Runner/Assets\.xcassets/(AppIcon\.appiconset|LaunchImage\.imageset)/[^/]+\.png", file)
    )
    if (
        private_dirs.intersection(path.parts)
        or path.suffix.lower() in private_extensions
        or any(part in {".tools", ".cache", ".dart_tool", "build"} for part in path.parts)
        or (path.name.startswith(".env") and path.name != ".env.example")
        or path.name in {"google-services.json", "GoogleService-Info.plist", "key.properties"}
        or tuple(path.parts[:2]) == ("config", "local")
        or (path.suffix.lower() in {".png", ".jpg", ".jpeg", ".heic"} and not approved_image)
    ):
        problems.append(f"Forbidden tracked data/config path: {file}")
    content = git("show", f":{file}")
    if len(content) > 2 * 1024 * 1024:
        problems.append(f"Unexpected large indexed file: {file}")
    if any(pattern.search(content) for pattern in secret_patterns):
        problems.append(f"Potential credential in indexed file: {file} (content redacted)")

ignore_probes = [
    ".env", ".env.production", "config/local/development.json", "credentials.json",
    "supabase/.temp/access-token", "private/identity.pdf", "documents/scan.jpg",
    "exports/finance.csv", "backups/vault.enc", "vault.sqlite3", "vault.sqlite3-wal",
    "android/key.properties", "android/app/release.jks", ".tools/flutter/bin/flutter",
    ".cache/checks/build.log", "build/app.apk",
]
for probe in ignore_probes:
    result = subprocess.run(["git", "check-ignore", "--quiet", "--no-index", probe], check=False)
    if result.returncode != 0:
        problems.append(f"Sensitive/generated path not ignored: {probe}")

if problems:
    print("\n".join(problems), file=sys.stderr)
    sys.exit(1)
print(f"Repository policy: {len(files)} indexed files checked; credential patterns and ignore probes passed")
print("Inspect the staged diff and run Gitleaks too; pattern scans cannot prove absence of personal data.")
