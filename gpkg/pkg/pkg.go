package pkg

import "os"
//import "path"
import "strings"
import "go/parser"
import "go/token"
import "path/filepath"
import "io/ioutil"

var root string
var go_packages []string

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

func checkName(name string) bool {
	for _, cur_name := range go_packages {
		if "\"" + cur_name + "\"" == name {
			return true
		}
	}
	return false
}

func DebugPackages(path string, level int) {
	fset := token.NewFileSet()
	pkgs, err := parser.ParseDir(fset, path, checkIt, 0)
	if err != nil {
		println("ERROR: Couldn't parse files" + err.String())
	}

	pkg_name := ""

	for _, pkg := range pkgs {
		
		if len(path) > len(root) {
			pkg_name = path[len(root)+1:]
		} else {
			pkg_name = pkg.Name
		}
	}

	imp_list := ""
	if level > 0 {
		imports := make(map[string]string)
		file := fset.Files()
		for f := range file {
			imports = readFile(imports, f.Name())
		}

		
		for _, str := range imports {
			if checkName(str) == false {
				imp_list += str[1:len(str)-1] + " "
			}
		}
	}

	if pkg_name != "" {
		println(pkg_name + ": " + imp_list)
		//println("	make -f Makefile.gvm -C " + pkg_name)
		println("	goinstall -nuke " + pkg_name)
	}
}

func ParseDir(path string, level int) {
	pkgfolder, err := os.Open(path)
	if err != nil {
		println("ERROR: Failed to open pkg dir", path)
	}

	dirs, err := pkgfolder.Readdir(0)
	if err != nil {
		println("ERROR: Failed to read dir", path, pkgfolder)
		os.Exit(1)
	}

	DebugPackages(path, level)

	for _, pkgfile := range dirs {
		if pkgfile.IsDirectory() {
			if pkgfile.Name != "test" && pkgfile.Name != "_obj" && pkgfile.Name != "_bin" {
				ParseDir(filepath.Join(path, pkgfile.Name), level)
			}
		}
	}
}

func List(path string) {
	root = path
	ParseDir(path, 0)
}

func Install() {
	data, err := ioutil.ReadFile("go.list")
	if err != nil {
		println("ERROR: Failed to read Go default package list")
	}
	go_packages = strings.Split(string(data), "\n")

	wd, err := os.Getwd()
	root = wd
	if err != nil {
		println("ERROR: Couldn't read current directory")
	}
	ParseDir(root, 1)
	println()
}
