package commands

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"github.com/djachenko/repokit/repokore/internal/managedfile"
	"github.com/djachenko/repokit/repokore/internal/template"
)

// Sync renders a template into a file repokit keeps in the user's repo, if
// that file is still repokit's to write.
//
// It prints the destination when it wrote it and nothing otherwise, so the
// caller stages exactly what changed. A file it had to leave alone is reported
// on stderr. The exit code means only success or failure.
func Sync(args []string) {
	fs := flag.NewFlagSet("sync", flag.ExitOnError)
	force := fs.Bool("force", false, "overwrite even a file that is not repokit's")
	skipHint := fs.String("skip-hint", "", "added to the notice when a file is left alone")
	vars := templateVars(fs)

	parse(fs, args, 2, "sync [--force] [--skip-hint H] [--repo R] [--owner O] [--version V] [--set K=V]... <template> <dest>")

	tmplPath, dest := fs.Arg(0), fs.Arg(1)

	rendered, err := template.RenderFile(tmplPath, vars())
	if err != nil {
		fail("error reading template: %v", err)
	}

	decision, err := managedfile.Decide(dest, []byte(rendered), *force)
	if err != nil {
		fail("error checking %s: %v", dest, err)
	}

	switch decision {
	case managedfile.Unchanged:
		return

	case managedfile.Skip:
		notice := fmt.Sprintf("  skip %s (changed since repokit wrote it)", dest)
		if *skipHint != "" {
			notice += " — " + *skipHint
		}

		fmt.Fprintln(os.Stderr, notice)

		return
	}

	if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
		fail("error creating %s: %v", filepath.Dir(dest), err)
	}

	if err := writeAtomically(dest, []byte(rendered), permFor(dest, tmplPath)); err != nil {
		fail("error writing %s: %v", dest, err)
	}

	fmt.Println(dest)
}

// permFor keeps the permissions of a file being replaced, and gives a new one
// the template's — so an executable script template yields an executable
// script without anyone listing which files are scripts.
func permFor(dest, tmplPath string) os.FileMode {
	if info, err := os.Stat(dest); err == nil {
		return info.Mode().Perm()
	}

	if info, err := os.Stat(tmplPath); err == nil {
		return info.Mode().Perm()
	}

	return 0o644
}
