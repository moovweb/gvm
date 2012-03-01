package pkg

import "os"
import "strings"
import "go/parser"
import "go/token"
import "path/filepath"

var root string

func checkIt(f *os.FileInfo) bool {
	if strings.HasSuffix(f.Name, ".go") {
		if f.IsDirectory() {
			return false
		}
		return true
	}
	return false
}

func DebugPackages(path string) {
	fset := token.NewFileSet()
	pkgs, err := parser.ParseDir(fset, path, checkIt, parser.ImportsOnly)
	if err != nil {
		println("ERROR: Couldn't parse files" + err.String())
	}

	for _, pkg := range pkgs {
		println("Package:", pkg.Name)
		println("  ", path[len(root)+1:])
	}
}

func ParseDir(path string) {
	pkgfolder, err := os.Open(path)
	if err != nil {
		println("ERROR: Failed to open pkg dir", path)
	}

	dirs, err := pkgfolder.Readdir(0)
	if err != nil {
		println("ERROR: Failed to read dir", path, pkgfolder)
		os.Exit(1)
	}

	DebugPackages(path)

	for _, pkgfile := range dirs {
		if pkgfile.IsDirectory() {
			if pkgfile.Name != "test" {
				ParseDir(filepath.Join(path, pkgfile.Name))
			}
		}
	}
}

func Install() {
	wd, err := os.Getwd()
	root = wd
	if err != nil {
		println("ERROR: Couldn't read current directory")
	}
	ParseDir(root)
	println()
}
