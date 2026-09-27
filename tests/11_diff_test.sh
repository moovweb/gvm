#!/usr/bin/env bash
# gvm diff compares a tree with the manifest install recorded.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox go1.24.13 go1.27.1
trap gvm_test_sandbox_teardown EXIT

manifest() { (cd "$GVM_ROOT/gos/$1" && find . | sort > manifest); }

t "a freshly installed tree is clean"
manifest go1.24.13
capture out gvm diff 1.24.13
assert_eq 0 "$CAPTURE_STATUS"
assert_contains "$out" "Clean"

t "a partial version picks the newest match, not the oldest"
# The old `ls | sort -V | grep 1.24 | head -1` picked go1.24.13 here by luck;
# with 1.23.x present it would have been wrong, and the order was the bug.
mkdir -p "$GVM_ROOT/gos/go1.23.9/bin"
echo go1.23.9 > "$GVM_ROOT/gos/go1.23.9/VERSION"
manifest go1.23.9
capture out gvm diff 1.23
assert_eq 0 "$CAPTURE_STATUS"
assert_contains "$out" "go1.23.9"

t "an added file is reported"
echo "// hand written" > "$GVM_ROOT/gos/go1.24.13/src/extra.go"
capture out gvm diff 1.24.13
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "*Dirty*"
assert_contains "$out" "added:"
assert_contains "$out" "./src/extra.go"

t "a removed file is reported"
rm "$GVM_ROOT/gos/go1.24.13/VERSION"
capture out gvm diff 1.24.13
assert_contains "$out" "removed:"
assert_contains "$out" "./VERSION"

t "an unknown version is reported, not guessed"
capture out gvm diff 9.9.9
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "No installed Go matches"

t "a tree with no manifest says so"
capture out gvm diff 1.27.1
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "no manifest"

t "with nothing selected, diff explains what to do"
capture out gvm diff
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "gvm use"

t "diff uses a private temporary file, not a fixed path in /tmp"
# The old version wrote /tmp/manifest.test, which any user on the machine could
# pre-create as a symlink. Remove any leftover first so this tests the current
# code rather than a previous run.
rm -f /tmp/manifest.test
manifest go1.24.13
gvm diff 1.24.13 > /dev/null 2>&1
assert_eq "" "$(ls /tmp/manifest.test 2> /dev/null)"
# A TMPDIR of this test's own, so the check is about gvm diff and not about
# whatever else on the machine is writing to a shared /tmp. Counting a shared
# directory before and after failed once here for exactly that reason, and did
# not reproduce in eight later runs - the worst kind of failure to leave behind.
private_tmp="$GVM_TEST_TMP/diff-tmp"
mkdir -p "$private_tmp"
TMPDIR="$private_tmp" gvm diff 1.24.13 > /dev/null 2>&1
assert_eq "0" "$(ls -A "$private_tmp" 2> /dev/null | wc -l | tr -d ' ')" \
	"gvm diff left its temporary directory behind"

t "diff follows the current version when given nothing"
# Asserted separately: if the use fails, the diff below fails too and the
# failure points at the wrong line.
capture_in_shell out gvm use 1.24.13
assert_eq 0 "$CAPTURE_STATUS" "gvm use said: $out"
capture out gvm diff
assert_eq 0 "$CAPTURE_STATUS"

summary
