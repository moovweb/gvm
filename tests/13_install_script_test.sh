#!/usr/bin/env bash
# install.sh, and the profile hook it writes. No network, no make.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox
trap gvm_test_sandbox_teardown EXIT

repo="$GVM_SOURCE_ROOT"
fake_home="$GVM_TEST_TMP/home"
prefix="$fake_home/gvm"
mkdir -p "$fake_home"
printf 'export PATH="$PATH"\n' > "$fake_home/.bashrc"

install() {
	env HOME="$fake_home" PATH="/usr/bin:/bin" GVM_NO_GIT_BAK=1 \
		bash "$repo/install.sh" "$@" 2>&1
}

t "install.sh --help explains itself"
out="$(bash "$repo/install.sh" --help)"
for flag in --prefix --profile --no-profile --force --uninstall --no-clone; do
	assert_contains "$out" "$flag"
done

t "an unknown option is rejected"
out="$(bash "$repo/install.sh" --bogus 2>&1)"
assert_ne 0 "$?"
assert_contains "$out" "Unknown option"

t "install.sh installs into --prefix"
out="$(install --no-clone --prefix "$prefix")"
assert_contains "$out" "installed at $prefix"
for path in bin/gvm scripts/functions scripts/gvm locales VERSION LICENSE; do
	[ -e "$prefix/$path" ] || _fail "missing $path" || continue
	_pass
done

t "the installed tree has the runtime directories"
for dir in gos environments aliases pkgsets cache logs archive/package; do
	[ -d "$prefix/$dir" ] || _fail "missing $dir" || continue
	_pass
done

t "the installed commands are executable"
# `use` and `implode` are shell functions, not scripts, because they have to
# change the calling shell or work when the rest of gvm is broken.
[ -x "$prefix/bin/gvm" ] || _fail "bin/gvm is not executable"
for command in install ls ls-remote alias uninstall doctor diff help version; do
	[ -x "$prefix/scripts/$command" ] || _fail "scripts/$command is not executable" || continue
	_pass
done

t "the shell functions are installed as sources"
for source_file in env/gvm env/use env/implode env/cd gvm gvm-default; do
	[ -f "$prefix/scripts/$source_file" ] || _fail "scripts/$source_file is missing" || continue
	_pass
done

t "no stray files from the checkout are installed"
# The old `make install` did `cp -rf .`, which brought .git, tests and whatever
# else happened to be in the working tree along with it.
for stray in .git tests .travis.yml configure.ac Makefile.am autogen.sh Rakefile; do
	[ -e "$prefix/$stray" ] && _fail "$stray was installed" || _pass
done

t "install.sh adds one line to the profile"
assert_eq 1 "$(grep -c 'scripts/gvm' "$fake_home/.bashrc")"
assert_contains "$(cat "$fake_home/.bashrc")" 'source "'"$prefix"'/scripts/gvm"'

t "installing twice does not add the line twice"
out="$(install --no-clone --force --prefix "$prefix")"
assert_eq 1 "$(grep -c 'scripts/gvm' "$fake_home/.bashrc")"

t "installing over an existing gvm needs --force"
out="$(install --no-clone --prefix "$prefix")"
assert_contains "$out" "already installed"

t "install.sh refuses to write over somebody else's directory"
mkdir -p "$fake_home/notgvm" && echo keep > "$fake_home/notgvm/important.txt"
out="$(install --no-clone --prefix "$fake_home/notgvm")"
assert_contains "$out" "not empty"
assert_eq "keep" "$(cat "$fake_home/notgvm/important.txt")"

t "install.sh reaches the login-shell profile too"
printf '# login\n' > "$fake_home/.profile"
out="$(install --no-clone --force --prefix "$prefix")"
assert_contains "$out" "added gvm to $fake_home/.profile"

t "a profile that already sources .bashrc is left alone"
rm "$fake_home/.profile"
printf 'if [ -f "$HOME/.bashrc" ]; then . "$HOME/.bashrc"; fi\n' > "$fake_home/.profile"
out="$(install --no-clone --force --prefix "$prefix")"
assert_not_contains "$out" "added gvm to $fake_home/.profile"
assert_eq "0" "$(grep -c 'scripts/gvm' "$fake_home/.profile" 2> /dev/null; true)"

t "--no-profile leaves the profile alone"
rm -f "$fake_home/.bashrc" "$fake_home/.profile"
out="$(install --no-clone --force --prefix "$prefix" --no-profile)"
[ -e "$fake_home/.bashrc" ] && _fail "--no-profile created a profile" || _pass
assert_contains "$out" "installed at"

# --- the profile hook itself -------------------------------------------------

t "scripts/gvm finds GVM_ROOT from its own location"
# The installed scripts/gvm used to be a generated file with the path baked in,
# so moving the directory broke every shell.
out="$(env -i HOME="$fake_home" PATH=/usr/bin:/bin bash -c '
	source "'"$prefix"'/scripts/gvm"
	echo "GVM_ROOT=$GVM_ROOT"')"
assert_contains "$out" "GVM_ROOT=$prefix"

t "scripts/gvm works even when GVM_ROOT is set to something stale"
out="$(env -i HOME="$fake_home" GVM_ROOT=/nonexistent/path PATH=/usr/bin:/bin bash -c '
	source "'"$prefix"'/scripts/gvm"
	echo "GVM_ROOT=$GVM_ROOT"')"
assert_contains "$out" "GVM_ROOT=$prefix"

t "sourcing the hook twice is a no-op"
out="$(env -i HOME="$fake_home" PATH=/usr/bin:/bin bash -c '
	source "'"$prefix"'/scripts/gvm"
	before="$PATH"
	source "'"$prefix"'/scripts/gvm"
	[ "$before" = "$PATH" ] && echo "PATH unchanged"')"
assert_contains "$out" "PATH unchanged"

t "the hooked gvm runs"
out="$(env -i HOME="$fake_home" PATH=/usr/bin:/bin bash -c '
	source "'"$prefix"'/scripts/gvm"
	gvm version' 2>&1)"
assert_contains "$out" "Go Version Manager"

t "a moved installation still works"
moved="$fake_home/gvm-moved"
mv "$prefix" "$moved"
out="$(env -i HOME="$fake_home" PATH=/usr/bin:/bin bash -c '
	source "'"$moved"'/scripts/gvm"
	gvm version' 2>&1)"
assert_contains "$out" "Go Version Manager"
mv "$moved" "$prefix"

t "scripts/gvm complains clearly when it is not in an install"
out="$(env -i HOME="$fake_home" PATH=/usr/bin:/bin bash -c '
	source "'"$GVM_TEST_TMP"'/nothing-here/scripts/gvm"' 2>&1)"
assert_contains "$out" "No such file"

# --- uninstall ---------------------------------------------------------------

t "uninstall needs --force"
out="$(install --prefix "$prefix" --uninstall)"
assert_contains "$out" "Pass --force"
[ -d "$prefix" ] && _pass || _fail "the install was removed without --force"

t "uninstall removes gvm and cleans the profiles"
# Reinstall first: an earlier test emptied the profile directory, and a
# profile with no gvm line in it produces no backup to assert on.
# An earlier test removed the profiles to check --no-profile, and the installer
# only updates a profile that already exists; it does not create one.
printf 'export PATH="$PATH"\n' > "$fake_home/.bashrc"
out="$(install --no-clone --force --prefix "$prefix")"
assert_contains "$out" "added gvm to $fake_home/.bashrc"
mkdir -p "$prefix/gos/go1.24.13"
out="$(install --prefix "$prefix" --uninstall --force)"
assert_contains "$out" "keeping gos/"
[ -d "$prefix/scripts" ] && _fail "scripts/ survived" || _pass
[ -d "$prefix/gos/go1.24.13" ] && _pass || _fail "gos/ was removed"
assert_eq "0" "$(grep -c 'scripts/gvm' "$fake_home/.bashrc" 2> /dev/null; true)"
assert_eq 1 "$(ls "$fake_home"/.bashrc.gvm-backup 2> /dev/null | wc -l | tr -d ' ')"

t "uninstall refuses a directory that is not a gvm root"
out="$(install --prefix "$fake_home/notgvm" --uninstall --force)"
assert_contains "$out" "does not look like a gvm"
assert_eq "keep" "$(cat "$fake_home/notgvm/important.txt")"

t "uninstall on nothing at all is an error, not a crash"
out="$(install --prefix "$fake_home/never-existed" --uninstall --force)"
assert_contains "$out" "Nothing installed"

# --- the remote installer ---------------------------------------------------

t "gvm-installer --help does not need the network"
out="$(bash "$repo/binscripts/gvm-installer" --help)"
assert_contains "$out" "install.sh"
assert_contains "$out" "--prefix"

t "gvm-installer is valid bash"
bash -n "$repo/binscripts/gvm-installer" && _pass || _fail "syntax error"

t "gvm-installer no longer overwrites scripts/gvm"
# It used to write two generated lines into the installed scripts/gvm, replacing
# the file the project ships.
grep -q '> *"\$.*scripts/gvm"' "$repo/binscripts/gvm-installer" &&
	_fail "the installer still writes scripts/gvm" || _pass

t "make lint passes"
(cd "$repo" && make lint > /dev/null 2>&1) && _pass || _fail "make lint failed"

t "make test is wired to tests/run.sh"
grep -q 'tests/run.sh' "$repo/Makefile" && _pass || _fail "the Makefile does not run the suite"

# --- installing from a checkout ---------------------------------------------

t "running install.sh from a checkout installs that checkout, not upstream"
# It used to git clone anyway and copy the local files on top, so the result was
# a mixture: upstream's dead autotools files reappeared in an install that had
# just deleted them.
checkout="$GVM_TEST_TMP/checkout"
mkdir -p "$checkout"
cp -R "$repo/bin" "$repo/scripts" "$repo/locales" "$repo/VERSION" "$checkout/"
for extra in install.sh README.md README.zh-CN.md; do
	cp "$repo/$extra" "$checkout/$extra"
done
out="$(env HOME="$fake_home" PATH="/usr/bin:/bin" bash "$checkout/install.sh" \
	--prefix "$fake_home/from-checkout" --no-profile)"
assert_contains "$out" "Installing from this checkout"
assert_not_contains "$out" "Cloning"
for legacy in configure.ac Makefile.am autogen.sh Rakefile Gemfile config extra git.bak .git; do
	[ -e "$fake_home/from-checkout/$legacy" ] &&
		_fail "$legacy leaked in from upstream" || _pass
done
[ -f "$fake_home/from-checkout/scripts/gvm" ] && _pass || _fail "scripts/gvm missing"
[ -f "$fake_home/from-checkout/README.zh-CN.md" ] && _pass || _fail "the Chinese README is not installed"

t "installing a checkout over itself does not delete it"
# --no-clone out of $prefix used to rm the file and then copy it from itself.
self="$GVM_TEST_TMP/self"
mkdir -p "$self" && cp -R "$repo/bin" "$repo/scripts" "$repo/locales" "$repo/VERSION" "$self/"
cp "$repo/install.sh" "$self/install.sh"
before="$(ls "$self/scripts" | wc -l | tr -d ' ')"
out="$(env HOME="$fake_home" PATH="/usr/bin:/bin" bash "$self/install.sh" \
	--prefix "$self" --no-clone --force --no-profile)"
assert_contains "$out" "in place"
assert_eq "$before" "$(ls "$self/scripts" | wc -l | tr -d ' ')"
[ -f "$self/scripts/gvm" ] && _pass || _fail "scripts/gvm was deleted by the self-install"
[ -d "$self/bin" ] && _pass || _fail "bin was deleted by the self-install"

t "an old gvm line in the profile is replaced, not duplicated"
# The old gvm quoted the line differently. Replacing it must not append a second
# one, and must not touch anything else in the file - an earlier version
# "restored" a *.gvm-backup over the file, which silently reverted edits.
printf '# my bashrc\nexport FOO=1\nsource "$HOME/.gvm/scripts/gvm"\nexport BAR=2\n' \
	> "$fake_home/.bashrc"
out="$(install --prefix "$prefix" --force)"
assert_contains "$out" "replaced the gvm line"
assert_eq "1" "$(grep -c 'scripts/gvm' "$fake_home/.bashrc")"
assert_contains "$(cat "$fake_home/.bashrc")" "export BAR=2"

t "a profile that already has our line is left alone"
before="$(cat "$fake_home/.bashrc")"
out="$(install --prefix "$prefix" --force)"
assert_contains "$out" "already loads gvm"
assert_eq "$before" "$(cat "$fake_home/.bashrc")"

t "--no-profile keeps an uninstall away from the profile too"
# The uninstall path looped over ~/.bashrc, ~/.zshrc, ~/.profile and
# ~/.bash_profile without looking at --no-profile. That is how this suite ended
# up rewriting the developer's ~/.bashrc and leaving a .gvm-backup in their home
# directory: an uninstall E2E run with --no-profile, which by its own
# documentation should not have touched anything.
printf '# my bashrc\nexport FOO=1\n' > "$fake_home/.bashrc"
printf '# my zshrc\n' > "$fake_home/.zshrc"
printf '# my profile\n' > "$fake_home/.profile"
out="$(install --prefix "$prefix" --force)"
assert_contains "$out" "added gvm to $fake_home/.zshrc"

bashrc_before="$(cat "$fake_home/.bashrc")"
profile_before="$(cat "$fake_home/.profile")"
out="$(install --prefix "$prefix" --uninstall --no-profile --force)"
assert_contains "$out" "Removed gvm from $prefix"
# The line the install added is still there: --no-profile means the uninstall
# does not go looking for it.
assert_contains "$(cat "$fake_home/.zshrc")" "scripts/gvm"
# And the files the install never touched are byte for byte what they were.
assert_eq "$bashrc_before" "$(cat "$fake_home/.bashrc")"
assert_eq "$profile_before" "$(cat "$fake_home/.profile")"
[ -e "$fake_home/.zshrc.gvm-backup" ] && _fail "a backup was left behind" || _pass

t "an uninstall without --no-profile does remove the line"
out="$(install --prefix "$prefix" --force)"
out="$(install --prefix "$prefix" --uninstall --force)"
assert_not_contains "$(cat "$fake_home/.zshrc")" "scripts/gvm"
assert_contains "$(cat "$fake_home/.bashrc")" "export FOO=1"

t "install.sh and uninstall.sh never touch the real HOME"
# Belt and braces: the fake HOME above covers the logic, this covers the
# possibility of a test invoking the script without one.
stray="$GVM_TEST_TMP/never-created"
before="$(ls -A "$HOME" 2> /dev/null)"
out="$(env PATH="/usr/bin:/bin" bash "$repo/install.sh" --prefix "$stray" --no-profile 2>&1)"
out="$out$(env PATH="/usr/bin:/bin" bash "$repo/install.sh" --prefix "$stray" --uninstall --no-profile --force 2>&1)"
after="$(ls -A "$HOME" 2> /dev/null)"
rm -rf "$stray"
assert_eq "$before" "$after"
assert_contains "$out" "Removed gvm from $stray"

t "a Go inside the gvm root is not recorded as the system Go"
# Installing over an existing gvm, the inherited PATH points into gos/, so
# `go env GOROOT` is one of our own versions. Recording it as "system" would
# make `gvm use system` and `gvm uninstall` disagree about who owns it.
inside="$GVM_TEST_TMP/inside"
mkdir -p "$inside/scripts" "$inside/gos/go1.24.13/bin"
printf '1.1.0\n' > "$inside/VERSION"
printf '#!/bin/sh\n' > "$inside/scripts/gvm"
cat > "$inside/gos/go1.24.13/bin/go" <<'GOEOF'
#!/bin/sh
[ "$1 $2" = "env GOROOT" ] && echo "$FAKE_GOROOT"
exit 0
GOEOF
chmod +x "$inside/gos/go1.24.13/bin/go"
out="$(env HOME="$fake_home" PATH="$inside/gos/go1.24.13/bin:/usr/bin:/bin" \
	FAKE_GOROOT="$inside/gos/go1.24.13" bash "$repo/install.sh" \
	--prefix "$inside" --force 2>&1)"
assert_not_contains "$out" "recorded the system Go"
[ -e "$inside/environments/system" ] && _fail "our own Go was recorded as system" || _pass

t "a Go belonging to another gvm is not recorded as the system Go"
# The shell that runs the installer usually already has a gvm active, and
# installing a second copy somewhere else must not adopt that gvm's Go as
# "system" either.
other_root="$GVM_TEST_TMP/other-gvm"
mkdir -p "$other_root/gos/go1.24.13/bin"
cat > "$other_root/gos/go1.24.13/bin/go" <<'GOEOF'
#!/bin/sh
[ "$1 $2" = "env GOROOT" ] && echo "$FAKE_GOROOT"
exit 0
GOEOF
chmod +x "$other_root/gos/go1.24.13/bin/go"
elsewhere="$GVM_TEST_TMP/elsewhere"
out="$(env HOME="$fake_home" PATH="$other_root/gos/go1.24.13/bin:/usr/bin:/bin" \
	GVM_ROOT="$other_root" FAKE_GOROOT="$other_root/gos/go1.24.13" \
	bash "$repo/install.sh" --prefix "$elsewhere" 2>&1)"
assert_not_contains "$out" "recorded the system Go"
[ -e "$elsewhere/environments/system" ] && _fail "another gvm's Go was recorded as system" || _pass

t "a Go outside any gvm root is recorded as the system Go"
outside="$GVM_TEST_TMP/outside-go"
mkdir -p "$outside/bin"
cat > "$outside/bin/go" <<'GOEOF'
#!/bin/sh
[ "$1 $2" = "env GOROOT" ] && echo "$FAKE_GOROOT"
exit 0
GOEOF
chmod +x "$outside/bin/go"
fresh="$GVM_TEST_TMP/fresh"
out="$(env HOME="$fake_home" PATH="$outside/bin:/usr/bin:/bin" \
	FAKE_GOROOT="$outside" bash "$repo/install.sh" --prefix "$fresh" 2>&1)"
assert_contains "$out" "recorded the system Go at $outside"
assert_contains "$(cat "$fresh/environments/system")" "GOROOT=\"$outside\""

t "the autotools build files are gone"
for legacy in configure.ac Makefile.am autogen.sh Rakefile Gemfile config/sources scripts/gvm.in; do
	[ -e "$repo/$legacy" ] && _fail "$legacy still exists" || _pass
done

summary
