#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
test_dir="$(mktemp -d --suffix=-olook-tests)"
trap 'rm -rf -- "$test_dir"' EXIT
mkdir "$test_dir/ui"
cp "$repo_dir/ui/Service.qml" "$repo_dir/ui/Model.js" "$test_dir/ui/"
cp "$repo_dir/tests/service/shell.qml" "$test_dir/shell.qml"
quickshell -p "$test_dir" --no-color 2>&1 | tee "$test_dir/result.log"
grep -q 'OLOOK_SERVICE_TESTS_PASS' "$test_dir/result.log"
! grep -q 'OLOOK_SERVICE_TESTS_FAIL' "$test_dir/result.log"
