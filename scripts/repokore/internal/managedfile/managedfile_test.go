package managedfile

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// repo makes a git repository in a temp dir and moves the test into it, since
// Decide works relative to the current directory like the steps that call it.
func repo(t *testing.T) {
	t.Helper()

	t.Chdir(t.TempDir())

	run(t, "git", "init", "-q")
	run(t, "git", "config", "user.email", "me@example.com")
	run(t, "git", "config", "user.name", "Me")
}

func run(t *testing.T, name string, args ...string) {
	t.Helper()

	out, err := exec.Command(name, args...).CombinedOutput()
	require.NoError(t, err, string(out))
}

// commit writes content to path and commits it under author.
func commit(t *testing.T, path, content, author string) {
	t.Helper()

	require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o755))
	require.NoError(t, os.WriteFile(path, []byte(content), 0o644))

	run(t, "git", "add", path)
	run(t, "git", "commit", "-q", "-m", "change "+path, "--author", "Someone <"+author+">")
}

func decide(t *testing.T, path, content string, force bool) Decision {
	t.Helper()

	got, err := Decide(path, []byte(content), force)
	require.NoError(t, err)

	return got
}

func TestDecide_MissingFile_IsWritten(t *testing.T) {
	repo(t)
	commit(t, "other", "x\n", Author)

	assert.Equal(t, Write, decide(t, "new.yml", "content\n", false))
}

func TestDecide_SameContent_IsUnchanged(t *testing.T) {
	repo(t)
	commit(t, "tests.yml", "content\n", "me@example.com")

	assert.Equal(t, Unchanged, decide(t, "tests.yml", "content\n", false))
}

// Forcing overrides ownership, not equality: a forced write of identical
// content would stage nothing, and the caller's commit of nothing would fail.
func TestDecide_SameContent_IsUnchangedEvenForced(t *testing.T) {
	repo(t)
	commit(t, "tests.yml", "content\n", Author)

	assert.Equal(t, Unchanged, decide(t, "tests.yml", "content\n", true))
}

func TestDecide_RepokitsFile_OutOfDate_IsWritten(t *testing.T) {
	repo(t)
	commit(t, "tests.yml", "old\n", Author)

	assert.Equal(t, Write, decide(t, "tests.yml", "new\n", false))
}

func TestDecide_UserCommittedSince_IsSkipped(t *testing.T) {
	repo(t)
	commit(t, "tests.yml", "old\n", Author)
	commit(t, "tests.yml", "mine\n", "me@example.com")

	assert.Equal(t, Skip, decide(t, "tests.yml", "new\n", false))
}

// The hole both bash copies had: the latest commit is repokit's, but the user
// has edited the file since without committing. History cannot see that edit,
// so the author check alone would have written over it.
func TestDecide_UncommittedEdit_IsSkipped(t *testing.T) {
	repo(t)
	commit(t, "tests.yml", "old\n", Author)
	require.NoError(t, os.WriteFile("tests.yml", []byte("half-done\n"), 0o644))

	assert.Equal(t, Skip, decide(t, "tests.yml", "new\n", false))
}

func TestDecide_StagedEdit_IsSkipped(t *testing.T) {
	repo(t)
	commit(t, "tests.yml", "old\n", Author)
	require.NoError(t, os.WriteFile("tests.yml", []byte("staged\n"), 0o644))
	run(t, "git", "add", "tests.yml")

	assert.Equal(t, Skip, decide(t, "tests.yml", "new\n", false))
}

// A file sitting in the tree that nobody ever committed has no history to
// claim it by, so it is the user's.
func TestDecide_UntrackedFile_IsSkipped(t *testing.T) {
	repo(t)
	commit(t, "other", "x\n", Author)
	require.NoError(t, os.WriteFile("tests.yml", []byte("theirs\n"), 0o644))

	assert.Equal(t, Skip, decide(t, "tests.yml", "new\n", false))
}

func TestDecide_Forced_OverridesOwnership(t *testing.T) {
	repo(t)
	commit(t, "tests.yml", "mine\n", "me@example.com")

	assert.Equal(t, Write, decide(t, "tests.yml", "new\n", true))
}
