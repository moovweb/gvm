package pkgs

import "os"
import "path/filepath"

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

	println("Installed gpkgs")
	println()

	pkgfolder, err := os.Open(filepath.Join(gvm_root, "pkgsets", gvm_go_name, gvm_pkgset_name, "pkg.gvm"))
	if err != nil {
		return
	}

	pkgfolderlist, err := pkgfolder.Readdir(0)
	checkError(err, "ERROR: Failed to read folder")

	var output_str string
	for _, info := range pkgfolderlist {
		pkg_name := info.Name
		output_str = output_str + "    " + pkg_name + " ("

		pkg, err := os.Open(filepath.Join(gvm_root, "pkgsets", gvm_go_name, gvm_pkgset_name, "pkg.gvm", pkg_name))
		checkError(err, "ERROR: Missing pkg folder")

		pkgversionlist, err := pkg.Readdir(0)
		checkError(err, "ERROR: No versions")

		var count int
		for _, version := range pkgversionlist {
			if version.Name != "current" {
				if count > 0 {
					output_str += ", "
				}
				output_str += version.Name
				count++
			}
		}
		output_str += ")\n"
	}
	println(output_str)
}

