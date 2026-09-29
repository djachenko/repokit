package pyproject

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/pmezard/go-difflib/difflib"
	"github.com/stretchr/testify/require"

	"github.com/djachenko/repokit/repokore/internal/template"
)

// Byte-level tests.
//
// The tests in merge_test.go read the result back through the tree API, which
// is exactly where this feature's real defect hides: every one of them passes
// while the merge rewrites 26 of the 46 lines of the user's file. TOML
// equivalence is not the contract — "we touched only what we changed" is, and
// that can only be checked against bytes.
//
// The fixture is the shipped template rather than a copy under testdata, so a
// change to the template is exercised here instead of silently drifting away
// from a stand-in.

// templateFixture renders the real languages/python/pyproject.toml.
func templateFixture(t *testing.T) string {
	t.Helper()

	path := filepath.Join("..", "..", "..", "..", "languages", "python", "pyproject.toml")

	rendered, err := template.RenderFile(path, map[string]string{
		"REPO":  "myproject",
		"OWNER": "djachenko",
	})
	require.NoError(t, err, "shipped template must be readable from the module")

	return rendered
}

// diffLines reports how many lines the merge added and removed, plus a unified
// diff for the failure message. Counting through a real line diff rather than
// position by position keeps an inserted line from being reported as every
// following line having changed.
func diffLines(t *testing.T, want, got string) (added, removed int, unified string) {
	t.Helper()

	a := difflib.SplitLines(want)
	b := difflib.SplitLines(got)

	for _, op := range difflib.NewMatcher(a, b).GetOpCodes() {
		if op.Tag == 'e' {
			continue
		}

		removed += op.I2 - op.I1
		added += op.J2 - op.J1
	}

	unified, err := difflib.GetUnifiedDiffString(difflib.UnifiedDiff{
		A: a, B: b, FromFile: "before", ToFile: "after", Context: 2,
	})
	require.NoError(t, err)

	return added, removed, unified
}

func requireDiff(t *testing.T, want, got string, wantAdded, wantRemoved int) {
	t.Helper()

	added, removed, unified := diffLines(t, want, got)
	if added == wantAdded && removed == wantRemoved {
		return
	}

	t.Fatalf("expected +%d/-%d lines, got +%d/-%d\n%s",
		wantAdded, wantRemoved, added, removed, unified)
}

// The merge's own no-op: same content on both sides, nothing to decide. The
// file must come back exactly as it went in, down to the byte.
func TestMergeText_Unchanged_IsByteIdentical(t *testing.T) {
	src := templateFixture(t)

	got, err := quiet().MergeText(src, src)
	require.NoError(t, err)

	requireDiff(t, src, got, 0, 0)
}

// Taking one value from the template is a one-line edit. Everything else in the
// file is untouched, including the parts TOML lets you write more than one way.
func TestMergeText_SingleValueTaken_ChangesOneLine(t *testing.T) {
	tmpl := templateFixture(t)
	base := strings.Replace(tmpl,
		`requires-python = ">=3.10"`,
		`requires-python = ">=3.11"`, 1)
	require.NotEqual(t, tmpl, base, "fixture must actually differ")

	got, err := answering("t\n").MergeText(base, tmpl)
	require.NoError(t, err)

	requireDiff(t, base, got, 1, 1)
}

// Keeping the current value decides nothing, so it must write nothing.
func TestMergeText_ConflictKept_IsByteIdentical(t *testing.T) {
	tmpl := templateFixture(t)
	base := strings.Replace(tmpl,
		`requires-python = ">=3.10"`,
		`requires-python = ">=3.11"`, 1)

	got, err := quiet().MergeText(base, tmpl)
	require.NoError(t, err)

	requireDiff(t, base, got, 0, 0)
}

// The user's own additions are the whole reason this feature exists. A section
// and a multi-line array the template knows nothing about must survive as
// written — not reflowed, not relocated.
func TestMergeText_UserContent_SurvivesVerbatim(t *testing.T) {
	tmpl := templateFixture(t)

	addition := `
[tool.ruff]
line-length = 100
select = [
    "E",
    "F",
]
`
	base := tmpl + addition

	got, err := quiet().MergeText(base, tmpl)
	require.NoError(t, err)

	require.Contains(t, got, addition, "user section must appear verbatim")
	requireDiff(t, base, got, 0, 0)
}

// A key only the template has is the one thing the merge is allowed to write.
func TestMergeText_NewTemplateKey_AddedInPlace(t *testing.T) {
	tmpl := templateFixture(t)
	base := strings.Replace(tmpl, "\n[tool.mypy]\nstrict = true\n", "\n", 1)
	require.NotEqual(t, tmpl, base, "fixture must actually differ")

	got, err := quiet().MergeText(base, tmpl)
	require.NoError(t, err)

	require.Contains(t, got, "\n\n[tool.mypy]\nstrict = true\n")
	// A blank line, the section header and its key. Nothing is removed: the
	// merge writes only what the target was missing.
	requireDiff(t, base, got, 3, 0)
}

// Reading the file back must not depend on the merge having run: a target the
// merge left alone is still the same document to the next run.
func TestMergeText_Idempotent(t *testing.T) {
	src := templateFixture(t)

	once, err := quiet().MergeText(src, src)
	require.NoError(t, err)

	twice, err := quiet().MergeText(once, src)
	require.NoError(t, err)

	requireDiff(t, once, twice, 0, 0)
}

// The fixture is the shipped template, so a placeholder left unrendered would
// quietly weaken every test above.
func TestTemplateFixture_HasNoPlaceholdersLeft(t *testing.T) {
	src := templateFixture(t)

	require.NotContains(t, src, "{{")
	require.Contains(t, src, `name = "myproject"`)
}
