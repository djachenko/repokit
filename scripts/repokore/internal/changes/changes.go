// Package changes groups a working tree's modified files into one commit per
// area, the way the dotfiles watcher wants to record them.
//
// It replaces the most awk-dense code in the project: one pass to derive the
// group keys, a second per key to select that group's files, and a third per
// file to pull the status letters back out of the porcelain line.
package changes

import (
	"fmt"
	"io"
	"path"
	"sort"
	"strings"
)

// Change is one entry of `git status --porcelain -z`.
type Change struct {
	// Status is the two-letter XY code.
	Status string
	Path   string
}

// Group is the set of changes that will become one commit.
type Group struct {
	// Key is the directory the commit is named after: the first two path
	// segments for a deep path, the first for a top-level directory, "." for a
	// file at the root.
	Key     string
	Changes []Change
}

// Parse reads `git status --porcelain -z`: NUL-separated entries, each a
// two-letter status, a space, and the path as-is.
//
// -z rather than plain porcelain because without it git quotes any path with
// non-ASCII bytes and escapes them in octal — "\320\277…" for a Cyrillic name —
// and that string names no file `git add` can find.
//
// A rename or copy takes two entries under -z: the new path in the entry
// itself, then the old path as a bare entry of its own. Only the new one is
// kept; the old one is gone from the tree and has nothing to stage.
func Parse(r io.Reader) ([]Change, error) {
	data, err := io.ReadAll(r)
	if err != nil {
		return nil, err
	}

	var changes []Change

	entries := strings.Split(string(data), "\x00")

	for i := 0; i < len(entries); i++ {
		entry := entries[i]
		if len(entry) < 4 {
			// The trailing NUL leaves an empty last element.
			continue
		}

		change := Change{Status: entry[:2], Path: entry[3:]}
		changes = append(changes, change)

		if strings.ContainsAny(change.Status, "RC") {
			i++
		}
	}

	return changes, nil
}

// Group buckets changes by area, ordered by key so repeated runs commit in the
// same order.
func Groups(changes []Change) []Group {
	byKey := map[string][]Change{}

	for _, change := range changes {
		key := key(change.Path)
		byKey[key] = append(byKey[key], change)
	}

	keys := make([]string, 0, len(byKey))
	for key := range byKey {
		keys = append(keys, key)
	}

	sort.Strings(keys)

	groups := make([]Group, 0, len(keys))
	for _, key := range keys {
		groups = append(groups, Group{Key: key, Changes: byKey[key]})
	}

	return groups
}

// Find returns the group with the given key.
func Find(groups []Group, key string) (Group, bool) {
	for _, group := range groups {
		if group.Key == key {
			return group, true
		}
	}

	return Group{}, false
}

func key(p string) string {
	parts := strings.Split(p, "/")

	switch len(parts) {
	case 1:
		return "."
	case 2:
		return parts[0]
	default:
		return parts[0] + "/" + parts[1]
	}
}

// Message is the commit message for a group: a subject naming the area and how
// much changed, then one line per file marked with what happened to it.
func (g Group) Message() string {
	noun := "files"
	if len(g.Changes) == 1 {
		noun = "file"
	}

	lines := make([]string, 0, len(g.Changes))
	for _, change := range g.Changes {
		lines = append(lines, fmt.Sprintf("%s %s", symbol(change.Status), path.Base(change.Path)))
	}

	sort.Strings(lines)

	return fmt.Sprintf("auto: %s (%d %s)\n\n%s\n", g.Key, len(g.Changes), noun, strings.Join(lines, "\n"))
}

// symbol condenses the porcelain status to what a reader of the message cares
// about: added, removed, or changed.
//
// Both columns are examined, not just the first. The status is "<index><tree>",
// so a file deleted but not yet staged reads " D" — and the bash version, which
// tested only the first character, showed every such deletion as a plain change.
// The letter is what matters here, not which side of the index it came from.
func symbol(status string) string {
	if strings.ContainsAny(status, "?A") {
		return "+"
	}

	if strings.ContainsRune(status, 'D') {
		return "-"
	}

	return "~"
}
