#!/usr/bin/env bash
#
# install.sh - install gvm, or check out this repository, without autotools.
#
# The old installation story was two half-working ones:
#
#   * `make install` copied the entire working tree, .git included, into
#     $prefix/gvm, so a local scratch file or an accidental `git status` diff
#     came along for the ride; and
#   * binscripts/gvm-installer cloned the repository into place and then
#     *overwrote* scripts/gvm with two generated lines, so the file a user
#     sourced was not the file the project ships.
#
# This installs an explicit list of files, keeps the repository in place when
# asked to, and never touches anything it did not create.

set -u


usage() {
	cat <<EOF
Usage: install.sh [options]

Installs gvm into a directory, and optionally adds one line to your shell
profile.

Options:
  --prefix <dir>    Where to install. Default: \$HOME/.gvm
  --profile <file>  Profile to update. Default: whichever of .bashrc, .bash_profile,
                    .profile and .zshrc exists, and .zshrc on macOS
  --no-profile      Do not touch any profile file
  --force           Install over an existing gvm, keeping installed Go versions
  --no-clone        Do not run 'git clone'; install from this directory as it is
  --keep-repo       Leave .git in place instead of renaming it to git.bak
  --uninstall       Remove an installed gvm, keeping \$GVM_ROOT/gos
  -h, --help        Show this message

Environment:
  GVM_NO_UPDATE_PROFILE=1   Same as --no-profile
  GVM_NO_GIT_BAK=1          Same as --keep-repo
EOF
}

display_error() {
	printf 'ERROR: %s\n' "$1" >&2
}

# gvm_version_string
# Prints the version being installed. A copy of install.sh downloaded on its
# own has no VERSION file beside it, so this is best-effort.
gvm_version_string() {
	local version=""
	if [ -n "${source_root:-}" ] && [ -f "$source_root/VERSION" ]; then
		version="$(tr -d '\n\r' < "$source_root/VERSION" 2> /dev/null)"
	fi
	printf '%s' "${version:-unknown}"
}

display_message() {
	printf '%s\n' "$1"
}

prefix="${HOME}/.gvm"
profile=""
update_profile=1
force=""
do_uninstall=""
no_clone=""
keep_repo=""
cloned=""
# Set only when this run is the one that fetches. Referenced later to record
# where the install came from, and `set -u` is on.
repo=""

while [ $# -gt 0 ]; do
	case "$1" in
		--prefix)
			[ $# -ge 2 ] || {
				display_error "--prefix needs a directory"
				exit 64
			}
			prefix="$2"
			shift
			;;
		--prefix=*) prefix="${1#--prefix=}" ;;
		--profile)
			[ $# -ge 2 ] || {
				display_error "--profile needs a file"
				exit 64
			}
			profile="$2"
			shift
			;;
		--profile=*) profile="${1#--profile=}" ;;
		--no-profile) update_profile="" ;;
		--force) force=1 ;;
		--no-clone) no_clone=1 ;;
		--keep-repo) keep_repo=1 ;;
		--uninstall) do_uninstall=1 ;;
		-h | --help)
			usage
			exit 0
			;;
		*) display_error "Unknown option: $1"; usage >&2; exit 64 ;;
	esac
	shift
done

[ -n "${GVM_NO_UPDATE_PROFILE:-}" ] && update_profile=""
[ -n "${GVM_NO_GIT_BAK:-}" ] && keep_repo=1

source_root="$(cd "$(dirname "$0")" > /dev/null 2>&1 && pwd -P)" || {
	display_error "Could not work out the directory this script is in."
	exit 1
}

# The profile line. It contains "scripts/gvm" because that is also what
# `gvm implode` greps for when it takes the line back out again.
profile_line() {
	printf '[[ -s "%s/scripts/gvm" ]] && source "%s/scripts/gvm"' "$prefix" "$prefix"
}

# find_profile
# Picks the first profile that exists, preferring the one for the shell that
# is actually going to read it. Guessing wrong means the user has to add the
# line by hand, so say which file was chosen.
find_profile() {
	if [ -n "$profile" ]; then
		printf '%s\n' "$profile"
		return 0
	fi

	if [ -n "${ZDOTDIR:-}" ] && [ -f "$ZDOTDIR/.zshrc" ]; then
		printf '%s\n' "$ZDOTDIR/.zshrc"
		return 0
	fi
	if [ -f "$HOME/.zshrc" ]; then
		printf '%s\n' "$HOME/.zshrc"
		return 0
	fi
	if [ -f "$HOME/.bashrc" ]; then
		printf '%s\n' "$HOME/.bashrc"
		# A login shell reads .profile or .bash_profile, not .bashrc, so the
		# line has to go there as well - unless that file already sources
		# .bashrc, in which case it is read anyway. Sourcing scripts/gvm twice
		# is harmless: it is a no-op the second time.
		local login
		for login in "$HOME/.bash_profile" "$HOME/.profile"; do
			[ -f "$login" ] || continue
			grep -q 'bashrc' "$login" 2> /dev/null && continue
			printf '%s\n' "$login"
		done
		return 0
	fi
	if [ -f "$HOME/.bash_profile" ]; then
		printf '%s\n' "$HOME/.bash_profile"
		return 0
	fi
	if [ -f "$HOME/.profile" ]; then
		printf '%s\n' "$HOME/.profile"
		return 0
	fi
	return 1
}

# update_profile_file <file>
# Idempotent: adding gvm twice would only slow every shell down.
update_profile_file() {
	local rcfile="$1" line tmp
	line="$(profile_line)"

	if [ -f "$rcfile.gvm-backup" ]; then
		display_message "  note: $rcfile.gvm-backup is left over from an older gvm"
		display_message "    uninstall and is not used any more; safe to delete it"
	fi

	if grep -q 'scripts/gvm' "$rcfile" 2> /dev/null; then
		# Our own line is already there, so there is nothing to do. Matching it
		# exactly (rather than looking for the substring "scripts/gvm") keeps
		# this from rewriting the same file on every install.
		if grep -qxF "$line" "$rcfile" 2> /dev/null; then
			display_message "  $rcfile already loads gvm; leaving it alone"
			return 0
		fi

		# Some other gvm wrote it, with different quoting or an old prefix.
		# Rewrite just that line. Restoring a *.gvm-backup over the file would
		# look tidier, but it also reverts every edit the user has made since
		# that uninstall - which is how a .bashrc loses changes.
		tmp="$rcfile.gvm-tmp.$$"
		if grep -v 'scripts/gvm' "$rcfile" > "$tmp" 2> /dev/null &&
			cat "$tmp" > "$rcfile" &&
			printf '\n%s\n' "$line" >> "$rcfile"; then
			rm -f "$tmp"
			display_message "  replaced the gvm line in $rcfile"
			return 0
		fi
		rm -f "$tmp"
		display_error "Could not rewrite $rcfile; not changing it"
		return 1
	fi

	if ! printf '\n%s\n' "$line" >> "$rcfile"; then
		display_error "Could not write to $rcfile"
		return 1
	fi
	display_message "  added gvm to $rcfile"
}

# remove_profile_line <file>
remove_profile_line() {
	local rcfile="$1"
	[ -f "$rcfile" ] || return 0
	grep -q 'scripts/gvm' "$rcfile" 2> /dev/null || return 0

	local backup="$rcfile.gvm-backup"
	if [ ! -f "$backup" ]; then
		cp "$rcfile" "$backup" || {
			display_error "Could not back up $rcfile; not changing it"
			return 1
		}
	fi
	if grep -v 'scripts/gvm' "$backup" > "$rcfile"; then
		display_message "  removed the gvm line from $rcfile (backup: $backup)"
	fi
}

# --- uninstall ---------------------------------------------------------------

if [ -n "$do_uninstall" ]; then
	[ -d "$prefix" ] || {
		display_error "Nothing installed at $prefix"
		exit 1
	}
	if [ ! -f "$prefix/scripts/functions" ] && [ ! -d "$prefix/gos" ]; then
		display_error "$prefix does not look like a gvm installation"
		display_message "A gvm root has a scripts/ directory; this one has neither that nor gos/."
		exit 1
	fi

	keep_gos=""
	[ -n "$force" ] && keep_gos=1

	display_message "About to remove $prefix"
	if [ -z "$keep_gos" ]; then
		[ -n "${force:-}" ] || {
			display_message "This deletes every Go version installed there. Pass --force to confirm."
			exit 1
		}
	fi

	# An old gvm may have written its line to a different file than the one this
	# install would pick, so all of them are checked - but only if the user has
	# not asked us to leave profiles alone. --no-profile means *no* profile,
	# and an uninstall that rewrites ~/.bashrc behind --no-profile is how a
	# test suite ends up editing the developer's shell.
	if [ -n "$update_profile" ]; then
		for rcfile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.bash_profile"; do
			remove_profile_line "$rcfile"
		done
	fi

	if [ -n "$keep_gos" ]; then
		find "$prefix" -mindepth 1 -maxdepth 1 ! -name gos -exec rm -rf {} + 2> /dev/null
		display_message "Removed gvm from $prefix, keeping gos/"
	else
		(cd / && rm -rf "$prefix") || {
			display_error "Could not remove $prefix"
			exit 1
		}
		display_message "Removed $prefix"
	fi
	exit 0
fi

# --- preflight ---------------------------------------------------------------

command -v tar > /dev/null 2>&1 || {
	display_error "Could not find tar"
	display_message "  Debian/Ubuntu: apt-get install tar"
	display_message "  macOS:         ships with the system"
	display_message "  RedHat:        yum install tar"
	exit 1
}

if [ -d "$prefix" ] && [ -z "$force" ]; then
	if [ -f "$prefix/VERSION" ] || [ -f "$prefix/scripts/functions" ]; then
		display_error "gvm is already installed at $prefix"
		display_message "  Reinstall over it:   $0 --force"
		display_message "  Remove it instead:   $0 --uninstall"
		exit 1
	fi
	if [ -n "$(ls -A "$prefix" 2> /dev/null)" ]; then
		display_error "$prefix exists and is not empty, and does not look like gvm"
		display_message "Refusing to put a gvm installation on top of it."
		exit 1
	fi
fi

# --- fetch -------------------------------------------------------------------

# The destination is always --prefix. --no-clone only means "do not fetch",
# because installing a checkout over itself would have the installer copying a
# directory into itself.
destination="$prefix"

# A checkout the user is standing in is what they mean to install. Cloning on
# top of it would install a mixture of upstream and the local tree, which is how
# a removed file survives an "upgrade" and how dead build files come back. Only
# fetch when there is nothing here to install from, which is the case for the
# one-line remote installer: it downloads this script into a temporary file with
# no checkout around it.
is_checkout=no
if [ -f "$source_root/VERSION" ] && [ -f "$source_root/scripts/gvm" ]; then
	is_checkout=yes
fi

if [ "$is_checkout" = yes ] && [ "$source_root" != "$prefix" ]; then
	display_message "Installing from this checkout ($source_root)"
	no_clone=1
fi

if [ -n "$no_clone" ]; then
	[ "$is_checkout" = yes ] || {
		display_error "--no-clone was passed but $source_root is not a gvm checkout"
		exit 1
	}
else
	command -v git > /dev/null 2>&1 || {
		display_error "Could not find git, which is needed to fetch gvm"
		display_message "  Debian/Ubuntu: apt-get install git"
		display_message "  macOS:         xcode-select --install"
		display_message "  RedHat:        yum install git"
		display_message ""
		display_message "Already have a gvm checkout? Pass --no-clone to install from it."
		exit 1
	}

	repo="${GVM_REPO:-https://github.com/moovweb/gvm.git}"
	mkdir -p "$prefix" || {
		display_error "Could not create $prefix"
		exit 1
	}

	if [ -d "$prefix/.git" ] || [ -d "$prefix/git.bak" ]; then
		# Already a checkout, presumably from a previous run or a git clone the
		# user did themselves. Update it rather than cloning on top.
		display_message "Updating the existing checkout in $prefix"
		if [ -d "$prefix/git.bak" ] && [ ! -d "$prefix/.git" ]; then
			mv "$prefix/git.bak" "$prefix/.git" || exit 1
		fi
		(cd "$prefix" && git pull --quiet --ff-only) ||
			display_message "  could not fast-forward; continuing with what is there"
		cloned=1
	else
		display_message "Cloning $repo into $prefix"
		git clone --quiet "$repo" "$prefix" || {
			display_error "Failed to clone $repo"
			display_message "  Check the network, or download gvm from $repo and run its install.sh."
			exit 1
		}
		cloned=1
	fi
	destination="$prefix"
fi

# --- install -----------------------------------------------------------------

# An explicit list. `cp -rf .` used to be the whole install, which is how test
# fixtures and scratch files ended up in a user's ~/.gvm.
mkdir -p "$destination" || {
	display_error "Could not create $destination"
	exit 1
}

# Everything the installer puts in a $GVM_ROOT, in one place. The staging copy
# below, the real copy, and the dirty check in scripts/update all depend on this
# list agreeing; scripts/update keeps its own copy of it and
# tests/17_update_test.sh fails if the two drift apart.
installed_items="bin scripts locales VERSION LICENSE AUTHORS README.md README.zh-CN.md"

# Installing a checkout over itself -- running this script out of $prefix, which
# is what --no-clone is for -- cannot copy a directory onto itself: cp either
# refuses or, with the rm below, deletes the file before reading it. Stage the
# new tree somewhere else first, then swap the pieces in.
if [ "$source_root" = "$destination" ]; then
	staging="$(mktemp -d "${TMPDIR:-/tmp}/gvm-install.XXXXXX")" || {
		display_error "Could not create a staging directory"
		exit 1
	}
	trap 'rm -rf "$staging"' EXIT
	for item in $installed_items; do
		[ -e "$source_root/$item" ] || continue
		cp -R "$source_root/$item" "$staging/" || {
			display_error "Could not stage $item from $source_root"
			exit 1
		}
	done
	display_message "Installing over $destination in place"
	source_root="$staging"
fi

installed=0
copy_into() {
	local relative="$1"
	[ -e "$source_root/$relative" ] || return 0
	# Replace rather than merge, so a file removed from the repository does not
	# survive in an upgraded install.
	rm -rf "${destination:?}/$relative"
	if ! cp -R "$source_root/$relative" "$destination/"; then
		display_error "Could not install $relative from $source_root"
		return 1
	fi
	installed=$((installed + 1))
}

for item in $installed_items; do
	copy_into "$item" || exit 1
done

# Keep the files that have to be run directly runnable. Only those: `chmod +x`
# over the whole of scripts/ also marked every *sourced* file as modified, so a
# checkout install came out of the installer dirty and `gvm update` - which
# refuses to move a dirty checkout - could never update it.
chmod +x "$destination/bin/gvm" 2> /dev/null
for script in "$destination"/scripts/*; do
	[ -f "$script" ] || continue
	case "${script##*/}" in
		functions | gvm | gvm-default) continue ;; # sourced, not run
	esac
	chmod +x "$script" 2> /dev/null
done

# Runtime directories. gvm-default creates these too, but a half-configured
# install is much harder to debug than one that is already right.
for dir in gos environments aliases pkgsets cache logs archive/package; do
	mkdir -p "$destination/$dir" 2> /dev/null ||
		display_error "Could not create $destination/$dir"
done

# A package set for the system Go, if there is one, so `gvm use system` and
# `gvm pkset list` have somewhere to point on a fresh machine.
if [ ! -e "$destination/environments/system" ] && command -v go > /dev/null 2>&1; then
	system_goroot="$(go env GOROOT 2> /dev/null)"
	# A Go that belongs to a gvm is not the system Go, whoever the gvm is. This
	# is what happens whenever the installer runs in a shell that already has a
	# gvm active - installing over it, or installing a second copy somewhere
	# else - and recording it makes `gvm use system` and `gvm uninstall` disagree
	# about who owns the directory. The .../gos/... shape is gvm's own layout.
	case "$system_goroot" in
		"$destination"/*) system_goroot="" ;;
		*/gos/*) system_goroot="" ;;
	esac
	if [ -n "$system_goroot" ]; then
		mkdir -p "$destination/pkgsets/system/global"
		cat > "$destination/environments/system" <<EOF
# Automatically generated file. DO NOT EDIT!
export GVM_ROOT; GVM_ROOT="$destination"
export gvm_go_name; gvm_go_name="system"
export gvm_pkgset_name; gvm_pkgset_name="global"
export GOROOT; GOROOT="$system_goroot"
export GOPATH; GOPATH="$destination/pkgsets/system/global"
export PATH; PATH="$destination/pkgsets/system/global/bin:$system_goroot/bin:\$PATH"
EOF
		cp "$destination/environments/system" "$destination/environments/system@global"
		display_message "  recorded the system Go at $system_goroot"
	fi
fi

# gvm keeps its own metadata out of a repository it does not own: a .git inside
# $GVM_ROOT means $GVM_ROOT is somebody's work tree, and every command then warns
# about it (see scripts/env/gvm). It is renamed rather than deleted, so the
# history is still there if someone wants it.
#
# Unless the previous install said it wanted a checkout: `gvm update` needs one,
# and quietly turning a deliberate --keep-repo install back into a git.bak on
# the next reinstall would take that away without anybody asking.
if [ -n "$cloned" ] && [ -z "$keep_repo" ] && [ -d "$destination/.git" ]; then
	if [ "$(sed -n 's/^checkout=//p' "$destination/.gvm-source" 2> /dev/null)" = "yes" ]; then
		display_message "  keeping .git: this install was recorded as a checkout, which is what 'gvm update' uses"
	else
		mv "$destination/.git" "$destination/git.bak" 2> /dev/null &&
			display_message "  kept the git history as $destination/git.bak"
	fi
fi

# --- provenance --------------------------------------------------------------

# Where this gvm came from, so `gvm update` knows what to fetch and `gvm doctor`
# can answer "which gvm is this?". Five key=value lines, written with plain
# printf because this script has to stand on its own; scripts/function/gvm_source
# reads them, and tests/17_update_test.sh fails if the two ever disagree.
write_source_file() {
	local source_repo="${1:-}" source_ref="${2:-}" source_commit="${3:-}" source_version="${4:-}" source_checkout="${5:-no}"

	{
		printf '# Written by gvm. Records what was installed, and where from.\n'
		printf 'repo=%s\n' "$source_repo"
		printf 'ref=%s\n' "$source_ref"
		printf 'commit=%s\n' "$source_commit"
		printf 'version=%s\n' "$source_version"
		printf 'checkout=%s\n' "$source_checkout"
		printf 'installed=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2> /dev/null || echo unknown)"
	} > "$destination/.gvm-source" 2> /dev/null ||
		display_message "  note: could not record the install's origin in $destination/.gvm-source"
}

source_repo="$repo"
if [ -z "$source_repo" ] && [ -d "$source_root/.git" ]; then
	source_repo="$(git -C "$source_root" remote get-url origin 2> /dev/null)"
fi
source_commit=""
source_ref=""
if [ -d "$destination/.git" ]; then
	source_commit="$(git -C "$destination" rev-parse --short HEAD 2> /dev/null)"
	source_ref="$(git -C "$destination" symbolic-ref --short HEAD 2> /dev/null)"
elif [ -d "$source_root/.git" ]; then
	source_commit="$(git -C "$source_root" rev-parse --short HEAD 2> /dev/null)"
	source_ref="$(git -C "$source_root" symbolic-ref --short HEAD 2> /dev/null)"
fi

if [ -d "$destination/.git" ]; then
	write_source_file "$source_repo" "$source_ref" "$source_commit" "$(gvm_version_string)" yes
else
	write_source_file "$source_repo" "$source_ref" "$source_commit" "$(gvm_version_string)" no
fi

# --- profile -----------------------------------------------------------------

if [ -n "$update_profile" ]; then
	if profiles="$(find_profile)"; then
		# shellcheck disable=SC2086
		for rcfile in $profiles; do
			update_profile_file "$rcfile"
		done
	else
		display_message "Could not find a shell profile to update. Add this line yourself:"
		printf '\n  %s\n\n' "$(profile_line)"
	fi
fi

display_message ""
display_message "gvm $(gvm_version_string) installed at $destination"
display_message ""
display_message "Start a new shell, or run this now:"
printf '  source "%s/scripts/gvm"\n\n' "$destination"
display_message "Then:"
printf '  gvm install stable   # download the newest Go release\n'
printf '  gvm use stable       # and use it\n'
