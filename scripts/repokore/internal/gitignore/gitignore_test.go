package gitignore

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func file(t *testing.T, content string) string {
	t.Helper()

	path := filepath.Join(t.TempDir(), ".gitignore")
	require.NoError(t, os.WriteFile(path, []byte(content), 0o644))

	return path
}

func read(t *testing.T, path string) string {
	t.Helper()

	b, err := os.ReadFile(path)
	require.NoError(t, err)

	return string(b)
}

func add(t *testing.T, path string, patterns ...string) []string {
	t.Helper()

	added, err := Add(path, patterns)
	require.NoError(t, err)

	return added
}

func TestAdd_AppendsMissing(t *testing.T) {
	path := file(t, "build/\n")

	assert.Equal(t, []string{".repokit"}, add(t, path, ".repokit"))
	assert.Equal(t, "build/\n.repokit\n", read(t, path))
}

func TestAdd_SkipsPresent(t *testing.T) {
	path := file(t, "build/\n.repokit\n")

	assert.Empty(t, add(t, path, ".repokit"))
	assert.Equal(t, "build/\n.repokit\n", read(t, path))
}

// Whole-line and literal: "key" is not present just because "monkey.txt" is.
func TestAdd_MatchesWholeLinesOnly(t *testing.T) {
	path := file(t, "monkey.txt\n")

	assert.Equal(t, []string{"*.key"}, add(t, path, "*.key"))
}

// The bug this fixes: bash checked for a trailing newline in the branch that
// adds .repokit and not in the one that adds sensitive patterns, so the first
// pattern was glued onto the last line and matched nothing.
func TestAdd_UnterminatedFile_GetsNewlineFirst(t *testing.T) {
	path := file(t, "build/")

	add(t, path, ".env", "*.pem")

	assert.Equal(t, "build/\n.env\n*.pem\n", read(t, path))
}

func TestAdd_MissingFile_IsCreated(t *testing.T) {
	path := filepath.Join(t.TempDir(), ".gitignore")

	assert.Equal(t, []string{".repokit"}, add(t, path, ".repokit"))
	assert.Equal(t, ".repokit\n", read(t, path))
}

func TestAdd_EmptyFile_GetsNoLeadingBlankLine(t *testing.T) {
	path := file(t, "")

	add(t, path, ".repokit")

	assert.Equal(t, ".repokit\n", read(t, path))
}

func TestAdd_DeduplicatesWithinOneCall(t *testing.T) {
	path := file(t, "")

	assert.Equal(t, []string{".env"}, add(t, path, ".env", ".env"))
	assert.Equal(t, ".env\n", read(t, path))
}

// ── scanning ──────────────────────────────────────────────────────────────────

func TestMatching_OnlyPatternsWithHits(t *testing.T) {
	dir := t.TempDir()
	for _, name := range []string{".env", "server.pem", "notes.txt"} {
		require.NoError(t, os.WriteFile(filepath.Join(dir, name), nil, 0o600))
	}

	matched, err := Matching(dir, Sensitive)
	require.NoError(t, err)

	assert.Equal(t, []string{".env", "*.pem"}, matched)
}

func TestMatching_NothingSensitive(t *testing.T) {
	dir := t.TempDir()
	require.NoError(t, os.WriteFile(filepath.Join(dir, "README.md"), nil, 0o644))

	matched, err := Matching(dir, Sensitive)
	require.NoError(t, err)

	assert.Empty(t, matched)
}

// A key hidden behind a leading dot is still a key. Bash globs skip dotfiles
// unless the pattern starts with one, so `*.key` never saw `.deploy.key`.
func TestMatching_FindsDotfiles(t *testing.T) {
	dir := t.TempDir()
	require.NoError(t, os.WriteFile(filepath.Join(dir, ".deploy.key"), nil, 0o600))

	matched, err := Matching(dir, Sensitive)
	require.NoError(t, err)

	assert.Equal(t, []string{"*.key"}, matched)
}
