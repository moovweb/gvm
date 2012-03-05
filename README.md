# gvm

GVM provides an interface to manage Go versions.

Installing
==========

To install the stable release run:

    bash -s stable < <(curl -s https://raw.github.com/moovweb/gvm/master/binscripts/gvm-installer)

To install the development branch (NOT USUALLY RECOMMENDED!) run:

    bash < <(curl -s https://raw.github.com/moovweb/gvm/master/binscripts/gvm-installer)

Installing Go
=============
    gvm install 60.3
    gvm use 60.3
Once this is done Go will be in the path and ready to use. $GOROOT is set automatically.

You are now ready to create packages using gpkg. Instructions can be found at http://github.com/moovweb/gpkg

List Go Versions
================
To list all installed Go versions (The current version is prefixed with "=>"):

    gvm list

Uninstalling
============
To completely remove gvm and all installed Go versions and packages:

    gvm implode

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

