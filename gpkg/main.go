package main

import "os"
import "github.com/moovweb/gvm/gpkg/pkgs"

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
			pkgs.List(gvm_root)
		} else {
			showUsage()
		}
	} else {
		showUsage()
	}
}
