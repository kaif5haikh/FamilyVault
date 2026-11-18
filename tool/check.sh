#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "$0")/env.sh"
cd -- "$FAMILYVAULT_ROOT"
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
dart run build_runner build
flutter analyze --no-pub
flutter test --no-pub
python3 tool/audit_dependencies.py
bash tool/check_proposals.sh
bash tool/check_backend.sh
git diff --check
# Also inspect staged content before committing; see .githooks/pre-commit.
