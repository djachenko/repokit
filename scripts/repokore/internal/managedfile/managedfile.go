// Package managedfile decides whether repokit may write a file it keeps in a
// user's repository: a CI wrapper, a dotfiles script.
//
// The rule is ownership by git history. repokit commits everything it writes
// under its own author, so a file whose latest commit is repokit's is still
// repokit's to replace; one someone else committed since is theirs. Before
// this package the rule existed twice in bash — the workflows step and the
// dotfiles step — and both overwrote uncommitted edits, which git history
// cannot see.
//
// git is only read here, never written: staging and committing stay in bash
// with the rest of the git bookkeeping.
package managedfile

import (
	"bytes"
	"errors"
	"os"
	"os/exec"
	"strings"
)

// Author is the email repokit commits under.
const Author = "repokit@djachenko"

// Decision is what to do with a managed file.
type Decision int

const (
	// Write: the file is missing, or repokit's and out of date.
	Write Decision = iota
	// Unchanged: the file already holds exactly this content.
	Unchanged
	// Skip: the file differs, but it is not repokit's to replace.
	Skip
)

// Decide compares content with what is at dest and says whether to write it.
//
// force overrides ownership, never equality: forcing a file that already
// matches still writes nothing, because the caller commits whatever it wrote
// and a commit of nothing fails.
func Decide(dest string, content []byte, force bool) (Decision, error) {
	current, err := os.ReadFile(dest)
	if errors.Is(err, os.ErrNotExist) {
		return Write, nil
	}

	if err != nil {
		return 0, err
	}

	if bytes.Equal(current, content) {
		return Unchanged, nil
	}

	if force {
		return Write, nil
	}

	owned, err := ownedByRepokit(dest)
	if err != nil {
		return 0, err
	}

	if owned {
		return Write, nil
	}

	return Skip, nil
}

func ownedByRepokit(path string) (bool, error) {
	// Uncommitted edits, staged or not, are the user's work in progress —
	// and invisible to the author check below, which only sees commits.
	// `diff --quiet` exits 1 when there are differences.
	err := exec.Command("git", "diff", "--quiet", "HEAD", "--", path).Run()

	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) && exitErr.ExitCode() == 1 {
		return false, nil
	}

	if err != nil {
		return false, err
	}

	author, err := exec.Command("git", "log", "--format=%ae", "-1", "--", path).Output()
	if err != nil {
		return false, err
	}

	return strings.TrimSpace(string(author)) == Author, nil
}
