package commands

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"github.com/djachenko/repokit/repokore/internal/workflow"
)

// context is one entry of a ruleset's required_status_checks.
type context struct {
	Context string `json:"context"`
}

// RulesetChecks prints the required_status_checks array for a repo's ruleset,
// derived from the workflows that actually run on a pull request.
//
// The context GitHub reports for a job that calls a reusable workflow is
// "<caller job> / <terminal job of the callee>", so the callee has to be read
// too — that is what --reusable points at.
func RulesetChecks(args []string) {
	fs := flag.NewFlagSet("ruleset-checks", flag.ExitOnError)
	reusableDir := fs.String("reusable", "", "directory holding the reusable workflows being called")

	if err := fs.Parse(args); err != nil {
		os.Exit(1)
	}

	if fs.NArg() == 0 {
		fmt.Fprintln(os.Stderr, "usage: repokore ruleset-checks [--reusable DIR] <workflow.yml>...")
		os.Exit(1)
	}

	var contexts []context

	for _, path := range fs.Args() {
		// A wrapper the language does not ship is not an error: dotfiles has no
		// CI at all, and the ruleset simply requires nothing from it.
		src, err := os.ReadFile(path)
		if os.IsNotExist(err) {
			continue
		}

		if err != nil {
			fail("error reading %s: %v", path, err)
		}

		jobs, err := workflow.Jobs(src)
		if err != nil {
			fail("error parsing %s: %v", path, err)
		}

		for _, job := range jobs {
			contexts = append(contexts, context{Context: checkContext(job, *reusableDir)})
		}
	}

	if len(contexts) == 0 {
		fmt.Fprintln(os.Stderr, "  warn: no required status checks derived from the given workflows")

		contexts = []context{}
	}

	// Encoded rather than concatenated: a job id with a quote in it used to
	// produce a broken request body that the API rejected with no useful
	// explanation.
	encoded, err := json.Marshal(contexts)
	if err != nil {
		fail("error encoding contexts: %v", err)
	}

	fmt.Println(string(encoded))
}

func checkContext(job workflow.Job, reusableDir string) string {
	if job.Uses == "" {
		return job.ID
	}

	name := workflow.ReusableName(job.Uses)

	src, err := os.ReadFile(filepath.Join(reusableDir, name))
	if err != nil {
		fmt.Fprintf(os.Stderr, "  warn: reusable workflow %s not found, using %q as the check context\n", name, job.ID)

		return job.ID
	}

	terminal, err := workflow.Terminal(src)
	if err != nil {
		fail("error resolving terminal job of %s: %v", name, err)
	}

	return job.ID + " / " + terminal
}
