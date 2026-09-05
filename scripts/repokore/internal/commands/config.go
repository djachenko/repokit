package commands

import (
	"flag"
	"fmt"

	"github.com/djachenko/repokit/repokore/internal/config"
)

// Config reads and writes fields in .repokit.
//
// Four bash sites did this with `grep '^key=' | cut -d= -f2` and a
// read-while-rewriting temp file dance; two of them had already drifted apart
// far enough to collide as a merge conflict. One implementation, one format.
func Config(args []string) {
	if len(args) == 0 {
		fail("usage: repokore config <get|set> ...")
	}

	switch args[0] {
	case "get":
		configGet(args[1:])
	case "set":
		configSet(args[1:])
	default:
		fail("unknown config operation: %s", args[0])
	}
}

// configGet prints the value, or nothing at all when the key or the file is
// absent — the same shape `grep | cut` had, so callers can keep using
// ${VAR:-default}.
func configGet(args []string) {
	fs := flag.NewFlagSet("config get", flag.ExitOnError)
	path := fs.String("file", ".repokit", "config file")

	parse(fs, args, 1, "config get [--file F] <key>")

	value, err := config.Get(*path, fs.Arg(0))
	if err != nil {
		fail("error reading %s: %v", *path, err)
	}

	fmt.Println(value)
}

func configSet(args []string) {
	fs := flag.NewFlagSet("config set", flag.ExitOnError)
	path := fs.String("file", ".repokit", "config file")

	parse(fs, args, 2, "config set [--file F] <key> <value>")

	if err := config.Set(*path, fs.Arg(0), fs.Arg(1)); err != nil {
		fail("error writing %s: %v", *path, err)
	}
}
