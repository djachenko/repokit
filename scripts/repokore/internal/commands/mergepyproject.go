package commands

import (
	"flag"
	"fmt"
	"os"

	"github.com/djachenko/repokit/repokore/internal/config"
	"github.com/djachenko/repokit/repokore/internal/pyproject"
	"github.com/djachenko/repokit/repokore/internal/template"
)

// MergePyproject renders the template, decides whether it changed since the
// last run, and merges it into the repo's pyproject.toml.
//
// Rendering, hashing and the template_hash bookkeeping live here rather than in
// the calling shell script: each was a separate bash construct (sed, openssl |
// awk, grep | cut, mktemp, trap) and together they made the wrapper grow while
// its logic moved out.
func MergePyproject(args []string) {
	fs := flag.NewFlagSet("merge-pyproject", flag.ExitOnError)
	nonInteractive := fs.Bool("non-interactive", false, "keep current value on all conflicts")
	repo := fs.String("repo", "", "value for {{REPO}}")
	owner := fs.String("owner", "", "value for {{OWNER}}")
	statePath := fs.String("state", ".repokit", "file holding template_hash")

	parse(fs, args, 2, "merge-pyproject [--non-interactive] --repo R --owner O [--state F] <template> <target>")

	tmplPath, targetPath := fs.Arg(0), fs.Arg(1)

	rendered, err := template.RenderFile(tmplPath, map[string]string{
		"REPO":  *repo,
		"OWNER": *owner,
	})
	if err != nil {
		fail("error reading template: %v", err)
	}

	hash := template.Hash(rendered)

	stored, err := config.Get(*statePath, "template_hash")
	if err != nil {
		fail("error reading %s: %v", *statePath, err)
	}

	// Template-to-template, never template-to-file: the user editing their own
	// pyproject.toml must not read as a pending update.
	if hash == stored {
		fmt.Println("→ pyproject.toml is up to date, skipping")
		os.Exit(ExitUpToDate)
	}

	current, err := os.ReadFile(targetPath)
	if err != nil {
		fail("error reading %s: %v", targetPath, err)
	}

	merger := &pyproject.Merger{Interactive: !*nonInteractive && stdinIsTTY()}

	merged, err := merger.MergeText(string(current), rendered)
	if err != nil {
		fail("error merging %s: %v", targetPath, err)
	}

	// Written in full rather than in place: the merge already carried the
	// untouched bytes through, so the file only changes where it decided to.
	if err := os.WriteFile(targetPath, []byte(merged), 0o644); err != nil {
		fail("error writing %s: %v", targetPath, err)
	}

	// Only after the merge landed — a failure here must leave the stored hash
	// alone so the next run tries again instead of assuming success.
	if err := config.Set(*statePath, "template_hash", hash); err != nil {
		fail("error writing %s: %v", *statePath, err)
	}
}
