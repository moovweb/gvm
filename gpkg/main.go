package main

import "os"
import "github.com/moovweb/gvm/gpkg/pkg"
import "github.com/moovweb/gvm/gpkg/pkgs"
import "github.com/moovweb/gvm/gpkg/gopkgs"

func showUsage() {
	println("usage: gpkg list")
}

func main() {
	gvm_root := os.Getenv("GVM_ROOT")
	if gvm_root == "" {
		println("ERROR: gpkg requires gvm to run (http://github.com/moovweb/gvm)")
		os.Exit(1)
	}

	if len(os.Args) > 1 {
		if os.Args[1] == "list" {
			println()
			pkgs.List(gvm_root)
			gopkgs.List(gvm_root)
		} else if os.Args[1] == "install" {
			pkg.Install()
		} else {
			showUsage()
		}
	} else {
		showUsage()
	}
}
