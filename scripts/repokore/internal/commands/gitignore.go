package commands

import (
	"flag"
	"fmt"
	"os"

	"github.com/djachenko/repokit/repokore/internal/gitignore"
)

// Gitignore keeps entries in .gitignore. Both operations print the entries they
// actually added, one per line, so the caller can report and commit only when
// something changed.
func Gitignore(args []string) {
	if len(args) == 0 {
		fail("usage: repokore gitignore <add|sensitive> ...")
	}

	switch args[0] {
	case "add":
		gitignoreAdd(args[1:])
	case "sensitive":
		gitignoreSensitive(args[1:])
	default:
		fail("unknown gitignore operation: %s", args[0])
	}
}

func gitignoreAdd(args []string) {
	fs := flag.NewFlagSet("gitignore add", flag.ExitOnError)
	path := fs.String("file", ".gitignore", "ignore file to update")

	if err := fs.Parse(args); err != nil {
		os.Exit(1)
	}

	if fs.NArg() == 0 {
		fmt.Fprintln(os.Stderr, "usage: repokore gitignore add [--file F] <pattern>...")
		os.Exit(1)
	}

	report(gitignore.Add(*path, fs.Args()))
}

// gitignoreSensitive protects the credential files that happen to be sitting in
// the directory, before anything is pushed anywhere.
func gitignoreSensitive(args []string) {
	fs := flag.NewFlagSet("gitignore sensitive", flag.ExitOnError)
	path := fs.String("file", ".gitignore", "ignore file to update")
	dir := fs.String("dir", ".", "directory to scan")

	parse(fs, args, 0, "gitignore sensitive [--file F] [--dir D]")

	matched, err := gitignore.Matching(*dir, gitignore.Sensitive)
	if err != nil {
		fail("error scanning %s: %v", *dir, err)
	}

	report(gitignore.Add(*path, matched))
}

func report(added []string, err error) {
	if err != nil {
		fail("error updating ignore file: %v", err)
	}

	for _, pattern := range added {
		fmt.Println(pattern)
	}
}
