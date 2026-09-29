// Package commands wires CLI flags to the packages that do the work.
package commands

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/djachenko/repokit/repokore/internal/template"
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

// templateVars registers the placeholder flags every rendering command takes,
// and returns a function that collects them once the flags are parsed.
// --set covers placeholders beyond the three repokit itself knows about.
func templateVars(fs *flag.FlagSet) func() map[string]string {
	repo := fs.String("repo", "", "value for {{REPO}}")
	owner := fs.String("owner", "", "value for {{OWNER}}")
	version := fs.String("version", "", "repokit version; {{VERSION}} gets its major.minor")

	var extra stringList

	fs.Var(&extra, "set", "KEY=VALUE, filling {{KEY}}; repeatable")

	return func() map[string]string {
		vars := map[string]string{
			"REPO":    *repo,
			"OWNER":   *owner,
			"VERSION": template.MajorMinor(*version),
		}

		for _, pair := range extra {
			key, value, found := strings.Cut(pair, "=")
			if !found || key == "" {
				fail("--set wants KEY=VALUE, got %q", pair)
			}

			vars[key] = value
		}

		return vars
	}
}

// writeAtomically replaces path through a temporary file in the same
// directory, so a crash or a full disk mid-write leaves the old file whole
// instead of truncated. perm is set explicitly: the temporary file would
// otherwise impose its own 0600.
func writeAtomically(path string, data []byte, perm os.FileMode) error {
	tmp, err := os.CreateTemp(filepath.Dir(path), "."+filepath.Base(path)+".*")
	if err != nil {
		return err
	}

	defer os.Remove(tmp.Name())

	if _, err := tmp.Write(data); err != nil {
		tmp.Close()

		return err
	}

	if err := tmp.Chmod(perm); err != nil {
		tmp.Close()

		return err
	}

	if err := tmp.Close(); err != nil {
		return err
	}

	return os.Rename(tmp.Name(), path)
}
