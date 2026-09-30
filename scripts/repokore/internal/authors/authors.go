// Package authors checks who wrote the commits a push is about to publish.
//
// It replaces the parsing half of hooks/pre-push, which pulled each field out
// of a log line with its own awk process — three per commit — and built the
// rev-list range as a bare string that relied on word splitting to become
// several arguments.
package authors

import (
	"bufio"
	"fmt"
	"io"
	"strings"
)

// Commit is one line of `git log --format="%h %ae %s"`.
type Commit struct {
	Hash    string
	Email   string
	Subject string
}

// Push is one line of the protocol git feeds a pre-push hook on stdin.
type Push struct {
	LocalRef  string
	LocalSHA  string
	RemoteRef string
	RemoteSHA string
}

// CommitRange returns the arguments naming the commits this push would add, to
// be passed to `git rev-list` or `git log`, or nil when there is nothing to
// check.
//
// A slice rather than a string even when it holds one element: the new-branch
// case genuinely needs three arguments, and the caller must be able to expand
// the result without knowing which case it got. The bash this replaces kept
// "$remote_sha --not --remotes" in one variable and relied on leaving it
// unquoted to split — which would have split any other whitespace too.
func (p Push) CommitRange() []string {
	if isZero(p.LocalSHA) {
		// Deleting a branch publishes no commits.
		return nil
	}

	if isZero(p.RemoteSHA) {
		// A new branch: everything reachable from it that no remote has yet.
		return []string{p.LocalSHA, "--not", "--remotes"}
	}

	return []string{p.RemoteSHA + ".." + p.LocalSHA}
}

// isZero reports the all-zero SHA git uses for "this ref does not exist".
// Matching on the digits rather than on a 40-character literal keeps this
// working for repositories using SHA-256, where the same marker is 64 long.
func isZero(sha string) bool {
	if sha == "" {
		return false
	}

	return strings.Trim(sha, "0") == ""
}

// ParsePush reads the pre-push protocol: four space-separated fields per line.
func ParsePush(r io.Reader) ([]Push, error) {
	var pushes []Push

	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		fields := strings.Fields(scanner.Text())
		if len(fields) == 0 {
			continue
		}

		if len(fields) != 4 {
			return nil, fmt.Errorf("expected 4 fields, got %d: %q", len(fields), scanner.Text())
		}

		pushes = append(pushes, Push{
			LocalRef:  fields[0],
			LocalSHA:  fields[1],
			RemoteRef: fields[2],
			RemoteSHA: fields[3],
		})
	}

	return pushes, scanner.Err()
}

// ParseLog reads `git log --format="%h %ae %s"` output. The subject is whatever
// follows the second space, so a subject containing spaces survives intact.
func ParseLog(r io.Reader) ([]Commit, error) {
	var commits []Commit

	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.TrimSpace(line) == "" {
			continue
		}

		hash, rest, found := strings.Cut(line, " ")
		if !found {
			return nil, fmt.Errorf("no email in log line: %q", line)
		}

		email, subject, _ := strings.Cut(rest, " ")

		commits = append(commits, Commit{Hash: hash, Email: email, Subject: subject})
	}

	return commits, scanner.Err()
}

// Offenders returns the commits whose author is not on the allowed list.
func Offenders(commits []Commit, allowed []string) []Commit {
	permitted := make(map[string]bool, len(allowed))
	for _, email := range allowed {
		if email != "" {
			permitted[email] = true
		}
	}

	var bad []Commit

	for _, commit := range commits {
		if !permitted[commit.Email] {
			bad = append(bad, commit)
		}
	}

	return bad
}
