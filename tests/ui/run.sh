#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
omarchy_shell="${OMARCHY_PATH:-/usr/share/omarchy}/shell"
test_dir="$(mktemp -d --suffix=-olook-ui-tests)"
trap 'rm -rf -- "$test_dir"' EXIT
cp -r "$repo_dir/ui" "$test_dir/ui"
for module in Commons Ui services; do
  ln -s "$omarchy_shell/$module" "$test_dir/$module"
done
cp "$repo_dir/tests/ui/shell.qml" "$test_dir/shell.qml"
cc -shared -fPIC "$repo_dir/lib/argcshim.c" -ldl -o "$test_dir/argcshim.so"
LD_PRELOAD="$test_dir/argcshim.so${LD_PRELOAD:+:$LD_PRELOAD}" timeout 20 quickshell -p "$test_dir" --no-color 2>&1 | tee "$test_dir/result.log"
grep -q 'OLOOK_INTERACTION_TESTS_PASS' "$test_dir/result.log"
! grep -q 'INTERACTION_FAIL' "$test_dir/result.log"
