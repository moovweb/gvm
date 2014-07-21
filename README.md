# gvm

[![Build Status](https://travis-ci.org/moovweb/gvm.svg?branch=master)](https://travis-ci.org/moovweb/gvm)

by Josh Bussdieker (jbuss, jaja, jbussdieker)

GVM provides an interface to manage Go versions.

Features
========
* Install/Uninstall Go versions with `gvm install [tag]` where tag is "60.3", "go1", "weekly.2011-11-08", or "tip"
* List added/removed files in GOROOT with `gvm diff`
* Manage GOPATHs with `gvm pkgset [create/use/delete] [name]`. Use `--local` as `name` to manage repository under local path (`/path/to/repo/.gvm_local`).
* List latest release tags with `gvm listall`. Use `--all` to list weekly as well.
* Cache a clean copy of the latest Go source for multiple version installs.
* Link project directories into GOPATH

Background
==========
When we started developing in Go mismatched dependencies and API changes plauged our build process and made it extremely difficult to merge with other peoples changes.

After nuking my entire GOROOT several times and rebuilding I decided to come up with a tool to oversee the process. It eventually evolved into what gvm is today.

Installing
==========

To install:

    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)

Installing Go
=============
    gvm install go1
    gvm use go1 [--default]
Once this is done Go will be in the path and ready to use. $GOROOT and $GOPATH are set automatically.

Additional options can be specified when installing Go:

    Usage: gvm install [version] [options]
        -s,  --source=SOURCE      Install Go from specified source.
        -n,  --name=NAME          Override the default name for this version.
        -pb, --with-protobuf      Install Go protocol buffers.
        -b,  --with-build-tools   Install package build tools.
        -B,  --binary             Only install from binary.
             --prefer-binary      Attempt a binary install, falling back to source.
        -h,  --help               Display this message.

List Go Versions
================
To list all installed Go versions (The current version is prefixed with "=>"):

    gvm list

Uninstalling
============
To completely remove gvm and all installed Go versions and packages:

    gvm implode

If that doesn't work see the troubleshooting steps at the bottom of this page.

Mac OS X Requirements
====================
 * Install Mercurial from http://mercurial.berkwood.com/
 * Install Xcode Command Line Tools from the App Store.

Linux Requirements
==================

Debian/Ubuntu
==================
    sudo apt-get install curl git mercurial make binutils bison gcc build-essential

Redhat/Centos
==================

    sudo yum install curl
    sudo yum install git
    sudo yum install make
    sudo yum install bison
    sudo yum install gcc
    sudo yum install glibc-devel

 * Install Mercurial from http://pkgs.repoforge.org/mercurial/

FreeBSD Requirements
====================

    sudo pkg_add -r bash
    sudo pkg_add -r git
    sudo pkg_add -r mercurial

Vendoring Native Code and Dependencies
==================================================
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

Recipe for success:

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

See examples/native for a working example.

Troubleshooting
===============
Sometimes especially during upgrades the state of gvm's files can get mixed up. This is mostly true for upgrade from older version than 0.0.8. Changes are slowing down and a LTR is imminent. But for now `rm -rf ~/.gvm` will always remove gvm. Stay tuned!
