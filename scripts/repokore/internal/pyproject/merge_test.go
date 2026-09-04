package pyproject

import (
	"bytes"
	"strings"
	"testing"

	tomledit "github.com/smm-h/go-toml-edit"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// quiet merges without asking, keeping the current value on every conflict.
func quiet() *Merger {
	return &Merger{Prompts: &bytes.Buffer{}}
}

// answering merges interactively, replying with the given input.
func answering(reply string) *Merger {
	return &Merger{
		Interactive: true,
		Answers:     strings.NewReader(reply),
		Prompts:     &bytes.Buffer{},
	}
}

func parse(t *testing.T, src string) *tomledit.DocumentNode {
	t.Helper()

	doc, err := tomledit.Parse([]byte(src))
	require.NoError(t, err)

	return doc
}

func merged(t *testing.T, m *Merger, base, tmpl string) string {
	t.Helper()

	out, err := m.MergeText(base, tmpl)
	require.NoError(t, err)

	return out
}

// ── internals ─────────────────────────────────────────────────────────────────

func TestNestedIn(t *testing.T) {
	assert.True(t, nestedIn("project.authors", "project.authors[0]"))
	assert.True(t, nestedIn("project.authors", "project.authors[0].name"))
	assert.True(t, nestedIn("tool.mypy", "tool.mypy.strict"))

	// A shared prefix is not containment: these are siblings.
	assert.False(t, nestedIn("project.name", "project.namespace"))
	assert.False(t, nestedIn("project.authors", "project.author"))
}

// An array counts as one value, so the merge asks about it once instead of once
// per element.
func TestValuePaths_TreatsContainersAsOneValue(t *testing.T) {
	doc := parse(t, `
[project]
name = "myproject"
authors = [{ name = "Igor" }]
keywords = ["a", "b"]
`)

	assert.Equal(t,
		[]string{"project.name", "project.authors", "project.keywords"},
		valuePaths(doc))
}

// Values must compare by what they say: two parses of the same array hold
// different nodes, and comparing those would make every array a conflict.
func TestPlain_ComparesAcrossDocuments(t *testing.T) {
	a := parse(t, `v = [{ name = "Igor" }, 1, true]`)
	b := parse(t, `v = [{ name = "Igor" }, 1, true]`)

	assert.Equal(t, plain(a.Get("v")), plain(b.Get("v")))
}

// ── conflicts ─────────────────────────────────────────────────────────────────

func TestMerge_IdenticalValues_NoChange(t *testing.T) {
	src := `name = "myproject"` + "\n"

	assert.Equal(t, src, merged(t, quiet(), src, src))
}

func TestMerge_Conflict_NonInteractive_KeepsCurrent(t *testing.T) {
	out := merged(t, quiet(), `requires-python = ">=3.11"`, `requires-python = ">=3.10"`)

	assert.Contains(t, out, `">=3.11"`)
}

func TestMerge_Conflict_Interactive_TakeTemplate(t *testing.T) {
	out := merged(t, answering("t\n"), `requires-python = ">=3.11"`, `requires-python = ">=3.10"`)

	assert.Contains(t, out, `">=3.10"`)
}

func TestMerge_Conflict_Interactive_KeepCurrent(t *testing.T) {
	out := merged(t, answering("k\n"), `requires-python = ">=3.11"`, `requires-python = ">=3.10"`)

	assert.Contains(t, out, `">=3.11"`)
}

// Empty input means "keep", which is what pressing Enter sends.
func TestMerge_Conflict_Interactive_EmptyAnswerKeeps(t *testing.T) {
	out := merged(t, answering("\n"), `requires-python = ">=3.11"`, `requires-python = ">=3.10"`)

	assert.Contains(t, out, `">=3.11"`)
}

// An unreadable answer must not spin the prompt loop forever.
func TestMerge_Conflict_Interactive_ClosedInputKeeps(t *testing.T) {
	out := merged(t, answering(""), `requires-python = ">=3.11"`, `requires-python = ">=3.10"`)

	assert.Contains(t, out, `">=3.11"`)
}

// An unrecognised reply re-asks rather than guessing.
func TestMerge_Conflict_Interactive_RepromptsOnGarbage(t *testing.T) {
	out := merged(t, answering("what\nt\n"), `requires-python = ">=3.11"`, `requires-python = ">=3.10"`)

	assert.Contains(t, out, `">=3.10"`)
}

// ── keys present on one side only ─────────────────────────────────────────────

func TestMerge_UserOnlyKey_Preserved(t *testing.T) {
	base := "name = \"myproject\"\ndependencies = [\"requests\"]\n"

	out := merged(t, quiet(), base, `name = "myproject"`)

	assert.Equal(t, base, out)
}

func TestMerge_NewTemplateKey_Added(t *testing.T) {
	out := merged(t, quiet(), "name = \"myproject\"\n", "name = \"myproject\"\nlicense = \"MIT\"\n")

	assert.Contains(t, out, `license = "MIT"`)
}

// ── nested tables ─────────────────────────────────────────────────────────────

func TestMerge_NestedTable_KeepsUserKeysAndValues(t *testing.T) {
	base := `[project]
name = "myproject"
requires-python = ">=3.11"
dependencies = ["requests"]
`

	out := merged(t, quiet(), base, "[project]\nname = \"myproject\"\nrequires-python = \">=3.10\"\n")

	assert.Equal(t, base, out)
}

func TestMerge_NestedTable_NewKeyAdded(t *testing.T) {
	out := merged(t, quiet(),
		"[project]\nname = \"myproject\"\n",
		"[project]\nname = \"myproject\"\nlicense = \"MIT\"\n")

	assert.Contains(t, out, `license = "MIT"`)
}

// A section the target has never had is created rather than skipped: SetCreate
// alone refuses when the key's own table is missing.
func TestMerge_MissingTable_Created(t *testing.T) {
	out := merged(t, quiet(),
		"[project]\nname = \"myproject\"\n",
		"[project]\nname = \"myproject\"\n\n[tool.mypy]\nstrict = true\n")

	assert.Contains(t, out, "[tool.mypy]")
	assert.Contains(t, out, "strict = true")
}

// A created section is a section, not a continuation of the one above it.
func TestMerge_CreatedTable_HasBlankLineBefore(t *testing.T) {
	out := merged(t, quiet(),
		"[project]\nname = \"myproject\"\n",
		"[project]\nname = \"myproject\"\n\n[tool.mypy]\nstrict = true\n")

	assert.Contains(t, out, "\n\n[tool.mypy]\n")
}

// Only the levels the template actually names get a header — the empty [tool]
// and [tool.hatch] headers the old tree-based merge invented are the bug this
// guards against.
func TestMerge_MissingTable_InventsNoParentHeaders(t *testing.T) {
	out := merged(t, quiet(),
		"[project]\nname = \"myproject\"\n",
		"[project]\nname = \"myproject\"\n\n[tool.hatch.build.targets.wheel]\npackages = [\"src/x\"]\n")

	assert.Contains(t, out, "[tool.hatch.build.targets.wheel]")

	for _, orphan := range []string{"[tool]", "[tool.hatch]", "[tool.hatch.build]", "[tool.hatch.build.targets]"} {
		assert.NotContains(t, out, "\n"+orphan+"\n", "invented an empty %s header", orphan)
	}
}

// Spacing the merge did not create is the user's own and stays as written.
func TestMerge_ExistingTightSpacing_LeftAlone(t *testing.T) {
	base := "[project]\nname = \"myproject\"\n[tool.ruff]\nline-length = 120\n"

	assert.Equal(t, base, merged(t, quiet(), base, "[project]\nname = \"myproject\"\n"))
}

// ── key order ─────────────────────────────────────────────────────────────────

func TestMerge_UserKeyOrder_Preserved(t *testing.T) {
	base := `name = "myproject"
dependencies = ["requests"]
version = "1.0.0"
`

	out := merged(t, quiet(), base, "name = \"myproject\"\nversion = \"1.0.0\"\n")

	assert.Equal(t, base, out)
}

// A key only the template has goes after the user's own keys, not before them.
func TestMerge_TemplateOnlyKey_AddedLast(t *testing.T) {
	out := merged(t, quiet(),
		"name = \"myproject\"\ndependencies = [\"requests\"]\n",
		"name = \"myproject\"\nlicense = \"MIT\"\n")

	assert.Less(t, strings.Index(out, "dependencies"), strings.Index(out, "license"))
}
