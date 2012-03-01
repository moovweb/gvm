package gopkgs

import "os"
import "path/filepath"
import "io/ioutil"
import "strings"

func pkgError(msg string) {
	println(msg)
	os.Exit(1)
}

func checkError(err os.Error, msg string) {
	if err != nil {
		pkgError(msg + "\n  " + err.String())
	}
}

func List(gvm_root string) {
	gvm_go_name := os.Getenv("gvm_go_name")
	if gvm_go_name == "" {
		pkgError("ERROR: No pkgset selected")
	}
	gvm_pkgset_name := os.Getenv("gvm_pkgset_name")
	if gvm_pkgset_name == "" {
		pkgError("ERROR: No pkgset selected")
	}

	println("Installed go packages")
	println()
	data, err := ioutil.ReadFile(filepath.Join(gvm_root, "pkgsets", gvm_go_name, gvm_pkgset_name, "goinstall.log"))
	if err != nil {
		return
	}

	buf_str := string(data)
	pkgs := strings.Split(buf_str, "\n")
	for _, pkg := range pkgs {
		println("    " + pkg)
	}
}

