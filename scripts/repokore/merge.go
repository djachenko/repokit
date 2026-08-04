package main

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"os"
	"reflect"
	"strings"

	"github.com/pelletier/go-toml"
)

var (
	stdin       = bufio.NewReader(os.Stdin)
	interactive = true
)

// mergePyproject merges repokit's pyproject.toml template into the repo's own
// file, keeping user-only keys and asking before overwriting a differing value.
func mergePyproject(args []string) {
	fs := flag.NewFlagSet("merge-pyproject", flag.ExitOnError)
	nonInteractive := fs.Bool("non-interactive", false, "keep current value on all conflicts")

	if err := fs.Parse(args); err != nil {
		os.Exit(1)
	}

	if fs.NArg() != 2 {
		fmt.Fprintln(os.Stderr, "usage: repokore merge-pyproject [--non-interactive] <template> <target>")

		os.Exit(1)
	}

	interactive = !*nonInteractive
	tmplPath, targetPath := fs.Arg(0), fs.Arg(1)

	tmpl, err := toml.LoadFile(tmplPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error loading template: %v\n", err)
		os.Exit(1)
	}

	target, err := toml.LoadFile(targetPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error loading target: %v\n", err)
		os.Exit(1)
	}

	merge(target, tmpl, "")

	f, err := os.Create(targetPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error opening target for writing: %v\n", err)
		os.Exit(1)
	}
	defer f.Close()

	if err := writeTOML(f, target); err != nil {
		fmt.Fprintf(os.Stderr, "error writing TOML: %v\n", err)
		os.Exit(1)
	}
}

// writeTOML serialises tree keeping the key order of the original file.
// Without OrderPreserve the encoder sorts alphabetically, which would rewrite
// the user's whole pyproject.toml on every merge. Keys the merge added have no
// source position and land at the end of their section.
func writeTOML(w io.Writer, tree *toml.Tree) error {
	return toml.NewEncoder(w).Order(toml.OrderPreserve).Encode(tree)
}

// merge updates base in-place from tmpl:
// - values identical: skip
// - values differ: prompt user (or keep base in non-interactive mode)
// - user-only keys: untouched
// - template keys missing from base: appended at end of section
func merge(base, tmpl *toml.Tree, path string) {
	for _, key := range base.Keys() {
		if !tmpl.Has(key) {
			continue
		}

		baseVal := base.Get(key)
		tmplVal := tmpl.Get(key)

		baseTree, baseIsTree := baseVal.(*toml.Tree)
		tmplTree, tmplIsTree := tmplVal.(*toml.Tree)

		fullKey := qualifiedKey(path, key)

		if baseIsTree && tmplIsTree {
			merge(baseTree, tmplTree, fullKey)
		} else if !reflect.DeepEqual(baseVal, tmplVal) {
			if takeTemplate(fullKey, baseVal, tmplVal) {
				base.Set(key, tmplVal)
			}
		}
	}

	for _, key := range tmpl.Keys() {
		if !base.Has(key) {
			base.Set(key, tmpl.Get(key))
		}
	}
}

// takeTemplate asks the user whether to take the template value.
// In non-interactive mode always keeps the current value.
func takeTemplate(key string, current, template any) bool {
	if !interactive {
		fmt.Fprintf(os.Stderr, "conflict: %s (keeping current)\n", key)
		return false
	}

	fmt.Fprintf(os.Stderr, "\nconflict: %s\n", key)
	fmt.Fprintf(os.Stderr, "  current:  %v\n", current)
	fmt.Fprintf(os.Stderr, "  template: %v\n", template)

	for {
		fmt.Fprint(os.Stderr, "keep current [k] / take template [t]: ")

		input, _ := stdin.ReadString('\n')
		switch strings.TrimSpace(strings.ToLower(input)) {
		case "k", "":
			return false
		case "t":
			return true
		}
	}
}

func qualifiedKey(path, key string) string {
	if path == "" {
		return key
	}

	return path + "." + key
}
