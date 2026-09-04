package commands

import (
	"flag"
	"fmt"
	"os"

	"github.com/djachenko/repokit/repokore/internal/config"
	"github.com/djachenko/repokit/repokore/internal/template"
)

// RenderTemplate renders a template and records its hash, so a later merge
// knows the file already matches the current template.
//
// Used where the whole file is written rather than merged: the first run, and
// --force-pyproject.
func RenderTemplate(args []string) {
	fs := flag.NewFlagSet("render-template", flag.ExitOnError)
	repo := fs.String("repo", "", "value for {{REPO}}")
	owner := fs.String("owner", "", "value for {{OWNER}}")
	version := fs.String("version", "", "repokit version; {{VERSION}} gets its major.minor")
	statePath := fs.String("state", "", "file to record template_hash in; empty to skip")
	out := fs.String("out", "", "file to write; empty for stdout")

	parse(fs, args, 1, "render-template --repo R [--owner O] [--version V] [--state F] [--out F] <template>")

	// Rendering before opening the output: a shell redirect would have
	// truncated the user's file before we knew whether we had anything to put
	// in it.
	rendered, err := template.RenderFile(fs.Arg(0), map[string]string{
		"REPO":    *repo,
		"OWNER":   *owner,
		"VERSION": template.MajorMinor(*version),
	})
	if err != nil {
		fail("error reading template: %v", err)
	}

	if *out == "" {
		fmt.Print(rendered)
	} else if err := os.WriteFile(*out, []byte(rendered), 0o644); err != nil {
		fail("error writing %s: %v", *out, err)
	}

	if *statePath == "" {
		return
	}

	if err := config.Set(*statePath, "template_hash", template.Hash(rendered)); err != nil {
		fail("error writing %s: %v", *statePath, err)
	}
}
