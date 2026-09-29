package config

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func write(t *testing.T, content string) string {
	t.Helper()

	path := filepath.Join(t.TempDir(), ".repokit")
	require.NoError(t, os.WriteFile(path, []byte(content), 0o644))

	return path
}

func read(t *testing.T, path string) string {
	t.Helper()

	b, err := os.ReadFile(path)
	require.NoError(t, err)

	return string(b)
}

func TestGet(t *testing.T) {
	path := write(t, "language=python\nbase_branch=master\n")

	v, err := Get(path, "base_branch")
	require.NoError(t, err)
	assert.Equal(t, "master", v)
}

func TestGet_MissingKey(t *testing.T) {
	path := write(t, "language=python\n")

	v, err := Get(path, "template_hash")
	require.NoError(t, err)
	assert.Equal(t, "", v)
}

// The first run has no .repokit yet — that is ordinary, not a failure.
func TestGet_MissingFile(t *testing.T) {
	v, err := Get(filepath.Join(t.TempDir(), "absent"), "language")
	require.NoError(t, err)
	assert.Equal(t, "", v)
}

// A value containing "=" survives: the split is on the first one only.
func TestGet_ValueWithEquals(t *testing.T) {
	path := write(t, "token=abc=def=\n")

	v, err := Get(path, "token")
	require.NoError(t, err)
	assert.Equal(t, "abc=def=", v)
}

func TestSet_ReplacesInPlace(t *testing.T) {
	path := write(t, "language=python\nbase_branch=master\napp_id=123\n")

	require.NoError(t, Set(path, "base_branch", "main"))

	assert.Equal(t, "language=python\nbase_branch=main\napp_id=123\n", read(t, path))
}

func TestSet_AppendsNewKey(t *testing.T) {
	path := write(t, "language=python\n")

	require.NoError(t, Set(path, "template_hash", "deadbeef"))

	assert.Equal(t, "language=python\ntemplate_hash=deadbeef\n", read(t, path))
}

// The bash version this replaces appended without checking for a trailing
// newline, gluing the new key onto the last existing line.
func TestSet_FileWithoutTrailingNewline(t *testing.T) {
	path := write(t, "language=python")

	require.NoError(t, Set(path, "app_id", "7"))

	assert.Equal(t, "language=python\napp_id=7\n", read(t, path))
}

func TestSet_CreatesFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), ".repokit")

	require.NoError(t, Set(path, "language", "python"))

	assert.Equal(t, "language=python\n", read(t, path))
}

// Keys sharing a prefix must not match each other.
func TestSet_PrefixCollision(t *testing.T) {
	path := write(t, "app=one\napp_id=two\n")

	require.NoError(t, Set(path, "app", "three"))

	assert.Equal(t, "app=three\napp_id=two\n", read(t, path))
}
