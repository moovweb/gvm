package main

import "os"

func main() {
	gvm_root := os.Getenv("GVM_ROOT")
	if gvm_root == "" {
		println("ERROR: gpkg requires gvm to run (http://github.com/moovweb/gvm)")
	} else {
		println("GVM Package Manager for release.r60.3!")
	}
}
