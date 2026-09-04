package main

import (
	"fmt"
	"os"

	"github.com/djachenko/repokit/repokore/internal/commands"
)

// repokore owns the structural work bash can't do safely: parsing config
// formats, generating JSON, diffing structured files. Bash stays the glue
// around git and gh.
//
// It runs on the machine of whoever installed repokit — installation and repo
// setup. Work that happens on a CI runner is not its job: a runner has no
// repokit install, so reaching for repokore there would mean downloading a
// binary per run, where fetching a script and running it is cheaper.
//
// Each command is one line in the switch; its logic lives in internal/, one
// package per concern, so the tree stays readable as commands are added.
func main() {
	if len(os.Args) < 2 {
		usage()
	}

	args := os.Args[2:]

	switch os.Args[1] {
	case "merge-pyproject":
		commands.MergePyproject(args)
	case "render-template":
		commands.RenderTemplate(args)
	case "config":
		commands.Config(args)
	case "ruleset-checks":
		commands.RulesetChecks(args)
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n\n", os.Args[1])
		usage()
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: repokore <command> [args]")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "commands:")
	fmt.Fprintln(os.Stderr, "  merge-pyproject [--non-interactive] --repo R --owner O [--state F] <template> <target>")
	fmt.Fprintln(os.Stderr, "  render-template --repo R [--owner O] [--version V] [--state F] [--out F] <template>")
	fmt.Fprintln(os.Stderr, "  config get [--file F] <key>")
	fmt.Fprintln(os.Stderr, "  config set [--file F] <key> <value>")
	fmt.Fprintln(os.Stderr, "  ruleset-checks [--reusable DIR] <workflow.yml>...")
	os.Exit(1)
}
