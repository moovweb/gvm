#!/usr/bin/env bash
# Turning user input into a concrete version.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox go1.2.2 go1.9.7 go1.10.1 go1.24.12 go1.24.13 go1.27.1
trap gvm_test_sandbox_teardown EXIT

cp "$GVM_ROOT/environments/go1.24.13" "$GVM_ROOT/environments/default"

t "an exact installed version resolves to itself"
assert_eq go1.24.13 "$(gvm_resolve_version go1.24.13 local)"

t "1.24 resolves to the newest installed go1.24.x"
assert_eq go1.24.13 "$(gvm_resolve_version 1.24 local)"

t "1.2 resolves to go1.2.2, not to go1.24.x"
assert_eq go1.2.2 "$(gvm_resolve_version 1.2 local)"

t "a glob resolves to the newest match"
assert_eq go1.24.13 "$(gvm_resolve_version '1.24.1?' local)"

t "the default alias resolves"
assert_eq go1.24.13 "$(gvm_resolve_version default local)"

t "a partial version that is not installed does not fall back to a prefix match"
assert_eq "" "$(gvm_resolve_version 1.20 local 2> /dev/null || true)"

t "an unknown query fails rather than guessing"
assert_fail "" gvm_resolve_version nonexistent local
assert_fail "" gvm_resolve_version 9.9 local

t "local mode never returns something that is not installed"
# `stable` in local mode means "the newest stable version I have", not "the
# newest stable release that exists", so it legitimately resolves here. The
# property worth pinning down is that whatever comes back is really on disk.
for query in stable latest newest oldest 1.24 go1.24.13 go1.9.7; do
	if resolved="$(gvm_resolve_version "$query" local 2> /dev/null)"; then
		[ -d "$GVM_ROOT/gos/$resolved" ] || _fail "local '$query' returned $resolved, which is not installed"
	fi
done
_pass

t "a partial version with nothing installed locally fails"
# The sandbox has no go1.25.x, so this must not fall back to the newest release
# in the index: local mode never suggests something that needs downloading.
assert_fail "" gvm_resolve_version 1.25 local
assert_eq "" "$(gvm_resolve_version 1.25 local 2> /dev/null || true)"

t "master only exists when it was built from git"
assert_fail "" gvm_resolve_version master local
mkdir -p "$GVM_ROOT/gos/master/bin"
echo "devel" > "$GVM_ROOT/gos/master/VERSION"
assert_eq master "$(gvm_resolve_version master local)"
rm -rf "$GVM_ROOT/gos/master"

t "system is never resolved by the version layer"
assert_fail "" gvm_resolve_version system local

t "gvm_versions_installed skips half-finished installs"
mkdir -p "$GVM_ROOT/gos/go1.99.0"
assert_not_contains "$(gvm_versions_installed)" "go1.99.0"
rmdir "$GVM_ROOT/gos/go1.99.0"

t "gvm_version_installed"
assert_ok "" gvm_version_installed go1.24.13
assert_fail "" gvm_version_installed go1.99.0

summary
