#!/usr/bin/env bash
#
# tests/lib.sh - a tiny assertion library and a sandbox builder.
#
# The previous suite was written for moovweb/gvm's "tf" framework, which had to
# be installed separately, shelled out to a Ruby process per assertion, and
# tested against go1.6.4 and go1.7.6. This needs nothing but bash, awk and a
# tarball, and every test runs against a throwaway GVM_ROOT.

set -u

# The harness looks for English shell diagnostics ("command not found",
# "unbound variable"), and so do the assertions on gvm's own output. On a
# zh_TW or ja_JP machine bash says 未找到命令 instead, so a real failure slips
# through: that is how `gvm_flag_is_set: command not found` went unnoticed while
# every test passed. gvm's own translations are unaffected: locale_text_for_key
# takes the locale as an argument and only en-US ships.
export LC_ALL=C

# The checkout under test, used to build sandboxes.
GVM_SOURCE_ROOT="${GVM_SOURCE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export GVM_SOURCE_ROOT

# Every sandbox this process has built, one path per line, and the cleanup a
# test file has registered. A file that builds more than one sandbox - implode
# destroys GVM_ROOT, so it needs one per case - used to leave all but the last
# behind, and a file that wanted to clean up after itself had only one EXIT trap
# to spend, which is the harness's. Six files were leaving a throwaway GVM_ROOT
# on every run because of the two together.
GVM_TEST_SANDBOXES=""
GVM_TEST_CLEANUP=""

# gvm_test_cleanup_add <command>
# Run by the harness's own EXIT trap, after the test file is finished. This is
# how a file tidies up: not with `trap ... EXIT`, which replaces the trap that
# removes the sandbox and the profile snapshot.
gvm_test_cleanup_add() {
	GVM_TEST_CLEANUP="${GVM_TEST_CLEANUP}${1}
"
}

GVM_TEST_PASS=0
GVM_TEST_FAIL=0
GVM_TEST_NAME=""
# Set once a test's name has been printed, so a test with four assertions shows
# its name once instead of four times.
GVM_TEST_NAME_SHOWN=0
CAPTURE_STATUS=0

RED="" GREEN="" YELLOW="" DIM="" RESET=""
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then
	RED=$'\033[0;31m'
	GREEN=$'\033[0;32m'
	YELLOW=$'\033[0;33m'
	DIM=$'\033[2m'
	RESET=$'\033[0m'
fi

t() {
	GVM_TEST_NAME="$1"
	GVM_TEST_NAME_SHOWN=0
	# Appended, not printed: a test file's stdout is block-buffered when run.sh
	# pipes it, so a file that hangs has its last few lines still sitting in a
	# buffer and the log ends at whatever fitted in 4KB. This goes to a file as
	# each test starts, so a hang says which test hung.
	if [ -n "${GVM_TEST_TRACE:-}" ]; then
		printf '%s\n' "$GVM_TEST_NAME" >> "$GVM_TEST_TRACE" 2> /dev/null
	fi
}

# _gvm_test_label
# Prints the test name on the first assertion of a test, and a blank marker
# afterwards, so a group of assertions reads as one test.
_gvm_test_label() {
	if [ "$GVM_TEST_NAME_SHOWN" = "0" ]; then
		printf '  %s\n' "$GVM_TEST_NAME"
		GVM_TEST_NAME_SHOWN=1
	else
		printf '  %s|%s\n' "$DIM" "$RESET"
	fi
}

_pass() {
	GVM_TEST_PASS=$((GVM_TEST_PASS + 1))
	_gvm_test_label
	printf '   %sok%s\n' "$GREEN" "$RESET"
}

_fail() {
	GVM_TEST_FAIL=$((GVM_TEST_FAIL + 1))
	_gvm_test_label
	printf '   %sFAIL%s\n' "$RED" "$RESET"
	local line
	for line in "$@"; do
		printf '       %s%s%s\n' "$DIM" "$line" "$RESET"
	done
}

# assert_eq <expected> <actual> [label]
assert_eq() {
	local expected="$1" actual="$2" label="${3:-}"
	if [ "$expected" = "$actual" ]; then
		_pass
	else
		_fail "expected: [$expected]" "actual:   [$actual]" "${label:+($label)}"
	fi
}

# assert_ne <not-expected> <actual> [label]
assert_ne() {
	local unexpected="$1" actual="$2" label="${3:-}"
	if [ "$unexpected" != "$actual" ]; then
		_pass
	else
		_fail "expected anything but: [$unexpected]" "(${label:-})"
	fi
}

# assert_contains <haystack> <needle> [label]
assert_contains() {
	local haystack="$1" needle="$2" label="${3:-}"
	case "$haystack" in
		*"$needle"*) _pass ;;
		*) _fail "expected to contain: [$needle]" "actual: [$haystack]" "${label:+($label)}" ;;
	esac
}

# assert_not_contains <haystack> <needle> [label]
assert_not_contains() {
	local haystack="$1" needle="$2" label="${3:-}"
	case "$haystack" in
		*"$needle"*) _fail "expected NOT to contain: [$needle]" "actual: [$haystack]" "${label:+($label)}" ;;
		*) _pass ;;
	esac
}

# assert_rc <expected-status> <cmd...>
assert_rc() {
	local expected="$1"
	shift
	local out status
	out="$("$@" 2>&1)"
	status=$?
	if [ "$status" = "$expected" ]; then
		_pass
	else
		_fail "expected exit status $expected, got $status" "command: $*" "output: $out"
	fi
}

# assert_fails_with <needle> <cmd...>
# The command must fail *and* its output must mention <needle>, so the test
# covers both the status and the message the user actually reads.
assert_fails_with() {
	local needle="$1"
	shift
	local out
	if out="$("$@" 2>&1)"; then
		_fail "expected failure from: $*" "output: $out"
		return
	fi
	case "$out" in
		*"$needle"*) _pass ;;
		*) _fail "expected the message to mention: [$needle]" "output: $out" ;;
	esac
}

# capture <varname> <cmd...>
# Runs a command once, storing its combined output in <varname> and its exit
# status in CAPTURE_STATUS. More readable than chasing `$?` through an
# assignment, and it only ever runs the command one time.
capture() {
	local __name="$1"
	shift
	local __out
	__out="$("$@" 2>&1)"
	CAPTURE_STATUS=$?
	printf -v "$__name" '%s' "$__out"
	return 0
}

# capture_in_shell <varname> <cmd...>
# Like capture, but runs in the *current* shell. `gvm use` changes the calling
# shell's environment, so a subshell would throw away the very thing under test.
capture_in_shell() {
	local __name="$1"
	shift
	local __file="$GVM_TEST_TMP/capture.out"
	"$@" > "$__file" 2>&1
	CAPTURE_STATUS=$?
	printf -v "$__name" '%s' "$(cat "$__file")"
	return 0
}

# run <label> <cmd...>
# Runs a command and fails the test if its output contains a shell-level error
# that the command itself may not have turned into a non-zero status - an unset
# variable under `set -u`, a bad substitution, a missing binary. This is the
# check that catches the set -u landmines no exit code reports.
run() {
	local label="$1"
	shift
	capture out env GVM_QUIET=1 "$@"
	case "$out" in
		*unbound\ variable* | *"bad substitution"* | *"command not found"* | *"no such file or directory: "*)
			_fail "$label" "shell error: $out" ;;
		*) _pass ;;
	esac
}

# assert_ok <label> <cmd...>
assert_ok() {
	local label="$1"
	shift
	local out
	if out="$("$@" 2>&1)"; then
		_pass
	else
		_fail "$label" "command: $*" "output: $out"
	fi
}

# assert_fail <label> <cmd...>
assert_fail() {
	local label="$1"
	shift
	local out
	if out="$("$@" 2>&1)"; then
		_fail "$label" "expected failure from: $*" "output: $out"
	else
		_pass
	fi
}

summary() {
	echo
	if [ "$GVM_TEST_FAIL" = "0" ]; then
		printf '%s%d passed, 0 failed%s\n' "$GREEN" "$GVM_TEST_PASS" "$RESET"
		return 0
	fi
	printf '%s%d passed, %d failed%s\n' "$RED" "$GVM_TEST_PASS" "$GVM_TEST_FAIL" "$RESET"
	return 1
}

# gvm_test_sandbox [version...]
# Builds a GVM_ROOT containing fake but structurally complete Go trees, and
# exports GVM_ROOT. No network and no real Go toolchain is required.
# The developer's own profile files are recorded before a test runs and checked
# after it. GVM_ROOT is sandboxed but $HOME is not, and `gvm implode` and
# `install.sh --uninstall` both edit the gvm line in $HOME's profiles as part of
# their job. Tests that ran those with the real HOME took the line out of a real
# ~/.zshrc, which is what this check exists to make impossible to miss again.
#
# The snapshot is a directory of copies compared with `cmp`, not a list of
# md5sums. macOS has no md5sum - brew's coreutils installs it as gmd5sum - so a
# guard built on it quietly did nothing on the one platform where a developer is
# most likely to have a real ~/.zshrc to lose. cmp is in POSIX.
#
# The real path of each copy is recorded in a manifest rather than rebuilt from
# $HOME at check time, because a test that points HOME at a fake home (which
# implode tests must) would otherwise make every real profile look deleted.
gvm_test_watch_real_profiles() {
	# Once per test file, not once per sandbox: a file that calls `sandbox` again
	# after pointing HOME somewhere else must keep watching the developer's real
	# home, which is the whole point.
	[ -n "${GVM_TEST_PROFILE_SNAPSHOT:-}" ] && return 0
	GVM_TEST_PROFILE_SNAPSHOT="$(mktemp -d "$GVM_TEST_TMPBASE"/gvm-home.XXXXXX)"
	: > "$GVM_TEST_PROFILE_SNAPSHOT/manifest"
	local f n=0
	for f in .bashrc .zshrc .profile .bash_profile .zprofile .zshenv; do
		# A file that cannot be read must not stop the run; leaving it out of
		# the manifest means the guard makes no claim about it.
		[ -f "$HOME/$f" ] && cp "$HOME/$f" "$GVM_TEST_PROFILE_SNAPSHOT/$n" 2> /dev/null || continue
		printf '%s\t%s\n' "$n" "$HOME/$f" >> "$GVM_TEST_PROFILE_SNAPSHOT/manifest"
		n=$((n + 1))
	done
	export GVM_TEST_PROFILE_SNAPSHOT
}

gvm_test_profiles_unchanged() {
	local snap copy path changed=0
	snap="${GVM_TEST_PROFILE_SNAPSHOT:-}"
	[ -s "$snap/manifest" ] || return 0
	while IFS="$(printf '\t')" read -r copy path; do
		[ -n "$copy" ] && [ -n "$path" ] || continue
		if [ ! -f "$path" ]; then
			printf '          %s (deleted)\n' "$path"
			changed=1
		elif ! cmp -s "$snap/$copy" "$path"; then
			printf '          %s (changed)\n' "$path"
			changed=1
		fi
	done < "$snap/manifest"
	[ "$changed" = 0 ] && return 0
	printf '\n  FAIL  a test wrote to your real home directory:\n'
	printf '        GVM_ROOT is sandboxed but HOME is not, and implode and\n'
	printf '        install.sh --uninstall edit the gvm line in these files.\n'
	return 1
}

gvm_test_sandbox() {
	local root leaked
	# Drop every GVM_* the developer brought in with them. Somebody who has gvm
	# sourced in their own shell exports GVM_SOURCED=1 and GVM_ROOT, and
	# scripts/gvm returns on sight when it sees GVM_SOURCED, so the suite went
	# through testing nothing: 12 and 16 failed on a laptop with gvm installed
	# and passed in CI, which has no GVM_* in its environment. A test suite that
	# only works on a machine without the thing installed is not a test suite.
	# Tests set the variables they need after this, so nothing is lost. The
	# harness's own GVM_TEST_* and GVM_SOURCE_ROOT stay: they describe the copy
	# of gvm under test, not the one the developer has installed.
	for leaked in $(env | sed -n 's/^\(GVM[A-Za-z0-9_]*\)=.*/\1/p'); do
		case "$leaked" in
			GVM_TEST_* | GVM_SOURCE_ROOT) continue ;;
		esac
		unset "$leaked"
	done
	gvm_test_watch_real_profiles
	root="$(mktemp -d "$GVM_TEST_TMPBASE"/gvm-test.XXXXXX)"
	ln -s "$GVM_SOURCE_ROOT/scripts" "$root/scripts"
	ln -s "$GVM_SOURCE_ROOT/bin" "$root/bin"
	mkdir -p "$root/logs" "$root/gos" "$root/archive/package" \
		"$root/environments" "$root/aliases" "$root/cache" "$root/pkgsets/global"
	echo "0.0.0-test" > "$root/VERSION"

	local version
	for version in "$@"; do
		mkdir -p "$root/gos/$version/bin" "$root/gos/$version/src" "$root/gos/$version/pkg"
		# A real tarball's VERSION file carries the `go` prefix.
		echo "$version" > "$root/gos/$version/VERSION"
		cat > "$root/gos/$version/bin/go" <<GOEOF
#!/bin/sh
[ "\$1" = "version" ] && echo "go version ${version} \$(uname -s)/\$(uname -m)"
[ "\$1" = "env" ] && [ "\$2" = "GOVERSION" ] && echo "${version}"
exit 0
GOEOF
		chmod +x "$root/gos/$version/bin/go"
		# The same shape `gvm install` writes, so the tests read what users get.
		cat > "$root/environments/$version" <<ENVEOF
export GVM_ROOT; GVM_ROOT="$root"
export gvm_go_name; gvm_go_name="$version"
export gvm_pkgset_name; gvm_pkgset_name="global"
export GOROOT; GOROOT="\$GVM_ROOT/gos/$version"
export GOPATH; GOPATH="\$GVM_ROOT/pkgsets/$version/global"
export PATH; PATH="\${GVM_ROOT}/pkgsets/$version/global/bin:\${GVM_ROOT}/gos/$version/bin:\$PATH"
export GOTOOLCHAIN; GOTOOLCHAIN="local"
ENVEOF
	done

	export GVM_ROOT="$root"
	unset GOROOT GOPATH GOBIN GOOS GOARCH GVM_VERSION gvm_go_name gvm_pkgset_name
	mkdir -p "$root/tmp"
	GVM_TEST_SANDBOX="$root"
	GVM_TEST_SANDBOXES="${GVM_TEST_SANDBOXES}${root}
"
	GVM_TEST_TMP="$root/tmp"
	# The sandbox's own bin/ goes first, so a `gvm` left over from a real
	# installation on the developer's PATH can never be the one under test.
	PATH="$root/bin:$PATH"
	# shellcheck disable=SC1091
	. "$root/scripts/functions"
	# `use`, `pkgset use` and `implode` are shell functions, because they have to
	# change the calling shell's environment. Source them so the tests exercise
	# the same entry point a user has.
	# shellcheck disable=SC1091
	. "$root/scripts/env/gvm"
}

# gvm_test_add_version <name>
# Adds one more fake-but-complete Go tree and environment to the sandbox, for
# tests that need a version the sandbox was not built with.
gvm_test_add_version() {
	local version="${1:-}" root="$GVM_TEST_SANDBOX"
	[ -n "$version" ] || return 1
	mkdir -p "$root/gos/$version/bin" "$root/gos/$version/pkg"
	echo "$version" > "$root/gos/$version/VERSION"
	cat > "$root/gos/$version/bin/go" <<GOEOF
#!/bin/sh
[ "\$1" = "version" ] && echo "go version $version linux/amd64"
[ "\$1" = "env" ] && [ "\$2" = "GOVERSION" ] && echo "$version"
exit 0
GOEOF
	chmod +x "$root/gos/$version/bin/go"
	cat > "$root/environments/$version" <<ENVEOF
export GVM_ROOT; GVM_ROOT="$root"
export gvm_go_name; gvm_go_name="$version"
export gvm_pkgset_name; gvm_pkgset_name="global"
export GOROOT; GOROOT="\$GVM_ROOT/gos/$version"
export GOPATH; GOPATH="\$GVM_ROOT/pkgsets/$version/global"
export PATH; PATH="\${GVM_ROOT}/pkgsets/$version/global/bin:\${GVM_ROOT}/gos/$version/bin:\$PATH"
export GOTOOLCHAIN; GOTOOLCHAIN="local"
ENVEOF
	mkdir -p "$root/pkgsets/$version/global/overlay/bin"
}

# macOS sets TMPDIR to .../T/ - with the trailing slash - so anything built as
# "${TMPDIR}/name" ends up with a // in it. That is not cosmetic here: several
# tests compare a path built from the sandbox root against the output of pwd,
# and pwd collapses the double slash, so the two disagree on macOS only.
GVM_TEST_TMPBASE="${TMPDIR:-/tmp}"
while [ "${GVM_TEST_TMPBASE}" != "/" ] && [ "${GVM_TEST_TMPBASE%/}" != "${GVM_TEST_TMPBASE}" ]
do
	GVM_TEST_TMPBASE="${GVM_TEST_TMPBASE%/}"
done
# Then resolve symlinks in it, once, here rather than in each test. gvm's own
# scripts work out GVM_ROOT from the physical location of the file they were
# sourced from, so a test that compares a path built out of TMPDIR against
# something gvm reported has both ends spelled the same way - which is what
# macOS needs, where $TMPDIR is under /var and /var is a symlink to
# /private/var. Everything derived from this is physical from here on.
#
# A TMPDIR that is not a directory - a stale value from a previous login, or a
# name somebody made up to reproduce the trailing-slash case - is created if it
# can be. It cannot simply be ignored: mktemp then fails, the sandbox is never
# built, GVM_TEST_TMP keeps its default of /tmp, and the suite writes its
# throwaway trees into the real one while reporting a shape it never tested.
if ! mkdir -p "$GVM_TEST_TMPBASE" 2> /dev/null ||
	! GVM_TEST_TMPBASE="$(cd "$GVM_TEST_TMPBASE" 2> /dev/null && pwd -P)" ||
	[ -z "$GVM_TEST_TMPBASE" ]; then
	printf 'gvm tests: TMPDIR "%s" is not a directory this suite can use.\n' \
		"${TMPDIR:-/tmp}" >&2
	exit 1
fi

gvm_test_sandbox_teardown() {
	local status=0
	# `return` from an EXIT trap does not change the exit status, so a test file
	# that edited the developer's ~/.bashrc would still report success. exit
	# does, and run.sh treats a non-zero status as a failure.
	gvm_test_profiles_unchanged || status=1
	if [ -n "$GVM_TEST_CLEANUP" ]; then
		eval "$GVM_TEST_CLEANUP" 2> /dev/null
		GVM_TEST_CLEANUP=""
	fi
	# Newline-separated and read with IFS= rather than split on spaces: TMPDIR
	# containing a space is one of the shapes this suite is here to cover.
	if [ -n "$GVM_TEST_SANDBOXES" ]; then
		while IFS= read -r sandbox; do
			[ -n "$sandbox" ] && rm -rf "$sandbox"
		done <<SANDBOXES
$GVM_TEST_SANDBOXES
SANDBOXES
	fi
	[ -n "${GVM_TEST_SANDBOX:-}" ] && rm -rf "$GVM_TEST_SANDBOX"
	[ -n "${GVM_TEST_PROFILE_SNAPSHOT:-}" ] && rm -rf "$GVM_TEST_PROFILE_SNAPSHOT"
	[ "$status" = 0 ] && return 0
	printf '  FAIL  this test file changed files in your real home directory\n'
	exit 1
}
