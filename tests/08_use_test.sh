#!/usr/bin/env bash
# gvm use, gvm uninstall, and the reporting commands that read the result.
#
# `gvm use` changes the calling shell's environment, so it cannot be run inside
# $( ) here; these tests call it directly and then inspect $GOROOT.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox go1.24.13 go1.27.1
trap gvm_test_sandbox_teardown EXIT

tsv="$GVM_TEST_TMP/index.tsv"
cat > "$tsv" <<'TSV'
V	go1.24.13	stable
V	go1.25.0rc1	unstable
V	go1.27.1	stable
TSV
export GVM_INDEX_FILE="$tsv"

# A git checkout, which is what a --from-git install leaves behind.
mkdir -p "$GVM_ROOT/gos/master/bin"
printf '#!/bin/sh\necho "go version devel go1.99-abcdef linux/amd64"\n' \
	> "$GVM_ROOT/gos/master/bin/go"
chmod +x "$GVM_ROOT/gos/master/bin/go"
cat > "$GVM_ROOT/environments/master" <<ENVEOF
export gvm_go_name; gvm_go_name="master"
export GOROOT; GOROOT="\$GVM_ROOT/gos/master"
export PATH; PATH="\$GOROOT/bin:\$PATH"
ENVEOF

t "use switches the calling shell to the named version"
capture_in_shell out gvm use go1.24.13
assert_eq 0 "$CAPTURE_STATUS"
assert_contains "$out" "Now using version go1.24.13"
assert_eq go1.24.13 "$gvm_go_name"
assert_eq "$GVM_ROOT/gos/go1.24.13" "$GOROOT"
assert_contains "$PATH" "$GVM_ROOT/gos/go1.24.13/bin"

t "use takes the old GOROOT off PATH"
# Switching versions must not leave the previous toolchain's bin behind,
# otherwise the first `go` on PATH wins and the switch appears to do nothing.
assert_eq "0" "$(printf '%s' "$PATH" | tr ':' '\n' | grep -c "$GVM_ROOT/gos/go1.27.1/bin")"

t "use accepts a partial version against the local installs"
capture_in_shell out gvm use 1.27
assert_contains "$out" "go1.27.1"
assert_eq go1.27.1 "$gvm_go_name"

t "use --default records the default as well as switching"
capture_in_shell out gvm use 1.24.13 --default
assert_eq 0 "$CAPTURE_STATUS"
assert_eq go1.24.13 "$(gvm_default_recorded)"
assert_eq go1.24.13 "$(gvm_alias_resolve default)"

t "use follows an alias that points at a git checkout"
gvm_alias_create dev master
capture_in_shell out gvm use dev
assert_contains "$out" "master"
assert_eq master "$gvm_go_name"

t "gvm current prints the version on stdout, so it can be captured"
assert_eq master "$(gvm current 2>/dev/null)"

t "gvm current annotates on stderr, where a script will not see it"
capture_in_shell out gvm use master --default
assert_contains "$(gvm current 2>&1 >/dev/null)" "default"

t "use of an unknown version fails and changes nothing"
before="$gvm_go_name"
capture_in_shell out gvm use 1.99.9
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "Version not found"
assert_eq "$before" "$gvm_go_name"

t "use of a published version that is not installed says which it is"
# A bare pre-release is a version like any other: it must be recognised as a
# real release that simply is not installed yet.
capture_in_shell out gvm use 1.25.0rc1
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "1.25.0rc1 is not installed"
assert_contains "$out" "gvm install"

t "gvm which reports the GOROOT of a named version"
assert_eq "$GVM_ROOT/gos/go1.24.13" "$(gvm which 1.24.13 2>/dev/null | head -1)"

t "gvm which with no argument follows the current version"
capture out gvm which
assert_contains "$out" "gos/master"

t "gvm ls lists installed versions, marking the active and the default"
out="$(gvm ls 2>/dev/null)"
assert_contains "$out" "go1.27.1"
assert_contains "$out" "go1.24.13"
assert_contains "$out" "master"
assert_contains "$out" "-> master"
assert_contains "$out" "default"
assert_contains "$out" "-> go1.24.13"

t "gvm ls-remote lists stable releases by default"
out="$(gvm ls-remote 2>/dev/null)"
assert_contains "$out" "go1.27.1"
assert_not_contains "$out" "go1.25.0rc1"
assert_not_contains "$out" "master"

t "gvm ls-remote --prerelease includes release candidates"
out="$(gvm ls-remote --prerelease 2>/dev/null)"
assert_contains "$out" "go1.25.0rc1"

t "gvm ls-remote --all includes both, newest first"
assert_eq "go1.27.1 go1.25.0rc1 go1.24.13" "$(gvm ls-remote --all --table | grep '^go' | cut -d' ' -f1 | tr '\n' ' ' | sed 's/ $//')"

t "gvm ls-remote marks what is already installed"
assert_contains "$(gvm ls-remote 2>/dev/null)" "(*) = already installed"

t "uninstall refuses the version in use without --force"
capture_in_shell out gvm uninstall master
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "in use"
assert_ok "" test -d "$GVM_ROOT/gos/master"

t "uninstall removes the tree, the environment and the pkgset"
capture_in_shell out gvm uninstall go1.24.13
assert_eq 0 "$CAPTURE_STATUS"
assert_fail "" test -d "$GVM_ROOT/gos/go1.24.13"
assert_fail "" test -f "$GVM_ROOT/environments/go1.24.13"
assert_fail "" test -d "$GVM_ROOT/pkgsets/go1.24.13"

t "uninstall removes the aliases that pointed at the version"
gvm_test_add_version go1.26.3
gvm_alias_create old 1.26.3 > /dev/null
gvm_alias_create older old > /dev/null
assert_eq go1.26.3 "$(gvm_alias_resolve older)"
capture_in_shell out gvm uninstall go1.26.3
assert_eq "" "$(gvm_alias_raw old)"
assert_contains "$out" "Removed aliases that pointed at it"

t "uninstall moves the default rather than leaving it dangling"
gvm_test_add_version go1.26.3
capture_in_shell out gvm use 1.26.3 --default
assert_eq go1.26.3 "$(gvm_default_recorded)"
capture_in_shell out gvm uninstall go1.26.3 --force
assert_ne go1.26.3 "$(gvm_default_recorded)"
assert_ok "" test -d "$GVM_ROOT/gos/$(gvm_default_recorded)"
assert_eq "$(gvm_default_recorded)" "$(sed -n 's/^export gvm_go_name; gvm_go_name="\(.*\)"$/\1/p' "$GVM_ROOT/environments/default")"

t "uninstall of a version that is not installed fails"
capture_in_shell out gvm uninstall go9.9.9
assert_ne 0 "$CAPTURE_STATUS"

t "uninstall never touches a built-in alias"
assert_eq go1.27.1 "$(gvm_alias_resolve stable)"
assert_eq go1.25.0rc1 "$(gvm_alias_resolve unstable)"

t "selecting a version pins GOTOOLCHAIN"
# Since Go 1.21 the go command downloads and switches to whatever a go.mod asks
# for, so without this a project declaring `go 1.30` would quietly build with a
# toolchain other than the one selected.
capture_in_shell out gvm use 1.24.13
assert_eq "local" "${GOTOOLCHAIN:-unset}"

t "gvm use system gives the toolchain switching back"
capture_in_shell out gvm use system
assert_eq "unset" "${GOTOOLCHAIN:-unset}"

t "the environment file records the pin, so a new shell starts pinned"
assert_contains "$(cat "$GVM_ROOT/environments/go1.27.1")" 'GOTOOLCHAIN="local"'

summary
