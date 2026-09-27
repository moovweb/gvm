# gvm

English | [简体中文](./README.zh-CN.md)

A Go version manager, in the shape nvm made familiar: `gvm install stable`,
`gvm use stable`, and a directory of Go trees you can switch between without
touching your project.


```console
$ gvm install 1.24
Downloading go1.24.13.linux-amd64.tar.gz
go1.24.13 successfully installed

$ gvm use 1.24
Now using version go1.24.13

$ go version
go version go1.24.13 linux/amd64
```

## Installing

Nothing to build. One of these:

```console
$ bash <(curl -sSL https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
```

Or from a checkout:

```console
$ git clone https://github.com/moovweb/gvm.git
$ cd gvm
$ ./install.sh
```

Or with make, if you prefer:

```console
$ make install                      # into ~/.gvm
$ make install PREFIX=~/go/gvm
```

The installer puts gvm in `~/.gvm` by default, adds one line to your shell
profile, and leaves everything else alone. It refuses to install over a
directory that is not already a gvm, so `--force` is a deliberate word.

| Flag | Effect |
| --- | --- |
| `--prefix <dir>` | Where to install. Default `~/.gvm` |
| `--profile <file>` | Update this profile instead of guessing |
| `--no-profile` | Do not touch any profile |
| `--force` | Reinstall over an existing gvm |
| `--no-clone` | Install from the checkout you are standing in |
| `--keep-repo` | Keep the git checkout as `.git`, instead of renaming it to `git.bak` |
| `--uninstall` | Remove gvm; keeps `$PREFIX/gos` with `--force` |

The profile line is:

```bash
[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"
```

`scripts/gvm` works out `GVM_ROOT` from its own location, so you can move or
symlink the directory without editing your profile. `gvm implode` takes the
line back out again and leaves a `.gvm-backup` beside it.

Works in bash and zsh; the profile line goes into whichever one the installer
finds. Requirements: `bash` 3.2+ (or zsh 5+), `tar`, `gzip`, `awk`, `sed`, and a
SHA256 utility
(`sha256sum` or `shasum`). `curl` is needed to download, and `make` plus a C
compiler only for source builds. `gvm doctor` checks all of it.

## Updating gvm

`gvm update` fetches from the repository your install came from and
fast-forwards, the way `brew update` does:

```console
$ gvm update
Fetching origin
gvm 1.1.0 -> 1.2.0 (949184e..a1b2c3d)
1 new commit(s):
  a1b2c3d Release 1.2.0

gvm is now at 1.2.0 (a1b2c3d).
Start a new shell to pick it up:  exec $SHELL
Go versions under /home/you/.gvm/gos were not touched.
```

| Flag | Effect |
| --- | --- |
| `--check` | Report what an update would do, and change nothing |
| `--repo <url>` | Fetch from somewhere else, without adding a remote |
| `--ref <name>` | Fetch that branch or tag instead of the tracked one |

It only ever fast-forwards. A checkout with local commits, with local edits to
gvm's own files, or with a merge or rebase somebody interrupted is refused, and
the error names the command that fixes it - `git -C ~/.gvm stash` for edits,
`gvm update --repo <your fork>` for local commits. An update that resolved a
conflict by gvm's opinion about your work would be worse than no update at all.

`install.sh` has always kept the history it cloned, as `~/.gvm/git.bak`, so an
install made by the one-liner is updatable without being reinstalled: the first
`gvm update` moves it back to `.git` and updates from there. `install.sh
--keep-repo` keeps the checkout in place instead, and a later reinstall leaves it
alone. An install with no history at all - a tarball unpacked by hand - is told
how to get a checkout rather than updated from a URL nothing has verified.

`gvm update` does not touch the Go versions under `gos/`, your aliases or your
package sets, and it does not switch the version you are using. It updates the
files; the shell you are in picks them up when you start a new one.

## Using it

### Versions

```console
$ gvm ls                    # installed versions and aliases
$ gvm ls-remote 1.24        # published releases
$ gvm use 1.24              # newest installed go1.24.x
$ gvm use go1.24.13         # exactly this one
$ gvm use stable            # newest stable, installed or not
$ gvm which                 # the GOROOT in effect
$ gvm which 1.24 go         # the path to that version's `go`
$ gvm current               # the selected version
```

`gvm install` takes the same arguments: a full version, a partial one, or an
alias. `gvm use` only ever selects something already installed; it will tell you
to install a version rather than fetching one behind your back.

### The names gvm understands

| Name | Meaning |
| --- | --- |
| `1.24.13`, `go1.24.13` | Exactly that release |
| `1.24`, `1.24.*` | The newest `go1.24.x` |
| `1.24.0rc1` | That release candidate |
| `stable`, `latest` | The newest stable release |
| `unstable` | The newest beta or release candidate |
| `newest` | The newest release of any kind |
| `oldest` | The oldest stable release gvm knows about |
| `default` | Whatever `gvm use --default` recorded |
| `system` | The Go already on your `PATH`, unmanaged |

Pre-releases are only ever selected on purpose. Asking for `1.25` when no stable
`go1.25.x` is installed picks the newest stable; if it can only find a release
candidate, it says so before switching.

### Aliases

```console
$ gvm alias create work 1.24
$ gvm use work
$ gvm alias list
$ gvm alias delete work
```

Aliases can point at versions or at other aliases, including the built-in ones,
so `gvm alias create mine stable` works. A cycle is refused rather than followed.

### Per-directory versions

Drop a `.go-version` in a project and gvm switches as you `cd` in:

```console
$ cat .go-version
1.24.13
$ cat .go-pkgset        # optional, selects a package set too
myproject
```

The file is searched for upwards from the current directory, so a monorepo can
have one at the root. The hook is installed with the profile; a shell that
already has a `cd` override keeps it.

`gvm applymod` reads the `go` directive out of a `go.mod` and switches to
something that satisfies it, treating it as a minimum the way Go does:

```console
$ gvm applymod
go.mod asks for go1.24.0
Now using version go1.24.13
```

It will not download anything: if nothing suitable is installed it prints the
`gvm install` line to run instead.

### Package sets

`GOPATH` moved from being one-per-machine to one-per-project:

```console
$ gvm pkgset create myproject
$ gvm use 1.24@myproject
$ gvm pkgset list
$ gvm pkgenv myproject     # print the environment; --edit to open $EDITOR
```

`gvm linkthis` symlinks the current directory into `GOPATH/src` for the old
GOPATH workflow.

### Source builds

```console
$ gvm install 1.25 --source
```

`--source` builds from `go.dev/dl` source rather than downloading a binary. It
needs a bootstrap toolchain, which gvm installs for you: the oldest supported
release of each series is pinned, and Go 1.26+ uses the even-numbered minor
release. Override it with `GOROOT_BOOTSTRAP` if you want to:

```console
$ GOROOT_BOOTSTRAP=$HOME/sdk/go1.24.6 gvm install 1.26 --source
```

Building the development tree is a git operation and needs a full C toolchain:

```console
$ gvm install master --from-git
```

That clones `golang/go` shallowly at the ref you name and builds it. It is the
only path that uses git, and it is slow on purpose.

### Cross compilation

gvm does not keep a tree per platform. Build for another one with the toolchain
you have:

```console
$ GOOS=darwin GOARCH=arm64 go build ./...
$ GOOS=windows GOARCH=amd64 go build -o app.exe .
```

If you want a genuinely separate toolchain per platform, the Go team ships
[`golang.org/dl`](https://pkg.go.dev/golang.org/dl), which manages its own
downloads:

```console
$ go install golang.org/dl/go1.24.13@latest
$ go1.24.13 download
```

### Keeping Go honest

`gvm diff` reports what changed inside an installed tree, against the file list
recorded at install time:

```console
$ gvm diff 1.24
WARNING: *Dirty* /home/you/.gvm/gos/go1.24.13
  added:
    + ./src/handwritten.go
```

`gvm doctor` reports on the installation and on the tools a command needs.

## Security

- Every artifact is checked against the SHA256 in the Go release index before it
  is unpacked. `GVM_NO_VERIFY=1` disables that and is not recommended.
- The index comes from `go.dev/dl`, and can be pinned with `GVM_INDEX_FILE` (a
  parsed TSV, not raw JSON) for air-gapped machines. `GVM_OFFLINE=1` keeps an
  existing cache without refreshing it; `GVM_OFFLINE=0` is not offline.
- `gvm implode`, the one command that deletes a whole tree, refuses a
  `GVM_ROOT` that does not have both `scripts/` and `VERSION`, and only prompts
  when there is a terminal, so a script gets an error instead of a hang.
- `gvm uninstall` refuses to remove the version currently in use unless forced.
- `gvm update` only fast-forwards, and refuses a dirty, diverged or
  half-finished checkout instead of resolving it for you. A tool that overwrites
  the files you edited to make it work is not an update.
- `gvm install <version> --force` replaces the GOROOT and nothing else. Your
  package set survives, which matters because that is where the module cache and
  everything `go get` built live: reinstalling a version is how you recover from
  a corrupted Go tree, and it should not also cost you the download cache.

## Environment variables

| Variable | Effect |
| --- | --- |
| `GVM_ROOT` | Where gvm is installed. Set by the profile line; do not set by hand |
| `GVM_OFFLINE` | Never refresh the release index |
| `GVM_DL_BASE_URL` | Fetch artifacts from a mirror instead of `go.dev` |
| `GVM_NO_VERIFY` | Skip checksum verification |
| `GOROOT_BOOTSTRAP` | Toolchain used to build a source install |
| `GVM_QUIET` | Say less |
| `GVM_DEBUG` | Trace the internals |

The boolean ones read `1`/`true`/`yes`/`on` and `0`/`false`/`no`/`off`, so
`GVM_NO_VERIFY=0` still verifies. Anything else is reported and treated as false.

## How it works

`GOTOOLCHAIN` is the one thing that behaves differently here. Modern Go can
download and switch toolchains by itself, so gvm sets `GOTOOLCHAIN=local` when
it selects a version. Without that, a `go.mod` saying `go 1.30` would send the
toolchain off to fetch Go 1.30 and quietly ignore the version you selected.
Set `GOTOOLCHAIN` yourself if you would rather Go managed that.

`$GVM_ROOT/.gvm-source` records what the installer put there: repository, ref,
commit, version, and whether the install is a git checkout. `gvm update` keeps
it current and `gvm doctor` prints it, and it is the first thing worth pasting
into a bug report. Only `gvm update` writes it and no `gvm ls` ever reads it, so
a damaged file cannot break a command that has nothing to do with it.

## What changed in 1.1.0 and 1.2.0

1.2.0 added `gvm update` - see [Updating gvm](#updating-gvm) - and fixed the
two things that got in its way. The rest of this section is 1.1.0, which is where
the rewrite happened.

1.0.22 is from 2016 and its release list is a file in the repository, so a
`gvm install 1.24` could only find the patch releases that existed when the
file was last edited. This is a rewrite of the parts that had aged, keeping the
interface:

- **Releases come from [go.dev](https://go.dev/dl).** `gvm install 1.24`
  resolves to the newest `go1.24.x` that was actually published, including
  patch releases newer than this repository's last commit, and picks the right
  artifact for your platform. `GVM_INDEX_FILE` pins a parsed index and
  `GVM_OFFLINE=1` reuses the cache, for machines that cannot reach the network.
- **Downloads are verified.** SHA256 for every artifact, refused on mismatch
  unless `GVM_NO_VERIFY=1` is set explicitly.
- **`GOTOOLCHAIN=local` while a gvm version is selected**, so a `go.mod`
  asking for a newer Go cannot make the selected toolchain quietly fetch and use
  that one instead.
- **zsh is supported and tested**, not just bash, and paths containing spaces
  work everywhere (`GVM_ROOT="/opt/my gvm"`).
- **The installer no longer needs autotools or Ruby.** It installs from a
  checkout without cloning over it, refuses to delete a gvm that is in use, and
  `--uninstall` honours `--no-profile`. Reinstalling a version with `--force`
  keeps its package set, so recovering from a broken Go tree does not cost you
  the module cache.
- **New commands**: `gvm update` (update gvm itself from git), `gvm doctor`
  (what is wrong with this installation), `gvm ls-remote` (what is published),
  `gvm applymod` (switch to whatever a `go.mod` asks for, treating it as the
  minimum it is), `gvm which`, `gvm delete`, and a rewritten `gvm diff` and
  `gvm help`.
- **The test suite** is 785 assertions of plain bash with no framework, each
  file building its own throwaway `GVM_ROOT`. It also fails if a test writes to
  your real `~/.bashrc` or `~/.zshrc`. `gvm update` is tested against real
  repositories built out of the real gvm tree, with the "remote" being a
  directory, so the test needs no network. GitHub Actions runs it on Linux and
  on macOS, whose `bash` is 3.2.
- **A Chinese README** ([简体中文](./README.zh-CN.md)) and a proper `CHANGELOG`.

Bugs fixed that are worth calling out, because they were silent: `gvm implode`
deleted a `GVM_ROOT` that was your `$HOME`; `gvm uninstall` removed the version
you were using and left `environments/default` pointing at nothing; and
`gvm install --force` emptied the package set of the version it was reinstalling.

## Development

```console
$ make test          # the whole suite, in throwaway sandboxes
$ make lint          # parse every shell script
$ ./tests/run.sh     # the same thing
```

Each test file is standalone, needs no framework, and builds its own `GVM_ROOT`
under `/tmp`, so the suite never touches a real installation. Tests that need
the release index pin it to a fixture.

macOS is where gvm is most likely to be used, and its `bash` is 3.2, so the
suite is worth running there even from Linux. A container is enough:

```console
$ docker build -t gvm-bash32 - <<'EOF'
FROM bash:3.2
RUN apk add --no-cache coreutils findutils grep gawk sed procps git python3 go curl make
RUN ln -sf /usr/local/bin/bash /usr/bin/bash && ln -sf /usr/local/bin/bash /bin/bash
EOF
$ docker run --rm -v "$PWD:/w" -w /w -e HOME=/tmp gvm-bash32 bash tests/run.sh
```

Two more conditions worth reproducing on purpose, because they have each broken
a test that passed everywhere else - neither needs macOS:

```console
$ TMPDIR=/tmp/whatever/ bash tests/run.sh       # macOS sets TMPDIR with a slash
$ ln -s /tmp /tmp/varlink
$ TMPDIR=/tmp/varlink/ bash tests/run.sh        # ... and under /var -> /private/var
```

The layout is flat on purpose: `bin/gvm` dispatches by file name, so a command
is `scripts/<name>` and a shell function is `scripts/env/<name>`. `make lint`
and the help-consistency test in `tests/09_cli_test.sh` both fail if the three
lists - files, help text, and what is advertised - stop agreeing.

## License

MIT, unchanged: `LICENSE` is Moov Corp.'s and is not touched here.
See [What changed in 1.1.0](#what-changed-in-110) for the details.
