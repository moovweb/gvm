# Changelog

Changes from 1.0.22 (2016), whose history is in this repository before that
release. Nothing here changes the interface, only how it works and what it gets
right.

## 1.2.0 - 2026-09-27

Only one thing changed: gvm can update itself.

### `gvm update`

- `gvm update` fetches from the repository the install came from and
  fast-forwards, the way `brew update` does. `gvm update --check` reports what
  it would do and changes nothing, `--repo <url>` fetches from somewhere else
  without touching the checkout's remotes, and `--ref <name>` fetches that
  branch or tag.
- It only ever fast-forwards. An install with local commits, with local edits to
  gvm's own files, or with a merge or rebase somebody interrupted is refused
  with the command that fixes it. An update that resolves a conflict by gvm's
  opinion about somebody's work is worse than no update.
- An install whose files do not match the commit they were installed over - what
  `install.sh` leaves behind when it copies one version over the history of
  another - is refused with the repair that works, and is told that
  `git checkout -- .` is not it: that would put the older code back.
- The installer already kept the history, as `git.bak`, so that most installs
  need no migration: the first `gvm update` moves it back to `.git` and updates
  from there. Installing with `install.sh --keep-repo` skips that step, and a
  later reinstall no longer takes the checkout away again.
- An install with no history at all - a tarball unpacked by hand - is told how to
  get a checkout rather than being updated from a URL nothing has verified.
- Go versions under `$GVM_ROOT/gos`, aliases and package sets are not touched.

### Provenance

- `install.sh` records what it installed in `$GVM_ROOT/.gvm-source`: the
  repository, the ref, the commit, the version, and whether the install is a
  git checkout. `gvm update` updates it, `gvm doctor` reports it, and it is the
  first thing to paste into a bug report. `gvm ls` and friends never read it, so
  a damaged file cannot break a command that has nothing to do with it.
- The shell warning about a `.git` in `GVM_ROOT` now says which kind it found:
  a checkout you asked for, or a `.git` that appeared without anybody's
  intention. `gvm doctor` no longer claims gvm refuses to run when a `.git` is
  present, which it has not done since the warning became a warning.

### Fixed

- `install.sh` ran `chmod +x` over the whole of `scripts/`, including the files
  that are only ever sourced. In a checkout install that marked 34 tracked files
  as modified, which left the install permanently dirty - and a dirty checkout is
  exactly what `gvm update` refuses to move. Only the files that are run are
  marked executable now.
- `gvm update` ignores permission-bit differences when deciding whether the tree
  is dirty, so an install copied onto a filesystem that does not keep modes is
  still updatable.

### Tests

785 assertions in 17 files, up from 664 in 16. The new file builds real
repositories out of the real gvm tree and runs real `git` against them, with the
"remote" being a directory, so `gvm update` is tested without a network.

## 1.1.0 - 2026-09-26

Version 1.1.0 rather than 1.0.23 because the release list, the installer and
the test suite were replaced, not patched.

### Release data

- The release list is fetched from `https://go.dev/dl/?mode=json&include=all`
  instead of being a file in the repository, so `gvm install 1.24` finds patch
  releases published after the bundled list was last edited. `GVM_INDEX_FILE` points
  at a parsed index for air-gapped machines, `GVM_OFFLINE=1` reuses the cache
  and does not refresh it, and `GVM_NO_CACHE=1` forces a refresh.
- Platform artifacts are chosen from the index, so an OS/architecture without a
  published binary says so instead of downloading something that will not run.
- Every download is verified against the SHA256 in the index; a mismatch is
  refused and the file is deleted. `GVM_NO_VERIFY=1` is the only way past it.
- Version sorting is numeric per component, prereleases are excluded from
  partial requests such as `1.24`, and aliases may chain - with a cycle check.
- Source builds pick a bootstrap toolchain: 1.5-1.19 use 1.4, 1.20-1.21 use
  1.17.13, 1.22-1.23 use 1.20.6, 1.24-1.25 use 1.22.6, 1.26-1.27 use 1.24.6, and
  anything newer uses the previous even-numbered minor.

### Behaviour

- `GOTOOLCHAIN=local` is exported whenever a gvm-managed version is selected, so
  a `go.mod` asking for a newer Go cannot make the selected toolchain download
  and use that one behind your back. `gvm use system` unsets it again.
- `gvm install <version> --force` keeps the version's package set. It used to
  go through `uninstall`, which ran `go clean -modcache` and deleted the pkgset,
  so recovering from a corrupted GOROOT also threw away the module cache.
- Reinstalling also refreshes `environments/default` when it pointed at that
  version, so a new shell does not keep settings from an older gvm.
- `gvm implode` refuses a `GVM_ROOT` that is `$HOME` or lacks `scripts/` and
  `VERSION`, and only prompts when there is a terminal, so a script gets an
  error instead of a hang.
- `gvm uninstall` refuses to remove the version currently in use unless forced,
  repairs `environments/default` when it pointed at what was removed, and drops
  aliases that pointed there.

- A package set created by `gvm pkgset create` writes an environment file that
  expanded `$GOPATH` and `$LD_LIBRARY_PATH` unguarded. Any shell running with
  `set -u` - which is what the test suite does, and what plenty of CI does -
  exited the moment that file was sourced, taking the calling shell with it and
  printing nothing, because `cd`'s hook discards the output. They are `${VAR:-}`
  now. The GitHub Actions job found this one, on its first run.

### Commands

- Bash 3.2 is still the default `bash` on macOS, and under `set -u` it treats an
  empty array as unset. `gvm use 1.24.13` passed `${options_hash[*]}` with the
  array still empty, so the shell died with `options_hash[*]: unbound variable`
  before the version was selected - on every `gvm use`, and, because the user's
  shell is where that happens, on the way in. Same shape in `gvm pkgsetuse` and
  in `munge_path`'s PATH assembly. 23 expansions now carry a default.
- The install test started its file server on port 0 and scraped the port out
  of python's log line. That line is python's wording, not ours, and when the
  test could not read it, it waited ten seconds and gave up on a server that was
  running. It asks python for a free port and polls with `/dev/tcp` instead, and
  prints the server's log if it still cannot start. The same test called
  `sha256sum` directly to checksum its own fixture; macOS has `shasum` and no
  `sha256sum`, and a pipeline through `cut` hid the failure, so the index went
  out with an empty checksum. It uses gvm's own `gvm_checksum_file` now.
- The test suite dropped every `GVM_*` variable it inherited, so it can be run
  from a shell that has gvm sourced. `GVM_SOURCED=1` alone makes `scripts/gvm`
  return on sight, and the suite went through testing nothing: it failed on any
  machine with gvm installed and passed in CI, which has no `GVM_*` in its
  environment at all.
- macOS puts `TMPDIR` under `/var`, which is a symlink to `/private/var`, and
  ends it with a slash. The test harness resolved neither, so a path built from
  `TMPDIR` and a path gvm reported for the same directory were spelled
  differently and three cd assertions failed on macOS only. The harness strips
  the slash and resolves symlinks once, up front.
- The four `display_*` helpers assume they were given a message, so a caller
  that passes an empty list kills the shell instead of reporting the problem -
  on bash 3.2 under `set -u`, which is the shell the message was for. They
  print what they were given, which may be nothing.
- The zsh test's "no zsh installed" branch called a function that does not
  exist, so skipping the test failed the file that skipped it.
- The `cd` override kept the user's own `cd` by lifting its body out of
  `declare -f cd` output: delete the first line, delete the last. That keeps the
  opening brace and drops the closing one, so the `eval` failed, `__gvm_oldcd`
  was never defined, and `cd` stopped changing directory - silently, and only for
  anyone who had a `cd` function. It renames the definition now.
- New: `gvm doctor`, `gvm ls-remote`, `gvm applymod`, `gvm which`, `gvm delete`.
- Rewritten: `gvm install`, `gvm use`, `gvm pkgset`, `gvm diff`, `gvm help`,
  `gvm linkthis`, `gvm pkgenv`, `gvm completion`, `gvm display`.
- `gvm get`, `gvm update` and `gvm cross` are gone. `cross` was a wrapper for
  build tooling that no longer exists; the other two were dead branches that
  shadowed `gvm install`.

### Portability and installation

- zsh is supported and covered by the suite, not just bash. Option changes
  (`KSH_ARRAYS`, `BASH_REMATCH`, `BASH_SOURCE`, `posix`) are saved and restored,
  and array handling works with and without `KSH_ARRAYS`.
- `GVM_ROOT` and other paths may contain spaces.
- `install.sh` replaces the autotools build: it installs from a checkout without
  cloning upstream over it, stages a self-install so it cannot delete its own
  source, keeps the git history as `git.bak`, and honours `--no-profile` on
  `--uninstall` as well as on install. A leftover `*.gvm-backup` is no longer
  restored over your shell profile, only mentioned.
- A Go inside `$GVM_ROOT` is no longer recorded as the "system" Go when
  installing over an existing gvm.
- Boolean environment variables accept `1/true/yes/on` and `0/false/no/off`, so
  `GVM_NO_VERIFY=0` verifies. `GVM_OFFLINE`, `GVM_NO_VERIFY`, `GVM_QUIET`,
  `GVM_DEBUG` and `GVM_NO_COLORS` all go through one helper.

### Documentation and tests

- `README.md` rewritten, and a Chinese translation added.
- The suite is 664 assertions of plain bash with no external framework, one file
  per area, each building a throwaway `GVM_ROOT`. It fails if a test writes to
  the developer's real `~/.bashrc` or `~/.zshrc`, and it runs under
  `LC_ALL=C` so a non-English locale cannot hide a failure.
- GitHub Actions runs lint and tests on Linux and on macOS, whose `bash` is 3.2.
  The runner streams each test file's output instead of capturing it, so a hang
  says which file hung, and the check that the suite left the developer's real
  `~/.bashrc` and `~/.zshrc` alone uses `cmp` on copies: `md5sum` does not exist
  on macOS, so that guard was doing nothing there.
