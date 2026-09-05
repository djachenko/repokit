// Package pyproject merges repokit's pyproject.toml template into a repo's own
// file, updating what repokit manages and leaving everything else alone.
//
// The merge edits the file's text through a lossless AST rather than parsing it
// into a tree and serialising that tree back out. The difference is the whole
// feature: a tree keeps no record of how the file was written, so writing one
// back reformats every line it touches and plenty it does not — and, on this
// project's own template, produced a file no TOML parser would read back.
package pyproject

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"reflect"
	"strings"

	tomledit "github.com/smm-h/go-toml-edit"
)

// Merger carries the decision of how to resolve a conflicting value.
// It is explicit state rather than package globals so that tests can construct
// one per case instead of mutating shared variables and restoring them after.
type Merger struct {
	// Interactive asks before overwriting a differing value. When false every
	// conflict keeps the current value and is reported on Prompts.
	Interactive bool
	// Answers supplies the replies to conflict prompts; defaults to stdin.
	Answers io.Reader
	// Prompts receives the questions and conflict reports; defaults to stderr.
	Prompts io.Writer
}

// MergeText merges tmpl into base and returns the updated base document:
//   - values identical: nothing is written
//   - values differ: ask, or keep base when not interactive
//   - keys only base has: never visited
//   - keys only tmpl has: added, creating their table if needed
//
// Text in, text out. The promise this feature makes is "leave alone what
// repokit did not change", and that promise is about the user's bytes, so only
// a signature that owns them can be held to it.
func (m *Merger) MergeText(base, tmpl string) (string, error) {
	baseDoc, err := tomledit.Parse([]byte(base))
	if err != nil {
		return "", fmt.Errorf("parsing target: %w", err)
	}

	tmplDoc, err := tomledit.Parse([]byte(tmpl))
	if err != nil {
		return "", fmt.Errorf("parsing template: %w", err)
	}

	created, err := m.merge(baseDoc, tmplDoc)
	if err != nil {
		return "", err
	}

	return separate(string(baseDoc.Bytes()), created), nil
}

// merge returns the tables it had to create, so their spacing can be fixed up
// once the document is back in text form.
func (m *Merger) merge(base, tmpl *tomledit.DocumentNode) ([]string, error) {
	var created []string

	for _, path := range valuePaths(tmpl) {
		tmplValue := plain(tmpl.Get(path))

		current := base.Get(path)
		if current == nil {
			table, err := add(base, path, tmplValue)
			if err != nil {
				return nil, fmt.Errorf("adding %s: %w", path, err)
			}

			if table != "" {
				created = append(created, table)
			}

			continue
		}

		baseValue := plain(current)
		if reflect.DeepEqual(baseValue, tmplValue) {
			continue
		}

		if m.takeTemplate(path, baseValue, tmplValue) {
			if err := base.Set(path, tmplValue); err != nil {
				return nil, fmt.Errorf("setting %s: %w", path, err)
			}
		}
	}

	return created, nil
}

// valuePaths lists the paths the merge is allowed to decide about: every value
// in the template, with arrays and inline tables counted as one value each.
//
// WalkAll yields a container before its children, so skipping anything nested
// under a path already collected is what keeps `authors = [{ name = ... }]` a
// single decision instead of one decision per element inside it.
func valuePaths(doc *tomledit.DocumentNode) []string {
	var paths []string

	container := ""

	_ = doc.Walk(func(path string, _ tomledit.Node) error {
		if container != "" && nestedIn(container, path) {
			return nil
		}

		paths = append(paths, path)
		container = path

		return nil
	}, tomledit.WalkAll)

	return paths
}

func nestedIn(container, path string) bool {
	return strings.HasPrefix(path, container+".") || strings.HasPrefix(path, container+"[")
}

// add writes a key the target does not have yet and reports the table it had to
// create, if any.
//
// SetCreate alone is not enough: it refuses with "cannot create intermediate
// table under Table node" as soon as the key's own table is missing, which is
// exactly the case here — a template section the user's file has never had.
// NewTable takes the whole dotted path at once and invents no headers for the
// levels above it, so [tool.mypy] does not drag an empty [tool] in with it.
func add(doc *tomledit.DocumentNode, path string, value any) (created string, err error) {
	dot := strings.LastIndex(path, ".")

	if dot > 0 {
		if table := path[:dot]; doc.Get(table) == nil {
			if err := doc.NewTable(table); err != nil {
				return "", err
			}

			created = table
		}
	}

	return created, doc.SetCreate(path, value)
}

// separate puts a blank line before each named table header.
//
// A table NewTable appended lands flush against the section above it, which
// reads as a continuation of that section. Only the headers this merge created
// are touched: spacing the user chose elsewhere in the file is theirs.
func separate(doc string, tables []string) string {
	lines := strings.Split(doc, "\n")

	for _, table := range tables {
		header := "[" + table + "]"

		for i, line := range lines {
			if line != header || i == 0 || lines[i-1] == "" {
				continue
			}

			lines = append(lines[:i], append([]string{""}, lines[i:]...)...)

			break
		}
	}

	return strings.Join(lines, "\n")
}

// plain converts a node to the ordinary Go value it stands for, so that two
// documents can be compared by what they say rather than by how they say it.
//
// Node.Value returns child nodes for containers, and those are distinct
// pointers in every parsed document — comparing them directly would report a
// conflict on every array in the file.
func plain(node tomledit.Node) any {
	switch n := node.(type) {
	case *tomledit.KeyValueNode:
		return plain(n.Val)

	case *tomledit.InlineTableNode:
		out := make(map[string]any, len(n.Children))

		for _, child := range n.Children {
			if kv, ok := child.(*tomledit.KeyValueNode); ok {
				out[strings.Join(kv.Key.Parts, ".")] = plain(kv.Val)
			}
		}

		return out
	}

	if children, ok := node.Value().([]tomledit.Node); ok {
		out := make([]any, len(children))

		for i, child := range children {
			out[i] = plain(child)
		}

		return out
	}

	return node.Value()
}

// takeTemplate asks whether to replace the current value with the template's.
func (m *Merger) takeTemplate(key string, current, template any) bool {
	out := m.prompts()

	if !m.Interactive {
		fmt.Fprintf(out, "conflict: %s (keeping current)\n", key)

		return false
	}

	fmt.Fprintf(out, "\nconflict: %s\n", key)
	fmt.Fprintf(out, "  current:  %v\n", current)
	fmt.Fprintf(out, "  template: %v\n", template)

	answers := bufio.NewReader(m.answers())

	for {
		fmt.Fprint(out, "keep current [k] / take template [t]: ")

		input, err := answers.ReadString('\n')

		switch strings.TrimSpace(strings.ToLower(input)) {
		case "k", "":
			return false
		case "t":
			return true
		}

		// A closed input would otherwise spin this loop forever.
		if err != nil {
			return false
		}
	}
}

func (m *Merger) prompts() io.Writer {
	if m.Prompts != nil {
		return m.Prompts
	}

	return os.Stderr
}

func (m *Merger) answers() io.Reader {
	if m.Answers != nil {
		return m.Answers
	}

	return os.Stdin
}
