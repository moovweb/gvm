#!/usr/bin/env bash
# gvm update - updating gvm itself with git, the way `brew update` does.
#
# Everything here runs against synthetic repositories built out of the real gvm
# tree, so the code an update fetches is the code that ships, and nothing
# touches the network: the "remote" is a directory and git fetches from a path.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox go1.24.13
trap gvm_test_sandbox_teardown EXIT

# Every install.sh call below passes --no-profile. Without it the installer
# writes the gvm line into the developer's real ~/.zshrc, and lib.sh's profile
# guard is there to stop a test suite from doing that - not to be argued with
# when it catches one.
#
# git is only needed to update gvm, so an install without it is still a
# supported install - there is just nothing to say about it here.
if ! command -v git > /dev/null 2>&1; then
	echo "gvm update: skipped, git is not installed"
	summary
	exit 0
fi

export GIT_AUTHOR_NAME="gvm tests" GIT_AUTHOR_EMAIL="tests@example.invalid"
export GIT_COMMITTER_NAME="gvm tests" GIT_COMMITTER_EMAIL="tests@example.invalid"

work="$GVM_TEST_TMP/update"
seed="$work/seed"
root="$work/root"
installer="$work/downloaded/install.sh"

# A copy of the real gvm tree, as a repository's content.
copy_gvm_tree() {
	local target="$1" item
	mkdir -p "$target"
	for item in bin scripts locales VERSION LICENSE AUTHORS README.md README.zh-CN.md install.sh; do
		[ -e "$GVM_SOURCE_ROOT/$item" ] || continue
		cp -R "$GVM_SOURCE_ROOT/$item" "$target/"
	done
}

# seed_repo [version]
# A repository whose tree is a real gvm - the files the installer copies, plus
# a marker file that is not part of an install - cloned into a directory shaped
# like a GVM_ROOT, with the state directories install.sh creates.
seed_repo() {
	rm -rf "$seed" "$root"
	copy_gvm_tree "$seed"
	echo "${1:-1.1.0}" > "$seed/VERSION"
	echo "a file the installer does not copy" > "$seed/EXTRA"
	git init -q "$seed" || return 1
	git -C "$seed" add -A &&
		git -C "$seed" commit -qm "gvm ${1:-1.1.0}" || return 1
	git clone -q "$seed" "$root" || return 1
	mkdir -p "$root/gos/go1.27.0/bin" "$root/pkgsets/go1.27.0/global" \
		"$root/environments" "$root/aliases" "$root/cache" "$root/logs" \
		"$root/archive/package"
	echo "go1.27.0" > "$root/gos/go1.27.0/VERSION"
	echo "a Go tree that gvm must not touch" > "$root/gos/go1.27.0/bin/marker"
}

# advance [version] [message]
# Publishes a commit in the "remote", the way an upstream push would. The change
# is a comment: this file is sourced, so anything else would break the install
# the test is updating.
advance() {
	local version="${1:-}" message="${2:-a new commit}"
	[ -n "$version" ] && echo "$version" > "$seed/VERSION"
	printf '\n# %s\n' "$message" >> "$seed/scripts/function/tools"
	git -C "$seed" add -A && git -C "$seed" commit -qm "$message"
}

# in_root <root> <args...> - gvm with a GVM_ROOT of our choosing
in_root() {
	local target="$1"
	shift
	GVM_ROOT="$target" "$target/bin/gvm" "$@"
}

head_of() {
	git -C "$1" rev-parse --short HEAD
}

branch_of() {
	git -C "$1" symbolic-ref --short HEAD
}

exists() {
	if [ -e "$1" ]; then echo yes; else echo no; fi
}

# assert_refused <needle> <cmd...>
# The command must fail *and* say why, and it leaves the output in $out so the
# next assertion can look at it. assert_fails_with keeps its output in a local,
# which reads like it shares the caller's $out and does not.
assert_refused() {
	local needle="$1"
	shift
	capture out "$@"
	assert_ne 0 "$CAPTURE_STATUS" "expected a failure from: $*"
	assert_contains "$out" "$needle"
}

# --- the command itself -------------------------------------------------------

t "gvm update --help documents itself"
capture out gvm update --help
assert_contains "$out" "Usage: gvm update"
assert_contains "$out" "--check"
assert_contains "$out" "--repo"

t "gvm update rejects an option it does not have"
capture out gvm update --frobnicate
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "Unknown option"

# --- an install with no repository -------------------------------------------

t "an install with no git history is told how to get one, and changes nothing"
before="$(ls -A "$GVM_TEST_SANDBOX" | sort | tr '\n' ' ')"
assert_refused "not installed from git" gvm update
assert_contains "$out" "--keep-repo"
assert_not_contains "$out" "unbound variable"
assert_eq "$before" "$(ls -A "$GVM_TEST_SANDBOX" | sort | tr '\n' ' ')" "sandbox untouched"

t "a directory called git.bak that is not a repository is left where it is"
mkdir -p "$GVM_TEST_SANDBOX/git.bak"
echo "somebody else's directory" > "$GVM_TEST_SANDBOX/git.bak/notes"
assert_fails_with "no usable git.bak" gvm update
assert_eq "somebody else's directory" "$(cat "$GVM_TEST_SANDBOX/git.bak/notes")"
assert_eq "no" "$(exists "$GVM_TEST_SANDBOX/.git")" "not renamed into place"
rm -rf "$GVM_TEST_SANDBOX/git.bak"

t "gvm update fails with a message, not a shell error, with nothing selected"
run "update with nothing selected" env -u gvm_go_name gvm update

# --- a real checkout ----------------------------------------------------------

seed_repo 1.1.0 || {
	echo "could not build the test repository" >&2
	exit 1
}

t "a checkout that is up to date says so, and stays put"
version_before="$(cat "$root/VERSION")"
commit_before="$(head_of "$root")"
capture out in_root "$root" update
assert_contains "$out" "Already up to date"
assert_contains "$out" "1.1.0"
assert_eq "$commit_before" "$(head_of "$root")"
assert_eq "$version_before" "$(cat "$root/VERSION")"

t "gvm update --check reports what would happen and does nothing"
advance 1.2.0 "Add gvm update"
capture out in_root "$root" update --check
assert_eq 0 "$CAPTURE_STATUS"
assert_contains "$out" "1.1.0 -> 1.2.0"
assert_contains "$out" "Add gvm update"
assert_contains "$out" "Nothing was changed"
assert_eq "1.1.0" "$(cat "$root/VERSION")" "VERSION not changed"
assert_eq "$commit_before" "$(head_of "$root")" "HEAD not moved"

t "gvm update fast-forwards, and says what it did"
capture out in_root "$root" update
assert_eq 0 "$CAPTURE_STATUS"
assert_contains "$out" "1.1.0 -> 1.2.0"
assert_contains "$out" "gvm is now at 1.2.0"
assert_contains "$out" "gos"
assert_eq "1.2.0" "$(cat "$root/VERSION")"
assert_ne "$commit_before" "$(head_of "$root")"

t "the updated install still works"
capture out in_root "$root" version
assert_contains "$out" "Go Version Manager v1.2.0"

t "gvm update leaves the installed Go versions alone"
assert_eq "a Go tree that gvm must not touch" "$(cat "$root/gos/go1.27.0/bin/marker")"
assert_eq "go1.27.0" "$(cat "$root/gos/go1.27.0/VERSION")"

t "gvm update records where the install now stands"
assert_eq "$(head_of "$root")" "$(sed -n 's/^commit=//p' "$root/.gvm-source")"
assert_eq "yes" "$(sed -n 's/^checkout=//p' "$root/.gvm-source")"
assert_contains "$(cat "$root/.gvm-source")" "repo=$seed"
assert_contains "$(cat "$root/.gvm-source")" "version=1.2.0"

t "gvm doctor says the install can update itself"
capture out in_root "$root" doctor
assert_contains "$out" "'gvm update' is available"
assert_contains "$out" "git checkout"

t "a second update has nothing to do"
capture out in_root "$root" update
assert_contains "$out" "Already up to date"
assert_contains "$out" "1.2.0"

# --- refusing to throw work away ---------------------------------------------

t "a locally modified gvm is refused, and the edit survives"
printf '\n# a hand patch somebody needs\n' >> "$root/scripts/function/tools"
commit_before="$(head_of "$root")"
assert_refused "local changes" in_root "$root" update
assert_contains "$out" "stash"
assert_contains "$out" "scripts/function/tools"
assert_eq "$commit_before" "$(head_of "$root")" "HEAD not moved"
assert_contains "$(cat "$root/scripts/function/tools")" "a hand patch somebody needs"
git -C "$root" checkout -- scripts/function/tools

t "an untracked file in the install is not a local change, and survives"
echo "stray" > "$root/scripts/stray-file"
advance 1.2.1 "Another release"
capture out in_root "$root" update
assert_eq 0 "$CAPTURE_STATUS" "an untracked file does not block an update"
assert_eq "stray" "$(cat "$root/scripts/stray-file")"
rm -f "$root/scripts/stray-file"

t "local commits are refused rather than overwritten"
advance 1.3.0 "Upstream work"
printf '\n# local work\n' >> "$root/scripts/function/tools"
git -C "$root" add -A && git -C "$root" commit -qm "local work" > /dev/null
commit_before="$(head_of "$root")"
assert_refused "ahead of" in_root "$root" update
assert_contains "$out" "--repo"
assert_eq "$commit_before" "$(head_of "$root")" "HEAD not moved"
git -C "$root" reset -q --hard "origin/$(branch_of "$root")"

t "a detached HEAD is refused with the command that fixes it"
branch_before="$(branch_of "$root")"
git -C "$root" checkout -q --detach HEAD
assert_refused "detached" in_root "$root" update
assert_contains "$out" "git -C"
assert_contains "$out" "checkout <branch>"
git -C "$root" checkout -q "$branch_before"

t "a merge somebody interrupted is not fast-forwarded over"
git -C "$root" rev-parse HEAD > "$root/.git/MERGE_HEAD"
assert_fails_with "middle of" in_root "$root" update
rm -f "$root/.git/MERGE_HEAD"

t "a rebase somebody interrupted is not fast-forwarded over"
mkdir -p "$root/.git/rebase-merge"
assert_fails_with "rebase" in_root "$root" update
rmdir "$root/.git/rebase-merge"

t "another git holding the index lock is not ignored"
: > "$root/.git/index.lock"
assert_fails_with "index lock" in_root "$root" update
rm -f "$root/.git/index.lock"

t "a repository that cannot be reached says so"
assert_fails_with "Could not fetch" in_root "$root" update --repo "$work/nosuchrepo"

# --- the git.bak shape the one-line installer leaves behind -------------------

t "the one-line installer clones and keeps the history as git.bak"
keep_root="$work/keep"
clone_root="$work/cloned"
rm -rf "$keep_root" "$clone_root" "$work/downloaded"
copy_gvm_tree "$keep_root"
echo "1.1.0" > "$keep_root/VERSION"
git init -q "$keep_root"
git -C "$keep_root" add -A && git -C "$keep_root" commit -qm "gvm 1.1.0" > /dev/null
# `bash <(curl .../gvm-installer)` hands install.sh a directory with no gvm in
# it, which is the only way the installer takes its clone path. Running the
# installer's own copy from the source tree instead would install that tree.
mkdir -p "$work/downloaded"
cp "$GVM_SOURCE_ROOT/install.sh" "$installer"
GVM_REPO="$keep_root" bash "$installer" --prefix "$clone_root" --no-profile > /dev/null 2>&1
assert_eq "no" "$(exists "$clone_root/.git")" "no live .git"
assert_eq "yes" "$(exists "$clone_root/git.bak")" "the history is kept as git.bak"
assert_eq "no" "$(sed -n 's/^checkout=//p' "$clone_root/.gvm-source" 2> /dev/null)" "recorded as not a checkout"
assert_contains "$(cat "$clone_root/.gvm-source" 2> /dev/null)" "repo=$keep_root"

t "an install whose files outrun its history is told to reinstall, not to update"
# The shape an upgrade actually takes on a machine installed by the one-liner:
# install.sh copied this version's files over a directory still holding the
# history of an older clone, so the tree can never fast-forward. Offering
# 'git checkout -- .' here as the fix would put the old code back.
stale="$work/stale"
stale_src="$work/stale-src"
rm -rf "$stale" "$stale_src"
copy_gvm_tree "$stale_src"
echo "1.1.0" > "$stale_src/VERSION"
git init -q "$stale_src"
git -C "$stale_src" add -A && git -C "$stale_src" commit -qm "gvm 1.1.0" > /dev/null
GVM_REPO="$stale_src" bash "$installer" --prefix "$stale" --no-profile > /dev/null 2>&1
# The upgrade somebody performs: the current tree copied over that install.
# Run it out of a repository of the test's own, because whether the tree gvm is
# developed in happens to be a git checkout is not something this test should
# depend on - and it decides whether a commit gets recorded at all.
reinstall_src="$work/reinstall-src"
rm -rf "$reinstall_src"
copy_gvm_tree "$reinstall_src"
git init -q "$reinstall_src"
git -C "$reinstall_src" add -A
git -C "$reinstall_src" commit -qm "gvm $(cat "$GVM_SOURCE_ROOT/VERSION")" > /dev/null
reinstalled_at="$(git -C "$reinstall_src" rev-parse --short HEAD)"
"$reinstall_src/install.sh" --prefix "$stale" --no-profile --no-clone --force > /dev/null 2>&1
assert_eq "yes" "$(exists "$stale/git.bak")" "the old history is still set aside"
assert_eq "$(cat "$GVM_SOURCE_ROOT/VERSION")" "$(cat "$stale/VERSION")" "the files are the new ones"
# A commit was recorded by the reinstall, so the remedy can name it.
assert_eq "$reinstalled_at" "$(sed -n 's/^commit=//p' "$stale/.gvm-source")" "the reinstall recorded its commit"
assert_refused "local changes" in_root "$stale" update
assert_contains "$out" "not update anything" "the checkout -- . trap is called out"
assert_contains "$out" "reset --hard" "pointed at the recorded commit"
assert_contains "$out" "gvm doctor prints it"
assert_eq "1.1.0" "$(cat "$stale_src/VERSION")" "nothing was written to the repository"

# Without a recorded commit there is nothing to reset to, so the only advice
# that works is reinstalling.
rm -f "$stale/.gvm-source"
assert_refused "local changes" in_root "$stale" update
assert_contains "$out" "install.sh --keep-repo" "pointed at a reinstall"
assert_not_contains "$out" "reset --hard" "nothing to reset to is not offered"

t "gvm update puts a git.bak install back under git and updates it"
# A new commit in the repository the clone came from.
printf '\n# a new commit\n' >> "$keep_root/scripts/function/tools"
echo "1.2.0" > "$keep_root/VERSION"
git -C "$keep_root" add -A && git -C "$keep_root" commit -qm "Add gvm update" > /dev/null

capture out in_root "$clone_root" update --check
assert_contains "$out" "git.bak"
assert_eq "no" "$(exists "$clone_root/.git")" "--check restored nothing"

capture out in_root "$clone_root" update
assert_eq 0 "$CAPTURE_STATUS"
assert_contains "$out" "Restoring the git history"
assert_contains "$out" "1.1.0 -> 1.2.0"
assert_eq "yes" "$(exists "$clone_root/.git")" ".git is back"
assert_eq "no" "$(exists "$clone_root/git.bak")" "git.bak is gone"
assert_eq "1.2.0" "$(cat "$clone_root/VERSION")"
assert_contains "$(cat "$clone_root/.gvm-source")" "checkout=yes"
capture out in_root "$clone_root" version
assert_contains "$out" "Go Version Manager v1.2.0"

# --- fetching from somewhere else --------------------------------------------

t "--repo fetches from another repository without touching the remotes"
seed_repo 1.1.0 || exit 1
advance 1.4.0 "Upstream release"
remotes_before="$(git -C "$root" remote -v | tr '\n' ' ')"
capture out in_root "$root" update --repo "$seed"
assert_eq 0 "$CAPTURE_STATUS"
assert_contains "$out" "1.1.0 -> 1.4.0"
assert_eq "$remotes_before" "$(git -C "$root" remote -v | tr '\n' ' ')" "remotes unchanged"
assert_eq "1.4.0" "$(cat "$root/VERSION")"

t "--ref fetches that branch, and leaves the checkout on the branch it had"
branch_before="$(branch_of "$root")"
git -C "$seed" checkout -q -b release
advance 2.0.0 "A release branch"
git -C "$seed" checkout -q "$branch_before"
capture out in_root "$root" update --repo "$seed" --ref release
assert_eq 0 "$CAPTURE_STATUS"
assert_contains "$out" "1.4.0 -> 2.0.0"
assert_eq "2.0.0" "$(cat "$root/VERSION")"
assert_eq "$branch_before" "$(branch_of "$root")" "still on the same branch"
git -C "$seed" branch -q -D release
# Back to the branch's own tip, so the tests below are not looking at a checkout
# that has walked off the end of its history.
git -C "$root" reset -q --hard "$(git -C "$seed" rev-parse "$branch_before")"

t "a checkout with no upstream falls back to the recorded repository"
git -C "$root" branch --unset-upstream 2> /dev/null
advance 1.5.0 "Another release"
capture out in_root "$root" update
assert_eq 0 "$CAPTURE_STATUS"
assert_contains "$out" "1.4.0 -> 1.5.0"
assert_eq "1.5.0" "$(cat "$root/VERSION")"

t "no upstream and no recorded repository is a clear error"
git -C "$root" branch --unset-upstream 2> /dev/null
rm -f "$root/.gvm-source"
assert_refused "no upstream" in_root "$root" update
assert_contains "$out" "--repo"

# --- what the installer and the reader agree on -------------------------------

t "install.sh and gvm_source write the same keys"
installer_keys="$(grep -o "printf '[a-z_]*=%s" "$GVM_SOURCE_ROOT/install.sh" | sed "s/printf '//" | sort | tr '\n' ' ')"
reader_keys="$(grep -o "printf '[a-z_]*=%s" "$GVM_SOURCE_ROOT/scripts/function/gvm_source" | sed "s/printf '//" | sort | tr '\n' ' ')"
assert_ne "" "$reader_keys"
assert_eq "$reader_keys" "$installer_keys"

t "gvm update watches the same files the installer copies"
# gvm update has to know which files gvm owns, to tell "you edited gvm" from
# "the installer never copied tests/ into this GVM_ROOT". If its list drifts
# from install.sh's, a real local edit goes unnoticed, or a path gvm never
# wrote is treated as its own and blocks every future update.
installer_items="$(sed -n 's/^installed_items="\(.*\)"$/\1/p' "$GVM_SOURCE_ROOT/install.sh" | tr ' ' '\n' | sort | tr '\n' ' ')"
update_items="$(sed -n 's/^installed_paths="\(.*\)"$/\1/p' "$GVM_SOURCE_ROOT/scripts/update" | tr ' ' '\n' | sort | tr '\n' ' ')"
assert_ne "" "$installer_items"
assert_eq "$installer_items" "$update_items"

t "an install from a checkout records where it came from"
install_root="$work/installed"
"$GVM_SOURCE_ROOT/install.sh" --prefix "$install_root" --no-profile --no-clone > /dev/null 2>&1
assert_eq "no" "$(sed -n 's/^checkout=//p' "$install_root/.gvm-source" 2> /dev/null)"
assert_contains "$(cat "$install_root/.gvm-source" 2> /dev/null)" "version=$(cat "$GVM_SOURCE_ROOT/VERSION")"

t "a --keep-repo install is still a checkout after a plain reinstall"
keep2="$work/kept"
keep2src="$work/kept-src"
rm -rf "$keep2" "$keep2src"
# Cloned, so the checkout has an origin the way a real one does: a repository
# with no remote at all cannot be updated by anything, gvm included.
copy_gvm_tree "$keep2src"
echo "9.9.9" > "$keep2src/VERSION"
git init -q "$keep2src"
git -C "$keep2src" add -A && git -C "$keep2src" commit -qm "gvm" > /dev/null
git clone -q "$keep2src" "$keep2"
(cd "$keep2" && ./install.sh --prefix "$keep2" --no-clone --keep-repo --no-profile --force > /dev/null 2>&1)
assert_eq "yes" "$(sed -n 's/^checkout=//p' "$keep2/.gvm-source" 2> /dev/null)" "recorded as a checkout"
# A reinstall without --keep-repo must not quietly take that away: that .git is
# the difference between `gvm update` working and not working.
(cd "$keep2" && ./install.sh --prefix "$keep2" --no-clone --force --no-profile > /dev/null 2>&1)
assert_eq "yes" "$(exists "$keep2/.git")" ".git survived the reinstall"
assert_eq "yes" "$(sed -n 's/^checkout=//p' "$keep2/.gvm-source" 2> /dev/null)" "still a checkout"
assert_contains "$(in_root "$keep2" update 2>&1)" "Already up to date"

# The same local edit in an install that *is* a checkout: refused for the same
# reason, but not told to reinstall - it already matches its history.
printf '\n# a hand patch\n' >> "$keep2/scripts/function/tools"
capture out in_root "$keep2" update
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "scripts/function/tools"
assert_not_contains "$out" "--keep-repo" "not told to reinstall what is already right"
git -C "$keep2" checkout -- scripts/function/tools

# --- the shell warning --------------------------------------------------------

t "a recorded checkout is not warned about as a mistake"
# A clean, recorded state to be warned in: the tests above have moved this one
# around - it has no upstream and no provenance file left - and the warning is
# about how an install was recorded.
seed_repo 1.2.0 || exit 1
advance 1.3.0 "A release"
capture out in_root "$root" update
assert_contains "$out" "1.2.0 -> 1.3.0"
warned="$(GVM_ROOT="$root" bash -c '. "$1/scripts/functions"; . "$1/scripts/env/gvm"; gvm ls' _ "$root" 2>&1)"
assert_contains "$warned" "is a git checkout"
assert_not_contains "$warned" "Reinstall with install.sh to fix this"

t "an unrecorded .git is still warned about as a mistake"
rm -f "$root/.gvm-source"
warned="$(GVM_ROOT="$root" bash -c '. "$1/scripts/functions"; . "$1/scripts/env/gvm"; gvm ls' _ "$root" 2>&1)"
assert_contains "$warned" "is a git work tree"
assert_contains "$warned" "Reinstall with install.sh to fix this"

summary
