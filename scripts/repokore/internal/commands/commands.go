// Package commands wires CLI flags to the packages that do the work.
package commands

import (
	"flag"
	"fmt"
	"os"
)

// ExitUpToDate tells the caller nothing changed, as distinct from an error.
// Bash branches on it to decide whether there is anything to commit.
const ExitUpToDate = 3

// stdinIsTTY reports whether there is a human to answer a prompt. Under CI or
// a pipe stdin is not a character device, and asking would block forever
// waiting for input nobody can type.
func stdinIsTTY() bool {
	info, err := os.Stdin.Stat()

	return err == nil && info.Mode()&os.ModeCharDevice != 0
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}

func parse(fs *flag.FlagSet, args []string, wantArgs int, usage string) {
	if err := fs.Parse(args); err != nil {
		os.Exit(1)
	}

	if fs.NArg() != wantArgs {
		fmt.Fprintln(os.Stderr, "usage: repokore "+usage)
		os.Exit(1)
	}
}
