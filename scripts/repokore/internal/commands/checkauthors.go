package commands

import (
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/djachenko/repokit/repokore/internal/authors"
)

// CheckAuthors serves the pre-push hook. The hook keeps the git calls and the
// prompt on /dev/tty; the parsing and the comparison happen here.
func CheckAuthors(args []string) {
	if len(args) == 0 {
		fail("usage: repokore check-authors <ranges|filter> ...")
	}

	switch args[0] {
	case "ranges":
		authorRanges(args[1:])
	case "filter":
		authorFilter(args[1:])
	default:
		fail("unknown check-authors operation: %s", args[0])
	}
}

// authorRanges turns the pre-push protocol on stdin into one rev-list argument
// list per line, tab separated so the caller can read it straight into an array
// instead of relying on word splitting.
func authorRanges(args []string) {
	fs := flag.NewFlagSet("check-authors ranges", flag.ExitOnError)

	parse(fs, args, 0, "check-authors ranges < pre-push-protocol")

	pushes, err := authors.ParsePush(os.Stdin)
	if err != nil {
		fail("error reading pre-push input: %v", err)
	}

	for _, push := range pushes {
		if rng := push.Range(); rng != nil {
			fmt.Println(strings.Join(rng, "\t"))
		}
	}
}

// authorFilter reads git log lines on stdin and prints only the commits whose
// author is not allowed, as hash, email and subject separated by tabs.
//
// Empty output means every author was expected — the hook has nothing to ask
// about.
func authorFilter(args []string) {
	fs := flag.NewFlagSet("check-authors filter", flag.ExitOnError)

	var allowed stringList

	fs.Var(&allowed, "allowed", "an accepted author email; repeatable")

	parse(fs, args, 0, "check-authors filter [--allowed EMAIL]... < git-log")

	commits, err := authors.ParseLog(os.Stdin)
	if err != nil {
		fail("error reading git log: %v", err)
	}

	for _, commit := range authors.Offenders(commits, allowed) {
		fmt.Printf("%s\t%s\t%s\n", commit.Hash, commit.Email, commit.Subject)
	}
}

// stringList collects a flag given more than once.
type stringList []string

func (l *stringList) String() string { return strings.Join(*l, ",") }

func (l *stringList) Set(value string) error {
	*l = append(*l, value)

	return nil
}
