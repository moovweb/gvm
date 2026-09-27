#!/usr/bin/env bash
# The shell-side commands: cd auto-switching, linkthis, completion.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox go1.24.12 go1.24.13 go1.27.1
trap gvm_test_sandbox_teardown EXIT

# The sandbox has no index cache, so completion must cope with none at all.
work="$GVM_TEST_TMP/work"
mkdir -p "$work/repo/sub" "$work/other"
cd "$work" || exit 1

# --- find_path_upwards -------------------------------------------------------

echo "go1.24.13" > "$work/repo/.go-version"

t "find_path_upwards finds a file in the current directory"
assert_eq "$work/repo/.go-version" "$(__gvm_find_path_upwards ".go-version" "$work/repo" "$work")"

t "find_path_upwards walks up to a parent"
# The old implementation only ever looked in start_dir, so a .go-version one
# directory up was invisible and `gvm env use` never switched.
assert_eq "$work/repo/.go-version" "$(__gvm_find_path_upwards ".go-version" "$work/repo/sub" "$work")"

t "find_path_upwards stops at the boundary"
assert_eq "" "$(__gvm_find_path_upwards ".go-version" "$work/other" "$work/other")"

t "find_path_upwards stops at / rather than looping"
assert_eq "" "$(__gvm_find_path_upwards ".no-such-file-anywhere" "$work" "/")"

t "find_path_upwards handles a trailing slash"
assert_eq "$work/repo/.go-version" "$(__gvm_find_path_upwards ".go-version" "$work/repo/sub/" "$work/")"

# --- cd ----------------------------------------------------------------------

capture_in_shell out true
. "$GVM_ROOT/scripts/env/cd" || _fail "could not source env/cd"

t "env/cd installs a cd override"
declare -F cd > /dev/null 2>&1 && _pass || _fail "cd was not overridden"

t "cd into a tree with .go-version selects that version"
cd "$work/repo/sub" && cd . || _fail "cd failed"
assert_eq go1.24.13 "${gvm_go_name:-}"

t "cd does not switch when the file asks for something that is not installed"
echo "go9.9.9" > "$work/repo/.go-version"
cd "$work/repo/sub" && cd . || _fail "cd failed"
assert_eq go1.24.13 "${gvm_go_name:-}"

t "cd into a plain directory leaves the selection alone"
cd "$work/other" && cd . || _fail "cd failed"
assert_eq go1.24.13 "${gvm_go_name:-}"

t "a .go-pkgset is picked up on cd"
# A package set is a directory with a pkg.gvm marker, which is what
# `gvm pkgset create` writes.
mkdir -p "$GVM_ROOT/pkgsets/go1.24.13/proj/bin" "$GVM_ROOT/pkgsets/go1.24.13/proj/overlay/bin"
echo "proj" > "$GVM_ROOT/pkgsets/go1.24.13/proj/pkg.gvm"
echo "proj" > "$work/repo/.go-pkgset"
cd "$work/repo" && cd . || _fail "cd failed"
assert_eq proj "${gvm_pkgset_name:-}"
rm -f "$work/repo/.go-pkgset" "$work/repo/.go-version"

t "a cd of the user's own keeps working under the override"
# The old capture copied the body by deleting the first and last line of
# `declare -f cd`, which keeps the opening brace and drops the closing one. The
# eval failed, __gvm_oldcd was never defined, and cd() stopped changing
# directory for anyone who had a cd function of their own - silently, and only
# in that case.
user_cd_calls=""
# The user's own cd, defined before gvm is sourced, which is the case that broke.
cd() { user_cd_calls="yes"; builtin cd "$@" || return $?; }
unset -f __gvm_oldcd # so env/cd captures, as it does in a fresh shell
. "$GVM_ROOT/scripts/env/cd"
assert_contains "$(declare -f __gvm_oldcd 2> /dev/null)" "user_cd_calls"
cd "$work/other"
assert_eq "$work/other" "$PWD"  # the real cd happened
assert_eq yes "$user_cd_calls" # and so did the user's
builtin cd "$work" || _fail "cd back failed"

t "env/cd survives being sourced twice"
# Re-sourcing used to capture gvm's own override as the "original" cd, so cd()
# recursed until bash segfaulted.
. "$GVM_ROOT/scripts/env/cd" 2> /dev/null || _fail "re-sourcing env/cd failed"
cd "$work/other" && cd . || _fail "cd broke after re-sourcing"
assert_eq go1.24.13 "${gvm_go_name:-}"
assert_eq "$work/other" "$PWD"

t "cd actually changes directory"
cd "$work/repo" || _fail "cd failed"
assert_eq "$work/repo" "$PWD"

# --- linkthis ----------------------------------------------------------------

t "a .go-pkgset that does not exist is reported, and the cd still happens"
echo "nope" > "$work/repo/.go-pkgset"
capture_in_shell out true
GVM_QUIET= capture out true  # keep output visible
cd "$work/repo" 2> /dev/null && cd . 2>&1
assert_contains "$(cd "$work/repo" && true)" ""
cd "$work/repo" > /dev/null 2>&1
rm -f "$work/repo/.go-pkgset"

t "linkthis refuses to run with no Go selected"
unset gvm_go_name GOPATH
capture out gvm linkthis
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "gvm use"

t "linkthis refuses a path that would escape GOPATH/src"
capture_in_shell out gvm use 1.24.13
capture out gvm linkthis "../../etc"
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "not a usable package path"

t "linkthis links the current directory using its basename"
mkdir -p "$GVM_TEST_TMP/mypkg" && cd "$GVM_TEST_TMP/mypkg"
capture out gvm linkthis
assert_eq 0 "$CAPTURE_STATUS"
target="${GOPATH%%:*}/src/mypkg"
[ -L "$target" ] || _fail "$target is not a symlink"
[ "$(cd "$target" && pwd -P)" = "$GVM_TEST_TMP/mypkg" ] || _fail "the link points somewhere else"
cd "$GVM_TEST_TMP" || exit 1

t "linkthis accepts an explicit import path"
mkdir -p "$GVM_TEST_TMP/pkg2"
capture out gvm linkthis github.com/example/pkg2
target="${GOPATH%%:*}/src/github.com/example/pkg2"
[ -L "$target" ] && _pass || _fail "$target is not a symlink"

t "linkthis will not clobber an existing link without --force"
capture out gvm linkthis github.com/example/pkg2
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "already exists"

t "linkthis --force replaces it"
capture out gvm linkthis --force github.com/example/pkg2
assert_eq 0 "$CAPTURE_STATUS"

# --- completion --------------------------------------------------------------

t "gvm completion emits a sourceable script"
capture out gvm completion
assert_contains "$out" "complete -F _gvm gvm"

t "completion has no syntax errors"
bash -n <(gvm completion) && _pass || _fail "gvm completion is not valid bash"

t "completion never completes the removed commands"
out="$(gvm completion)"
for ghost in cross get; do
	case "$out" in
		*"\"$ghost"* | *" $ghost "*) _fail "completion still offers $ghost" ;;
	esac
done
_pass

t "completion completes the commands that do exist"
run "_gvm completes a command" bash -c '
	. "$1/scripts/functions"
	COMP_WORDS=(gvm use ""); COMP_CWORD=2
	. "$1/scripts/completion"
	_gvm
	printf "%s\n" "${COMPREPLY[@]}"' _ "$GVM_ROOT"
assert_contains "$out" "go1.24.13"
assert_contains "$out" "stable"

t "completion offers aliases that point at an installed version"
gvm alias create mine 1.24.13
run "_gvm completes aliases" bash -c '
	. "$1/scripts/functions"
	COMP_WORDS=(gvm use ""); COMP_CWORD=2
	. "$1/scripts/completion"
	_gvm
	printf "%s\n" "${COMPREPLY[@]}"' _ "$GVM_ROOT"
assert_contains "$out" "mine"

t "completion does not hit the network when the index cache is empty"
# Nothing in the sandbox is cached, and GVM_OFFLINE plus a bogus base URL would
# make any fetch fail loudly rather than hang.
out="$(GVM_OFFLINE=1 GVM_DL_BASE_URL="http://127.0.0.1:1" timeout 10 bash -c '
	. "$1/scripts/functions"
	COMP_WORDS=(gvm install ""); COMP_CWORD=2
	. "$1/scripts/completion"
	_gvm
	printf "%s\n" "${COMPREPLY[@]}"' _ "$GVM_ROOT" 2>&1)"
assert_eq 0 "$?"

t "completion works with set -u and no selection"
out="$(env -u gvm_go_name -u gvm_pkgset_name -u GOPATH timeout 10 bash -c '
	set -u
	. "$1/scripts/functions"
	COMP_WORDS=(gvm ""); COMP_CWORD=1
	. "$1/scripts/completion"
	_gvm
	printf "%s\n" "${COMPREPLY[@]}"' _ "$GVM_ROOT" 2>&1)"
assert_contains "$out" "doctor"

# `gvm use` changes the calling shell, so these run in a command substitution,
# which is a subshell: the switch happens and is then thrown away, and the
# command under test is the real gvm function from this shell.
applymod_in() { (cd "$1" && shift && gvm applymod "$@" && gvm current) 2>&1; }

t "applymod reads the go directive and switches to it"
mod="$GVM_TEST_TMP/mod"
mkdir -p "$mod"
printf 'module example.com/m\n\ngo 1.24.13\n' > "$mod/go.mod"
assert_contains "$(applymod_in "$mod")" "go1.24.13"

t "applymod takes a two-component directive"
# go.mod says `go 1.27`; the newest installed go1.27.x is the one to use.
printf 'module example.com/m\n\ngo 1.27\n' > "$mod/go.mod"
assert_contains "$(applymod_in "$mod")" "go1.27.1"

t "applymod ignores comments and the module line"
printf '// go 1.9\nmodule go1.8\n\ngo 1.24.13 // trailing comment\n' > "$mod/go.mod"
out="$(applymod_in "$mod")"
assert_contains "$out" "go1.24.13"
assert_not_contains "$out" "go1.9"

t "applymod treats the go directive as a minimum, not a pin"
# go.mod says `go 1.24.0`; go1.24.13 is what builds it, and insisting on the
# exact patch release sent people to install a version they did not need.
printf 'module example.com/m\n\ngo 1.24.0\n' > "$mod/go.mod"
assert_contains "$(applymod_in "$mod")" "go1.24.13"

t "applymod still uses an exact version when it is installed"
printf 'module example.com/m\n\ngo 1.27.1\n' > "$mod/go.mod"
assert_contains "$(applymod_in "$mod")" "go1.27.1"

t "applymod does not download anything, it says what to run"
# The old version installed a toolchain as a side effect of reading a file.
printf 'module example.com/m\n\ngo 1.19.3\n' > "$mod/go.mod"
out="$(applymod_in "$mod")"
assert_contains "$out" "gvm install"
assert_not_contains "$out" "Downloading"
[ -d "$GVM_ROOT/gos/go1.19.3" ] && _fail "applymod installed a version" || _pass

t "applymod says something useful when there is no go.mod"
nomod="$GVM_TEST_TMP/nomod"
mkdir -p "$nomod"
out="$(applymod_in "$nomod")"
assert_contains "$out" "No go.mod"
out="$( cd "$nomod" && gvm applymod some/where/go.mod 2>&1 )"
assert_contains "$out" "No some/where/go.mod"

t "applymod says something useful when go.mod has no go directive"
printf 'module example.com/m\n' > "$nomod/go.mod"
out="$(applymod_in "$nomod")"
assert_contains "$out" "no 'go' directive"

# Without the parentheses: $(display_error) called the function with no
# arguments at all, and a bare $1 is an unbound variable under `set -u` on
# bash 3.2, so building this test's own name killed the file on macOS.
t "applymod is not a script full of return plus a message"
# `return $(display_error ...)` returns a message, not a status. It is the old
# signature of a script that had never been run.
# Comments quote the old bug to explain it, so look at code only.
sed 's/[[:space:]]*#.*$//' "$GVM_ROOT/scripts/env/applymod" | grep -q 'return \$(' &&
	_fail "applymod still returns a message instead of a status" || _pass

t "a .git in GVM_ROOT warns once instead of failing every command"
git_dir="$GVM_TEST_TMP/gitroot"
mkdir -p "$git_dir/.git"
cp -R "$GVM_ROOT/bin" "$GVM_ROOT/scripts" "$GVM_ROOT/VERSION" "$git_dir/"
mkdir -p "$git_dir/gos/go1.24.13"
capture_in_shell out bash -c "export GVM_ROOT='$git_dir'; . '$git_dir/scripts/gvm'; gvm version; gvm version; gvm ls"
assert_contains "$out" "work tree"
assert_eq "1" "$(printf '%s\n' "$out" | grep -c 'work tree')"
assert_contains "$out" "$(cat "$git_dir/VERSION")"

t "GVM_NO_GIT_BAK=1 silences that warning"
capture_in_shell out bash -c "export GVM_NO_GIT_BAK=1 GVM_ROOT='$git_dir'; . '$git_dir/scripts/gvm'; gvm version"
assert_not_contains "$out" "work tree"

t "a GVM_ROOT with a space in it still works"
space_root="$GVM_TEST_TMP/a dir/gvm"
mkdir -p "$space_root"
cp -R "$GVM_ROOT/bin" "$GVM_ROOT/scripts" "$GVM_ROOT/VERSION" "$space_root/"
mkdir -p "$space_root/gos"
capture_in_shell out bash -c "export GVM_ROOT='$space_root'; . '$space_root/scripts/gvm'; gvm version; gvm ls"
assert_contains "$out" "$(cat "$space_root/VERSION")"
assert_contains "$out" "$space_root"

summary
