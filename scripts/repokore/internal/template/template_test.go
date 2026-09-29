package template

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestRender(t *testing.T) {
	out := Render("repo: {{REPO}}, owner: {{OWNER}}", map[string]string{
		"REPO":  "myproject",
		"OWNER": "djachenko",
	})

	assert.Equal(t, "repo: myproject, owner: djachenko", out)
}

func TestRender_EveryOccurrence(t *testing.T) {
	out := Render("{{REPO}}/{{REPO}}", map[string]string{"REPO": "x"})

	assert.Equal(t, "x/x", out)
}

func TestRender_UnknownPlaceholderUntouched(t *testing.T) {
	out := Render("{{REPO}} {{VERSION}}", map[string]string{"REPO": "x"})

	assert.Equal(t, "x {{VERSION}}", out)
}

// The sed version this replaces used / as its delimiter, so a value containing
// one produced "unknown option to `s'" instead of a substitution.
func TestRender_ValueWithSlash(t *testing.T) {
	out := Render("{{PATH}}", map[string]string{"PATH": "a/b/c"})

	assert.Equal(t, "a/b/c", out)
}

// In sed's replacement text & means "the whole match", so an ampersand in a
// value silently duplicated the placeholder.
func TestRender_ValueWithAmpersand(t *testing.T) {
	out := Render("{{NAME}}", map[string]string{"NAME": "a&b"})

	assert.Equal(t, "a&b", out)
}

func TestRender_ValueWithBackslash(t *testing.T) {
	out := Render("{{NAME}}", map[string]string{"NAME": `a\1b`})

	assert.Equal(t, `a\1b`, out)
}

// A value that looks like a placeholder is inserted, not re-expanded.
func TestRender_NoRecursiveExpansion(t *testing.T) {
	out := Render("{{A}}", map[string]string{"A": "{{B}}", "B": "boom"})

	assert.Equal(t, "{{B}}", out)
}

func TestHash_StableAndDistinct(t *testing.T) {
	assert.Equal(t, Hash("same"), Hash("same"))
	assert.NotEqual(t, Hash("same"), Hash("other"))
}

func TestMajorMinor(t *testing.T) {
	assert.Equal(t, "0.9", MajorMinor("0.9.8"))
	assert.Equal(t, "1.10", MajorMinor("1.10.0"))

	// Not a version: a ref that is already what workflows should pin to.
	assert.Equal(t, "master", MajorMinor("master"))
	assert.Equal(t, "0.9", MajorMinor("0.9"))
}
