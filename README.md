# gvm

[![Build Status](https://travis-ci.org/moovweb/gvm.svg?branch=master)](https://travis-ci.org/moovweb/gvm)

by Josh Bussdieker (jbuss, jaja, jbussdieker)

GVM provides an interface to manage Go versions.

## Features
* Install/Uninstall Go versions with `gvm install [tag]` where tag is "60.3", "go1", "weekly.2011-11-08", or "tip"
* List added/removed files in GOROOT with `gvm diff`
* Manage GOPATHs with `gvm pkgset [create/use/delete] [name]`. Use `--local` as `name` to manage repository under local path (`/path/to/repo/.gvm_local`).
* List latest release tags with `gvm listall`. Use `--all` to list weekly as well.
* Cache a clean copy of the latest Go source for multiple version installs.
* Link project directories into GOPATH
* Supports automatic selection of Go version and pkgset using `.go-version` and `.go-pkgset` files.
* Works happily alongside RVM: the [__Ruby Version Manager__](https://rvm.io/) including the usage of `.ruby-version` and `.ruby-gemset` files.

## Background
When we started developing in Go mismatched dependencies and API changes plauged our build process and made it extremely difficult to merge with other peoples changes.

After nuking my entire GOROOT several times and rebuilding I decided to come up with a tool to oversee the process. It eventually evolved into what gvm is today.

## Installing

To install:

```sh
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
```

Or if you are using zsh just change `bash` with `zsh`

### Sourcing gvm into your shell (bash, zsh)
The `gvm-installer` will automatically update your shell environment to load
GVM last. What is needed is a line like this (in your `.bashrc`, `.bash_profile`,
`.zlogin`, etc.). GVM should always be loaded last using a line like this:

```sh
[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"
```

>If you are using RVM as well, then GVM should be loaded __after__ RVM. The
 instructions for RVM will conflict with these instructions. Loading RVM
 last will result in a broken environment. While GVM has been designed to
 accommodate RVM, the reverse statement is not true.

 If you are using both GVM and RVM, then you will need the following at the end
 of your shell init file:

```sh
export PATH="$PATH:$HOME/.rvm/bin"
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"
```

If GVM is installed after RVM, then the above entries should appear in the
proper order already.

## Installing Go
Once you've installed GVM, you will need to install at least one version of Go.
Beginning with Go 1.5 it is no longer possible to build Go by merely downloading
the source code (support for C compilers was removed from the toolchain at that
point and [replaced][compiler_note] with compilers written in Go.) Therefore,
__the very first version of Go that you install should probably be Go 1.4__:

```sh
    gvm install go1.4
    gvm use go1.4
```

Once this is done Go will be in the path and ready to use. `$GOROOT` and `$GOPATH`
will be set automatically.

Additional options can be specified when installing Go:

```
    Usage: gvm install [version] [options]
        -s,  --source=SOURCE      Install Go from specified source.
        -n,  --name=NAME          Override the default name for this version.
        -pb, --with-protobuf      Install Go protocol buffers.
        -b,  --with-build-tools   Install package build tools.
        -B,  --binary             Only install from binary.
             --prefer-binary      Attempt a binary install, falling back to source.
        -h,  --help               Display this message.
```

[compiler_note]: https://docs.google.com/document/d/1OaatvGhEAq7VseQ9kkavxKNAfepWy2yhPUBs96FGV28/edit

## List Go Versions
To list all installed Go versions (The current version is prefixed with "=>"):

```sh
    gvm list
```

To list all Go versions available for download:

```sh
    gvm listall
```

## Using a Go Version
Before you can use Go, you will need to select a Go version:

```
    gvm use go1.4
```

The Go version that is in use will be the last one you selected or the one that
is auto-selected by GVM depending on the presence of a .go-version file.

## Using a Package Set with a Go Version
A package set (__pkgset__) provides a way for you to isolate dependencies for a
project in that all dependencies installed with `go get` will be installed into
the currently active __pkgset__.

Package sets are bound to Go versions. When you switch Go versions (using the
`gvm use` command), the list of package sets available will change. The package
set in use will be the last one you selected or the one that is auto-selected by
GVM depending on the presence of a .go-pkgset file.

### Create a Package Set
Before you can create or select a package set, you must first select a Go
version.

```sh
    gvm pkgset create "my-package-set"
    gvm pkgset use "my-package-set"
```

## Uninstalling
To completely remove gvm and all installed Go versions and packages:

```sh
    gvm implode
```

If that doesn't work see the troubleshooting steps at the bottom of this page.

## Using .go-version and .go-pkgset files
Prior to the introduction of the `.go-version` and `.go-pkgset` files, you had
to manually select the Go version and package set in use, and then those
settings remained set until you once again changed them or began a new session.
When juggling several Go projects it can become quite a hassle to not only
remember which version and pkgset you should be using, but also to execute the
commands to switch to the correct version and pkgset.

The use of `.go-version` and `.go-pkgset` files eliminates this problem all
together.

### .go-version
The content of a `.go-version` file is simple:

```sh
    cat ~/dev/my_go_project/.go-version
    go1.4
```

Just a single line consisting of a Go version as reported by the `gvm list`
command.

### .go-pkgset
The content of a `.go-pkgset` file is simple:

```sh
    cat ~/dev/my_go_project/.go-pkgset
    my-package-set
```

Again, a single line consisting of a GVM package set as reported by the `gvm
pkgset list` command.

### Auto selection of Go version and GVM pkgset

Whenever you change directories (using the cd() command), GVM will search for an
applicable `.go-version` and `.go-pkgset` file. The search will begin in the
directory that your are changing to and will then continue all the way up to the
top of your HOME directory. If these files appear anywhere along the path during
the upwards traversal, GVM will select the file, parse it and apply it. GVM will
only consider the first file it encounters.

If the `.go-version` and/or the `.go-pkgset` files are not found, GVM will next
attempt to make suitable guesses for an appropriate environment to select. The
order of guessing looks like this:

```
Go version:
    1. default environment
    2. system environment
    3. highest version of Go installed

GVM pkgset:
    global pkgset for the version of Go selected
```

## Setting defaults
__TBD__

## Mac OS X Requirements

 * Install Mercurial from https://www.mercurial-scm.org/downloads
 * Install Xcode Command Line Tools from the App Store.

```
xcode-select --install
brew update
brew install mercurial
```

## Linux Requirements

### Debian/Ubuntu

```sh
    sudo apt-get install curl git mercurial make binutils bison gcc build-essential
```

### Redhat/Centos

```sh
    sudo yum install curl
    sudo yum install git
    sudo yum install make
    sudo yum install bison
    sudo yum install gcc
    sudo yum install glibc-devel
```

 * Install Mercurial from http://pkgs.repoforge.org/mercurial/

## FreeBSD Requirements

```sh
    sudo pkg_add -r bash
    sudo pkg_add -r git
    sudo pkg_add -r mercurial
```

## Vendoring Native Code and Dependencies

GVM supports vendoring package set-specific native code and related
dependencies, which is useful if you need to qualify a new configuration
or version of one of these dependencies against a last-known-good version
in an isolated manner.  Such behavior is critical to maintaining good release
engineering and production environment hygiene.

As a convenience matter, GVM will furnish the following environment variables to
aid in this manner if you want to decouple your work from what the operating
system provides:

1. ``${GVM_OVERLAY_PREFIX}`` functions in a manner akin to a root directory
  hierarchy suitable for auto{conf,make,tools} where it could be passed in
  to ``./configure --prefix=${GVM_OVERLAY_PREFIX}`` and not conflict with any
  existing operating system artifacts and hermetically be used by your
  workspace.  This is suitable to use with ``C{PP,XX}FLAGS and LDFLAGS``, but you will have
  to manage these yourself, since each tool that uses them is different.

2. ``${PATH}`` includes ``${GVM_OVERLAY_PREFIX}/bin`` so that any tools you
  manually install will reside there, available for you.

3. ``${LD_LIBRARY_PATH}`` includes ``${GVM_OVERLAY_PREFIX}/lib`` so that any
  runtime library searching can be fulfilled there on FreeBSD and Linux.

4. ``${DYLD_LIBRARY_PATH}`` includes ``${GVM_OVERLAY_PREFIX}/lib`` so that any
  runtime library searching can be fulfilled there on Mac OS X.

5. ``${PKG_CONFIG_PATH}`` includes ``${GVM_OVERLAY_PREFIX}/lib/pkgconfig`` so
  that ``pkg-config`` can automatically resolve any vendored dependencies.

## Recipe for success

```
    gvm use go1.1
    gvm pkgset use current-known-good

    # Let's assume that this includes some C headers and native libraries, which
    # Go's CGO facility wraps for us.  Let's assume that these native
    # dependencies are at version V.
    gvm pkgset create trial-next-version

    # Let's assume that V+1 has come along and you want to safely trial it in
    # your workspace.
    gvm pkgset use trial-next-version

    # Do your work here replicating current-known-good from above, but install
    # V+1 into ${GVM_OVERLAY_PREFIX}.
```

See examples/native for a working example.

## Troubleshooting

Sometimes especially during upgrades the state of gvm's files can get mixed up. This is mostly true for upgrade from older version than 0.0.8. Changes are slowing down and a LTR is imminent. But for now `rm -rf ~/.gvm` will always remove gvm. Stay tuned!
