#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
omarchy_shell="${OMARCHY_PATH:-/usr/share/omarchy}/shell"
test_dir="$(mktemp -d --suffix=-olook-bar-tests)"
trap 'rm -rf -- "$test_dir"' EXIT
cp -r "$repo_dir/ui" "$test_dir/ui"
for module in Commons Ui services; do
  ln -s "$omarchy_shell/$module" "$test_dir/$module"
done
mkdir "$test_dir/bin"
cp "$repo_dir/tests/bar/fake_cli.py" "$test_dir/bin/olook"
chmod +x "$test_dir/bin/olook"
cp "$repo_dir/tests/bar/shell.qml" "$test_dir/shell.qml"
timeout 20 quickshell -p "$test_dir" --no-color 2>&1 | tee "$test_dir/result.log"
grep -q 'OLOOK_BAR_TESTS_PASS' "$test_dir/result.log"
! grep -q 'OLOOK_BAR_TESTS_FAIL' "$test_dir/result.log"
