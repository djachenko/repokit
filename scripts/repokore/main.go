package main

import (
	"fmt"
	"os"
)

// repokore owns the structural work bash can't do safely: parsing config
// formats, generating JSON, diffing structured files. Bash stays the glue
// around git and gh.
//
// Each subcommand lives in its own file and gets one line in the switch.
func main() {
	if len(os.Args) < 2 {
		usage()
	}

	args := os.Args[2:]

	switch os.Args[1] {
	case "merge-pyproject":
		mergePyproject(args)
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n\n", os.Args[1])
		usage()
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: repokore <command> [args]")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "commands:")
	fmt.Fprintln(os.Stderr, "  merge-pyproject [--non-interactive] <template> <target>")
	os.Exit(1)
}
