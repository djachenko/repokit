package main

import (
	"bufio"
	"bytes"
	"os"
	"strings"
	"testing"

	"github.com/pelletier/go-toml"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func load(t *testing.T, s string) *toml.Tree {
	t.Helper()
	tree, err := toml.Load(s)
	require.NoError(t, err)
	return tree
}

func dump(t *testing.T, tree *toml.Tree) string {
	t.Helper()
	s, err := tree.ToTomlString()
	require.NoError(t, err)
	return s
}

// ── qualifiedKey ──────────────────────────────────────────────────────────────

func TestQualifiedKey(t *testing.T) {
	assert.Equal(t, "name", qualifiedKey("", "name"))
	assert.Equal(t, "project.name", qualifiedKey("project", "name"))
	assert.Equal(t, "a.b.c", qualifiedKey("a.b", "c"))
}

// ── merge: identical values ───────────────────────────────────────────────────

func TestMerge_IdenticalValues_NoChange(t *testing.T) {
	base := load(t, `name = "myproject"`)
	tmpl := load(t, `name = "myproject"`)

	merge(base, tmpl, "")

	assert.Equal(t, "myproject", base.Get("name"))
}

// ── merge: template updates base value ───────────────────────────────────────

func TestMerge_Conflict_NonInteractive_KeepsCurrent(t *testing.T) {
	interactive = false
	defer func() { interactive = true }()

	base := load(t, `requires-python = ">=3.11"`)
	tmpl := load(t, `requires-python = ">=3.10"`)

	merge(base, tmpl, "")

	assert.Equal(t, ">=3.11", base.Get("requires-python"))
}

func TestMerge_Conflict_Interactive_TakeTemplate(t *testing.T) {
	interactive = true
	stdin = bufio.NewReader(strings.NewReader("t\n"))
	defer func() {
		interactive = true
		stdin = bufio.NewReader(os.Stdin)
	}()

	base := load(t, `requires-python = ">=3.11"`)
	tmpl := load(t, `requires-python = ">=3.10"`)

	merge(base, tmpl, "")

	assert.Equal(t, ">=3.10", base.Get("requires-python"))
}

func TestMerge_Conflict_Interactive_KeepCurrent(t *testing.T) {
	interactive = true
	stdin = bufio.NewReader(strings.NewReader("k\n"))
	defer func() {
		interactive = true
		stdin = bufio.NewReader(os.Stdin)
	}()

	base := load(t, `requires-python = ">=3.11"`)
	tmpl := load(t, `requires-python = ">=3.10"`)

	merge(base, tmpl, "")

	assert.Equal(t, ">=3.11", base.Get("requires-python"))
}

// ── merge: user-only keys ─────────────────────────────────────────────────────

func TestMerge_UserOnlyKey_Preserved(t *testing.T) {
	base := load(t, `
name = "myproject"
dependencies = ["requests"]
`)
	tmpl := load(t, `name = "myproject"`)

	merge(base, tmpl, "")

	assert.Equal(t, []interface{}{"requests"}, base.Get("dependencies"))
}

// ── merge: new template keys ──────────────────────────────────────────────────

func TestMerge_NewTemplateKey_Appended(t *testing.T) {
	base := load(t, `name = "myproject"`)
	tmpl := load(t, `
name = "myproject"
license = "MIT"
`)

	merge(base, tmpl, "")

	assert.Equal(t, "MIT", base.Get("license"))
}

// ── merge: nested tables ──────────────────────────────────────────────────────

func TestMerge_NestedTable_UpdatesTemplateKey(t *testing.T) {
	interactive = false
	defer func() { interactive = true }()

	base := load(t, `
[project]
name = "myproject"
requires-python = ">=3.11"
dependencies = ["requests"]
`)
	tmpl := load(t, `
[project]
name = "myproject"
requires-python = ">=3.10"
`)

	merge(base, tmpl, "")

	project := base.Get("project").(*toml.Tree)
	assert.Equal(t, ">=3.11", project.Get("requires-python"))
	assert.Equal(t, []interface{}{"requests"}, project.Get("dependencies"))
}

func TestMerge_NestedTable_NewKeyAppended(t *testing.T) {
	base := load(t, `
[project]
name = "myproject"
`)
	tmpl := load(t, `
[project]
name = "myproject"
license = "MIT"
`)

	merge(base, tmpl, "")

	project := base.Get("project").(*toml.Tree)
	assert.Equal(t, "MIT", project.Get("license"))
}

// ── merge: key order ──────────────────────────────────────────────────────────

// Order is asserted on the serialised output, not on Keys(): the tree stores
// values in a map, so Keys() returns them in Go's randomised map order and says
// nothing about what lands in the file.
func TestMerge_UserKeyOrder_Preserved(t *testing.T) {
	base := load(t, `
name = "myproject"
dependencies = ["requests"]
version = "1.0.0"
`)
	tmpl := load(t, `
name = "myproject"
version = "1.0.0"
`)

	merge(base, tmpl, "")

	var buf bytes.Buffer
	require.NoError(t, writeTOML(&buf, base))
	out := buf.String()

	assert.Less(t, strings.Index(out, "name"), strings.Index(out, "dependencies"))
	assert.Less(t, strings.Index(out, "dependencies"), strings.Index(out, "version"))
}

// A key only the template has is appended after the user's own keys.
func TestMerge_TemplateOnlyKey_AppendedLast(t *testing.T) {
	base := load(t, `
name = "myproject"
dependencies = ["requests"]
`)
	tmpl := load(t, `
name = "myproject"
license = "MIT"
`)

	merge(base, tmpl, "")

	var buf bytes.Buffer
	require.NoError(t, writeTOML(&buf, base))
	out := buf.String()

	assert.Less(t, strings.Index(out, "dependencies"), strings.Index(out, "license"))
}
