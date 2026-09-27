#!/usr/bin/env bash
# Every command must be `set -u` safe and must fail with a message rather than a
# shell error. Users run `set -u` in their profiles, and the old scripts assumed
# that every environment variable was always set.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox go1.24.13
trap gvm_test_sandbox_teardown EXIT

tsv="$GVM_TEST_TMP/index.tsv"
printf 'V\tgo1.24.13\tstable\n' > "$tsv"
export GVM_INDEX_FILE="$tsv"

# run <label> <cmd...> - the command may fail; it may not leak a shell error.

t "gvm which prints the GOROOT, and a binary inside it"
assert_eq "$GVM_ROOT/gos/go1.24.13" "$(gvm which 1.24)"
assert_eq "$GVM_ROOT/gos/go1.24.13/bin/go" "$(gvm which 1.24 go)"

t "gvm which with nothing selected says so"
capture out gvm which
assert_contains "$out" "No Go version is currently selected"

# `gvm use` has to happen in the same shell as the `gvm which` that reads it:
# selecting a version is an environment change, and capture/subshells throw it
# away. The later "nothing selected" test still needs an empty selection, so
# nothing is selected in this shell.
t "gvm which reads the selected version when there is one"
assert_eq "$GVM_ROOT/gos/go1.24.13" "$(gvm use go1.24.13 > /dev/null 2>&1; gvm which)"
assert_eq "$GVM_ROOT/gos/go1.24.13" "$(gvm use go1.24.13 > /dev/null 2>&1; gvm which current)"
assert_eq "$GVM_ROOT/gos/go1.24.13/bin/go" "$(gvm use go1.24.13 > /dev/null 2>&1; gvm which current go)"

t "gvm which go is a command lookup, not a missing version"
# The documented spelling is `gvm which current go`, but `gvm which go` is what
# gets typed. It used to answer "install it with 'gvm install go'", which reads
# like a version called "go" was missing.
assert_eq "$GVM_ROOT/gos/go1.24.13/bin/go" "$(gvm use go1.24.13 > /dev/null 2>&1; gvm which go)"

t "gvm which says what to do for a name that is neither"
capture out gvm which nosuchthing
assert_contains "$out" "gvm which current nosuchthing"

t "no command dies on an unset variable"
for cmd in current which version ls ls-remote doctor help pkgenv diff pkgset \
	completion uninstall implode list listall update; do
	run "$cmd with nothing selected" gvm "$cmd"
done

t "no command dies on an unset variable with a version selected"
GVM_STRICT=1
( gvm use go1.24.13 > /dev/null 2>&1
	for cmd in current which version ls ls-remote doctor help pkgenv diff \
		completion uninstall list listall update; do
		run "$cmd with go1.24.13 selected" gvm "$cmd"
	done
	exit $?
)

t "commands that need a selection say so instead of crashing"
capture out gvm diff
assert_contains "$out" "No version selected"
assert_contains "$out" "gvm use"

capture out gvm pkgenv foo
assert_contains "$out" "gvm use"

capture out gvm pkgset create foo
assert_contains "$out" "gvm use"

capture out gvm pkgset delete foo
assert_contains "$out" "gvm use"

t "gvm version reports where GVM lives and what it found"
out="$(gvm version 2>&1)"
assert_contains "$out" "installed at $GVM_ROOT"
assert_contains "$out" "1 installed"
assert_contains "$out" "active      none"

t "an unknown command is a clear error, not a traceback"
capture out gvm frobnicate
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "Unrecognized command"

t "gvm with no arguments prints help rather than doing nothing"
capture out gvm
assert_contains "$out" "Usage:"

t "gvm help is the same text"
assert_eq "$(gvm help 2>&1)" "$(gvm 2>&1)"

t "every advertised command actually exists"
# `help` is documentation; if it drifts from bin/gvm the user is misled. This
# caught `cross`, which was advertised long after the script was removed.
missing=""
# Commands sit in a four-space column; wrapped prose is indented further, so
# anchoring on exactly four spaces keeps sentences out of the list.
for cmd in $(gvm help 2>&1 | sed -n 's/^    \([a-z][a-z-]*\) \{2,\}.*/\1/p' | sort -u); do
	case "$cmd" in
		use | env | pkgset | alias) continue ;;  # shell functions
	esac
	[ -e "$GVM_ROOT/scripts/$cmd" ] || [ -e "$GVM_ROOT/scripts/env/$cmd" ] || missing="$missing $cmd"
done
assert_eq "" "$missing"

t "every command that exists is advertised"
# The other direction: a script nobody can discover.
missing=""
for script in "$GVM_ROOT"/scripts/*; do
	[ -f "$script" ] || continue
	cmd="$(basename "$script")"
	case "$cmd" in
		functions | gvm.in | gvm-check | gvm-default | help | pkgset-*) continue ;;
	esac
	grep -qE "(^|[^a-z-])$cmd([^a-z-]|$)" <(gvm help 2>&1) || missing="$missing $cmd"
done
assert_eq "" "$missing"

t "gvm diff --help documents itself"
capture out gvm diff --help
assert_contains "$out" "Usage: gvm diff"

summary
