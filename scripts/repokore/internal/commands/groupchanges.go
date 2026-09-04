package commands

import (
	"flag"
	"fmt"
	"os"

	"github.com/djachenko/repokit/repokore/internal/changes"
)

// GroupChanges splits a working tree's changes into one commit per area.
//
// The three operations read the same status file rather than a pipe, because
// the caller needs to walk the groups and ask about each one in turn.
func GroupChanges(args []string) {
	if len(args) == 0 {
		fail("usage: repokore group-changes <keys|paths|message> --status F [--key K]")
	}

	fs := flag.NewFlagSet("group-changes "+args[0], flag.ExitOnError)
	status := fs.String("status", "", "file holding `git status --porcelain` output")
	key := fs.String("key", "", "group to report on")

	parse(fs, args[1:], 0, "group-changes <keys|paths|message> --status F [--key K]")

	if *status == "" {
		fail("--status is required")
	}

	f, err := os.Open(*status)
	if err != nil {
		fail("error reading %s: %v", *status, err)
	}

	defer f.Close()

	parsed, err := changes.Parse(f)
	if err != nil {
		fail("error parsing status: %v", err)
	}

	groups := changes.Groups(parsed)

	if args[0] == "keys" {
		for _, group := range groups {
			fmt.Println(group.Key)
		}

		return
	}

	group, ok := changes.Find(groups, *key)
	if !ok {
		fail("no such group: %s", *key)
	}

	switch args[0] {
	case "paths":
		for _, change := range group.Changes {
			fmt.Println(change.Path)
		}
	case "message":
		fmt.Print(group.Message())
	default:
		fail("unknown group-changes operation: %s", args[0])
	}
}
