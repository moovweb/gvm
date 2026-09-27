#!/usr/bin/env bash
# gvm implode refuses to delete anything it is not sure about.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox go1.24.13
trap gvm_test_sandbox_teardown EXIT

# implode destroys GVM_ROOT, so every case gets a sandbox of its own.
sandbox() {
	gvm_test_sandbox go1.24.13
	SANDBOX="$GVM_TEST_SANDBOX"
}

t "implode refuses a GVM_ROOT that is not a gvm root"
plain="$(mktemp -d "${TMPDIR:-/tmp}/gvm-plain.XXXXXX")"
touch "$plain/important.txt"
# A directory that has the script but not a VERSION file: the shape of a
# mistyped GVM_ROOT, and the case the guard exists for.
mkdir -p "$plain/scripts/env"
cp "$GVM_SOURCE_ROOT/scripts/env/implode" "$plain/scripts/env/implode"
capture out env GVM_ROOT="$plain" gvm implode --force
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "does not look like a gvm root"
assert_ok "" test -f "$plain/important.txt"
rm -rf "$plain"

t "implode refuses an empty GVM_ROOT"
capture out env GVM_ROOT="" gvm implode --force
assert_ne 0 "$CAPTURE_STATUS"

# implode's job includes taking the gvm line out of the shell profiles in $HOME,
# and GVM_ROOT being sandboxed does not sandbox $HOME. Every call here therefore
# runs with a fake home: two of these tests once took the line out of the
# developer's own ~/.zshrc.
fake_home="$(mktemp -d "${TMPDIR:-/tmp}/gvm-home.XXXXXX")"
printf 'export PATH=/usr/bin\nexport EDITOR=vi\n' > "$fake_home/.bashrc"
printf '# zshrc\n' > "$fake_home/.zshrc"
export HOME="$fake_home"
gvm_test_cleanup_add 'rm -rf "$fake_home"'

t "implode refuses $HOME outright"
capture out env GVM_ROOT="$HOME" gvm implode --force
assert_ne 0 "$CAPTURE_STATUS"

t "implode will not block on stdin when there is no terminal"
# This is what hung CI: `read` with nothing behind it.
sandbox
capture out gvm implode
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "Not a terminal"
assert_ok "" test -d "$SANDBOX/scripts"

t "implode says what it is about to delete"
capture out gvm implode
assert_contains "$out" "1 Go version(s)"

t "implode --force removes the root"
capture out gvm implode --force
assert_eq 0 "$CAPTURE_STATUS"
assert_fail "" test -d "$SANDBOX"

t "implode takes the gvm line out of a shell profile, and keeps a backup"
sandbox
# The fake home has to live outside the sandbox, or implode deletes it as part
# of removing GVM_ROOT.
printf 'export PATH=/usr/bin\n# ~/.gvm/scripts/gvm\nexport EDITOR=vi\n' > "$fake_home/.bashrc"
capture out env HOME="$fake_home" gvm implode --force
assert_eq 0 "$CAPTURE_STATUS"
assert_fail "" grep -q 'scripts/gvm' "$fake_home/.bashrc"
assert_contains "$(cat "$fake_home/.bashrc")" "export EDITOR=vi"
assert_contains "$(cat "$fake_home/.bashrc")" "export PATH=/usr/bin"
assert_ok "" test -f "$fake_home/.bashrc.gvm-backup"

t "implode --help explains the flag"
sandbox
capture out gvm implode --help
assert_contains "$out" "--force"

t "implode rejects an unknown option"
sandbox
capture out gvm implode --yes
assert_ne 0 "$CAPTURE_STATUS"
assert_ok "" test -d "$SANDBOX/scripts"

summary
