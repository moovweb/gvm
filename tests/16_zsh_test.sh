#!/usr/bin/env bash
# gvm under zsh.
#
# The suite runs everything in bash, and that hid a whole class of bug: install.sh
# offers to write the profile line into .zshrc, so zsh is a supported shell, but
# nothing here ever ran a single command in one. The first thing noticed when
# actually trying it was `${!1}`, a bad substitution in zsh, in the flag helper
# every command calls.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox go1.24.13 go1.27.1
trap gvm_test_sandbox_teardown EXIT

if ! command -v zsh > /dev/null 2>&1; then
	# Nothing to check, and no assertion to count, so say so and stop. This
	# branch runs on every machine without zsh and used to die with "skip_summary:
	# command not found", which failed the file it was skipping.
	printf 'zsh is not installed, so there is nothing to check\n'
	printf '0 passed, 0 failed\n'
	exit 0
fi

version="$(cat "$GVM_ROOT/VERSION")"

# In zsh <cmd...> runs the function in the current shell, which is what these
# need: `gvm use` has to change the environment it is called from.
zsh_run() {
	ZDOTDIR="$GVM_TEST_TMP/zdot" LANG=en_US.UTF-8 zsh -c "
		set -u
		export GVM_ROOT='$GVM_ROOT'
		. \"\$GVM_ROOT/scripts/gvm\"
		$1
	" 2>&1
}

t "sourcing scripts/gvm works in zsh"
out="$(zsh_run "gvm version")"
assert_contains "$out" "$version"
assert_not_contains "$out" "not found"
assert_not_contains "$out" "bad substitution"
assert_not_contains "$out" "no such file"

t "the shell functions gvm needs are all defined in zsh"
# bin/gvm dispatches to files; these are functions, so a zsh that cannot parse or
# define them fails here instead of halfway through a command. The use and pkgset
# ones are loaded on first use, so ask for them after using them.
out="$(zsh_run "builtin declare -f gvm > /dev/null || echo 'missing: gvm'")"
assert_eq "" "$out"
out="$(zsh_run "gvm use 1.24.13 > /dev/null 2>&1
gvm applymod > /dev/null 2>&1
for f in gvm_use gvm_applymod; do
	builtin declare -f \$f > /dev/null || echo \"missing: \$f\"
done")"
assert_eq "" "$out"
out="$(zsh_run "gvm pkgset use 1.24.13 > /dev/null 2>&1
builtin declare -f gvm_pkgset_use > /dev/null || echo 'missing: gvm_pkgset_use'")"
assert_eq "" "$out"

t "gvm use changes the environment of the zsh that asked"
out="$(zsh_run "gvm use 1.24.13 && go version")"
assert_contains "$out" "go1.24.13"
out="$(zsh_run "gvm use 1.24.13 > /dev/null && gvm current")"
assert_contains "$out" "go1.24.13"

t "gvm use --default is remembered by a new zsh"
zsh_run "gvm use 1.24.13 --default > /dev/null" > /dev/null
out="$(zsh_run "gvm current")"
assert_contains "$out" "go1.24.13"

t "the read-only commands work in zsh"
for cmd in "gvm ls" "gvm ls-remote --offline" "gvm which" "gvm doctor" "gvm alias list" \
	"gvm pkgset list" "gvm diff" "gvm pkgenv" "gvm completion"; do
	out="$(zsh_run "$cmd")"
	assert_not_contains "$out" "bad substitution"
	assert_not_contains "$out" "command not found"
	assert_not_contains "$out" "parse error"
done

t "the boolean flags work in zsh"
out="$(zsh_run "GVM_QUIET=0 gvm version; GVM_DEBUG=0 gvm version")"
assert_contains "$out" "$version"
assert_not_contains "$out" "bad substitution"
assert_not_contains "$out" "command not found"
out="$(zsh_run "GVM_NO_VERIFY=0 gvm version; GVM_OFFLINE=0 gvm ls-remote")"
assert_not_contains "$out" "bad substitution"

t "gvm applymod works in zsh"
mkdir -p "$GVM_TEST_TMP/zmod"
printf 'module example.com/m\n\ngo 1.24.13\n' > "$GVM_TEST_TMP/zmod/go.mod"
out="$(zsh_run "cd '$GVM_TEST_TMP/zmod' && gvm applymod && gvm current")"
assert_contains "$out" "go1.24.13"

t "the cd hook is installed and fires in zsh"
out="$(zsh_run "cd '$GVM_TEST_TMP/zmod' && gvm current")"
assert_contains "$out" "go1.24.13"

t "completion is valid zsh"
# The completion script is offered to zsh users, so zsh has to be able to parse
# it. bash -n on a zsh script proves nothing.
zsh -n "$GVM_ROOT/scripts/completion" 2>&1 | head -3
zsh -n "$GVM_ROOT/scripts/completion" > /dev/null 2>&1 && _pass ||
	_fail "completion is not valid zsh"
out="$(zsh_run "autoload -Uz compinit && compinit -u -d '$GVM_TEST_TMP/zcompdump' 2>/dev/null; . \"\$GVM_ROOT/scripts/completion\"; _gvm")"
assert_not_contains "$out" "parse error"

t "the profile line the installer writes is valid zsh"
mkdir -p "$GVM_TEST_TMP/zdot"
printf '[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"\n' > "$GVM_TEST_TMP/zdot/.zshrc"
out="$(zsh_run "gvm version")"
assert_contains "$out" "$version"

t "GVM_ROOT with a space in it works in zsh"
space="$GVM_TEST_TMP/z dir/gvm"
mkdir -p "$space"
cp -R "$GVM_ROOT/bin" "$GVM_ROOT/scripts" "$GVM_ROOT/VERSION" "$space/"
out="$(zsh_run "export GVM_ROOT='$space'; . \"\$GVM_ROOT/scripts/gvm\"; gvm version")"
assert_contains "$out" "$(cat "$space/VERSION")"

summary
