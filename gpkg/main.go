package main

import "os"
import "path/filepath"
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

	gvm_go_name := os.Getenv("gvm_go_name")
	if gvm_go_name == "" {
		println("ERROR: No Go version selected")
		os.Exit(1)
	}

	if len(os.Args) > 1 {
		if os.Args[1] == "list" {
			println()
			pkgs.List(gvm_root)
			gopkgs.List(gvm_root)
		} else if os.Args[1] == "listall" {
			pkg.List(filepath.Join(gvm_root, "gos", gvm_go_name, "src", "pkg"))
		} else if os.Args[1] == "install" {
			pkg.Install()
		} else {
			showUsage()
		}
	} else {
		showUsage()
	}
}
