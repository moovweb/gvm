#!/usr/bin/env bash
# GOROOT_BOOTSTRAP requirements and resolution.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox go1.20.1 go1.24.6 go1.26.8 go1.27.1
trap gvm_test_sandbox_teardown EXIT

tsv="$(mktemp "${TMPDIR:-/tmp}/gvm-index.XXXXXX")"
gvm_test_cleanup_add 'rm -f "$tsv"'
printf 'V\tgo1.27.1\tstable\n' > "$tsv"
export GVM_INDEX_FILE="$tsv"

t "the documented floor for each release matches its own make.bash"
assert_eq go1.4 "$(gvm_bootstrap_floor go1.5)"
assert_eq go1.4 "$(gvm_bootstrap_floor go1.19.13)"
assert_eq go1.17.13 "$(gvm_bootstrap_floor go1.20)"
assert_eq go1.17.13 "$(gvm_bootstrap_floor go1.21.13)"
assert_eq go1.20.6 "$(gvm_bootstrap_floor go1.22)"
assert_eq go1.20.6 "$(gvm_bootstrap_floor go1.23.6)"
assert_eq go1.22.6 "$(gvm_bootstrap_floor go1.24)"
assert_eq go1.22.6 "$(gvm_bootstrap_floor go1.25.7)"
assert_eq go1.24.6 "$(gvm_bootstrap_floor go1.26)"
assert_eq go1.24.6 "$(gvm_bootstrap_floor go1.27.1)"

t "Go 1.4 and earlier bootstrap from C"
assert_eq c "$(gvm_bootstrap_floor go1.4.3)"
assert_eq c "$(gvm_bootstrap_floor go1.0.1)"

t "an unknown future release falls back to the even-minus-two rule"
# Go 1.N builds with Go 1.(N-2), rounded down to an even minor.
assert_eq go1.26 "$(gvm_bootstrap_floor go1.28)"
assert_eq go1.26 "$(gvm_bootstrap_floor go1.29)"
assert_eq go1.28 "$(gvm_bootstrap_floor go1.30)"
assert_eq go1.28 "$(gvm_bootstrap_floor go1.31)"

t "a non-version target is reported as unknown rather than guessed"
assert_eq unknown "$(gvm_bootstrap_floor master)"
assert_eq unknown "$(gvm_bootstrap_required stable)"

t "gvm_bootstrap_usable respects the floor"
assert_ok "" gvm_bootstrap_usable "$GVM_ROOT/gos/go1.27.1" go1.26.8
assert_ok "" gvm_bootstrap_usable "$GVM_ROOT/gos/go1.26.8" go1.27.1
# 1.26.8 declares a floor of 1.24.6, so 1.24.6 itself qualifies and 1.20.1 does not.
assert_ok "" gvm_bootstrap_usable "$GVM_ROOT/gos/go1.24.6" go1.26.8
assert_fail "" gvm_bootstrap_usable "$GVM_ROOT/gos/go1.20.1" go1.26.8

t "a C target needs no Go bootstrap at all"
assert_ok "" gvm_bootstrap_usable /nonexistent go1.4.3

t "a tree without bin/go is not a toolchain"
# This is the unpacked-source-tarball case that used to get nominated to build
# itself, because a source tarball ships a VERSION file.
mkdir -p "$GVM_ROOT/gos/go1.30.0/src"
echo "1.30" > "$GVM_ROOT/gos/go1.30.0/VERSION"
assert_fail "" gvm_bootstrap_usable "$GVM_ROOT/gos/go1.30.0" go1.28
assert_not_contains "$(gvm_bootstrap_installed_candidates)" "go1.30.0"
rm -rf "$GVM_ROOT/gos/go1.30.0"

t "only real toolchains are offered as bootstrap candidates"
assert_eq "$GVM_ROOT/gos/go1.20.1 $GVM_ROOT/gos/go1.24.6 $GVM_ROOT/gos/go1.26.8 $GVM_ROOT/gos/go1.27.1" \
	"$(gvm_bootstrap_installed_candidates | tr '\n' ' ' | sed 's/ $//')"

t "resolve picks the oldest qualifying toolchain, as upstream tests"
# Oldest, because that is the combination the Go project itself builds with.
assert_eq "$GVM_ROOT/gos/go1.24.6" "$(gvm_bootstrap_resolve go1.26.8)"
assert_eq "$GVM_ROOT/gos/go1.20.1" "$(gvm_bootstrap_resolve go1.20.1)"
# 1.22 declares a floor of 1.20.6, so the installed 1.20.1 is too old for it.
assert_eq "$GVM_ROOT/gos/go1.24.6" "$(gvm_bootstrap_resolve go1.22.1)"

t "resolve fails with an actionable message when nothing qualifies"
assert_fails_with "gvm install go1.28" gvm_bootstrap_resolve go1.30

t "an explicit GOROOT_BOOTSTRAP wins, and is validated"
assert_eq "$GVM_ROOT/gos/go1.27.1" \
	"$(GOROOT_BOOTSTRAP="$GVM_ROOT/gos/go1.27.1" gvm_bootstrap_resolve go1.26.8)"
with_bootstrap() { GOROOT_BOOTSTRAP="$1" gvm_bootstrap_resolve "$2"; }
assert_fails_with "cannot build" with_bootstrap "$GVM_ROOT/gos/go1.20.1" go1.27.1

t "GVM_BOOTSTRAP_GOROOT overrides GOROOT_BOOTSTRAP"
assert_eq "$GVM_ROOT/gos/go1.27.1" \
	"$(GVM_BOOTSTRAP_GOROOT="$GVM_ROOT/gos/go1.27.1" GOROOT_BOOTSTRAP="$GVM_ROOT/gos/go1.20.1" \
		gvm_bootstrap_resolve go1.26.8)"

t "an explicit GOROOT_BOOTSTRAP that is not a Go tree is rejected"
# Not /usr: a CI runner has a real Go there, and the point of the assertion is
# a directory that cannot be a toolchain.
not_a_toolchain="$GVM_TEST_TMP/not-a-toolchain"
mkdir -p "$not_a_toolchain"
assert_fails_with "cannot build" with_bootstrap "$not_a_toolchain" go1.26.8

t "gvm_go_version_of reads VERSION"
assert_eq go1.27.1 "$(gvm_go_version_of "$GVM_ROOT/gos/go1.27.1")"
assert_fail "" gvm_go_version_of "$GVM_ROOT/nosuchdir"

t "gvm_bootstrap_explain is human readable"
assert_contains "$(gvm_bootstrap_explain go1.24.13)" "Go 1.22.6"
assert_contains "$(gvm_bootstrap_explain go1.4.3)" "C"

t "a git checkout's version is derived from its nearest tag"
mkdir -p "$GVM_ROOT/gos/master/src"
printf 'package goversion\n\nconst TheVersion = "go1.28-devel_20260101120000"\n' \
	> "$GVM_ROOT/gos/master/src/internal_goversion.go"
mkdir -p "$GVM_ROOT/gos/master/src/internal/goversion"
mv "$GVM_ROOT/gos/master/src/internal_goversion.go" \
	"$GVM_ROOT/gos/master/src/internal/goversion/goversion.go"
assert_eq go1.28 "$(gvm_bootstrap_checkout_version "$GVM_ROOT/gos/master")"
assert_eq go1.26 "$(gvm_bootstrap_floor "$(gvm_bootstrap_checkout_version "$GVM_ROOT/gos/master")")"

t "an unreadable checkout falls back to the newest known release"
mkdir -p "$GVM_ROOT/gos/empty"
assert_eq go1.27.1 "$(gvm_bootstrap_checkout_version "$GVM_ROOT/gos/empty")"

summary
