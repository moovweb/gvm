# gvm

GVM provides an interface to manage Go versions.

Features
========
* Install/Uninstall Go versions with `gvm install [tag]` where tag is "60.3", "weekly.2011-11-08", or "tip"
* List added/removed files in GOROOT with `gvm diff`
* Manage GOPATHs with `gvm pkgset [create/use/delete] [name]`
* List latest release tags with `gvm listall`. Use `--all` to list weekly as well.
* Cache a clean copy of the latest Go source for multiple version installs.

Background
==========
When we started developing in Go mismatched dependencies and API changes plauged our build process and made it extremely difficult to merge with other peoples changes.

After nuking my entire GOROOT several times and rebuilding I decided to come up with a tool to oversee the process. It eventually evolved into what gvm is today.

Installing
==========

To install:

    bash < <(curl -s https://raw.github.com/moovweb/gvm/master/binscripts/gvm-installer)

Installing Go
=============
    gvm install 60.3
    gvm use 60.3
Once this is done Go will be in the path and ready to use. $GOROOT and $GOPATH are set automatically.

You are now ready to create and use packages built using gpkg. Instructions can be found at http://github.com/moovweb/gpkg

List Go Versions
================
To list all installed Go versions (The current version is prefixed with "=>"):

    gvm list

Uninstalling
============
To completely remove gvm and all installed Go versions and packages:

    gvm implode

If that doesn't work see the troubleshooting steps at the bottom of this page.

Mac OSX Requirements
====================
    Install mercurial from http://mercurial.berkwood.com/

Linux Requirements
==================
    sudo apt-get install curl
    sudo apt-get install git
    sudo apt-get install mercurial
    sudo apt-get install make
    sudo apt-get install binutils
    sudo apt-get install bison
    sudo apt-get install gcc

Troubleshooting
===============
Sometimes especially during upgrades the state of gvm's files can get mixed up. This is mostly true for upgrade from older version than 0.0.8. Changes are slowing down and a LTR is imminent. But for now `rm -rf ~/.gvm` will always remove gvm. Stay tuned!
