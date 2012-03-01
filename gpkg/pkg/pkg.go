package pkg

import "os"
import "strings"
import "go/parser"
import "go/token"
import "path/filepath"

var root string

func readFile(imports map[string]string, filename string) map[string]string {
	fset := token.NewFileSet()
	a, err := parser.ParseFile(fset, filename, nil, parser.ImportsOnly)
	if err != nil {
		println("ERR")
	}

	for _, imp := range a.Imports {
		imports[imp.Path.Value] = imp.Path.Value
	}
	return imports
}

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
	pkgs, err := parser.ParseDir(fset, path, checkIt, 0)
	if err != nil {
		println("ERROR: Couldn't parse files" + err.String())
	}

	for _, pkg := range pkgs {
		pkg_name := ""
		if len(path) > len(root) {
			pkg_name = path[len(root)+1:] + "/" + pkg.Name
		} else {
			pkg_name = pkg.Name
		}
		println("  Package:", pkg_name)
	}

	imports := make(map[string]string)
	file := fset.Files()
	for f := range file {
		imports = readFile(imports, f.Name())
		//println(f.Name())
	}

	for _, str := range imports {
		println("    import", str)
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
			if pkgfile.Name != "test" && pkgfile.Name != "_obj" && pkgfile.Name != "_bin" {
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
