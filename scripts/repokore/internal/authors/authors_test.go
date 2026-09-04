package authors

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const (
	zero40 = "0000000000000000000000000000000000000000"
	zero64 = "0000000000000000000000000000000000000000000000000000000000000000"
)

// ── the pre-push protocol ─────────────────────────────────────────────────────

func TestParsePush(t *testing.T) {
	got, err := ParsePush(strings.NewReader(
		"refs/heads/main abc123 refs/heads/main def456\n" +
			"refs/heads/topic aaa111 refs/heads/topic " + zero40 + "\n"))

	require.NoError(t, err)
	require.Len(t, got, 2)
	assert.Equal(t, Push{"refs/heads/main", "abc123", "refs/heads/main", "def456"}, got[0])
	assert.Equal(t, zero40, got[1].RemoteSHA)
}

func TestParsePush_MalformedLine_IsAnError(t *testing.T) {
	_, err := ParsePush(strings.NewReader("refs/heads/main abc123\n"))

	assert.Error(t, err)
}

func TestRange_ExistingBranch(t *testing.T) {
	p := Push{LocalSHA: "def456", RemoteSHA: "abc123"}

	assert.Equal(t, []string{"abc123..def456"}, p.Range())
}

func TestRange_NewBranch(t *testing.T) {
	p := Push{LocalSHA: "def456", RemoteSHA: zero40}

	assert.Equal(t, []string{"def456", "--not", "--remotes"}, p.Range())
}

// Deleting a branch publishes nothing, so there is nothing to check. The
// installed hook that predates this guard aborts the push instead.
func TestRange_Deletion_IsNothingToCheck(t *testing.T) {
	p := Push{LocalSHA: zero40, RemoteSHA: "abc123"}

	assert.Nil(t, p.Range())
}

// SHA-256 repositories use the same marker at twice the length; matching on a
// 40-character literal would have missed it.
func TestRange_Sha256Zero(t *testing.T) {
	assert.Nil(t, Push{LocalSHA: zero64, RemoteSHA: "abc"}.Range())
	assert.Equal(t, []string{"def", "--not", "--remotes"},
		Push{LocalSHA: "def", RemoteSHA: zero64}.Range())
}

// A hash that merely begins with zeros is a real commit.
func TestRange_LeadingZeroHash_IsNotTheZeroSHA(t *testing.T) {
	p := Push{LocalSHA: "0001234", RemoteSHA: "abc123"}

	assert.Equal(t, []string{"abc123..0001234"}, p.Range())
}

// ── git log ───────────────────────────────────────────────────────────────────

func TestParseLog(t *testing.T) {
	got, err := ParseLog(strings.NewReader(
		"abc123 igor@example.com feat: add thing\n" +
			"def456 other@example.com fix: correct it\n"))

	require.NoError(t, err)
	assert.Equal(t, []Commit{
		{"abc123", "igor@example.com", "feat: add thing"},
		{"def456", "other@example.com", "fix: correct it"},
	}, got)
}

// The subject is the rest of the line, spaces and all — awk's field splitting
// was what made this need a substr() dance.
func TestParseLog_SubjectKeepsSpacing(t *testing.T) {
	got, err := ParseLog(strings.NewReader("abc123 igor@example.com chore: a  b   c\n"))

	require.NoError(t, err)
	assert.Equal(t, "chore: a  b   c", got[0].Subject)
}

func TestParseLog_EmptySubject(t *testing.T) {
	got, err := ParseLog(strings.NewReader("abc123 igor@example.com\n"))

	require.NoError(t, err)
	assert.Equal(t, Commit{"abc123", "igor@example.com", ""}, got[0])
}

func TestParseLog_BlankLinesIgnored(t *testing.T) {
	got, err := ParseLog(strings.NewReader("\nabc123 igor@example.com x\n\n"))

	require.NoError(t, err)
	assert.Len(t, got, 1)
}

// ── the check itself ──────────────────────────────────────────────────────────

var commits = []Commit{
	{"a1", "igor@example.com", "one"},
	{"b2", "stranger@example.com", "two"},
	{"c3", "repokit@djachenko", "three"},
}

func TestOffenders(t *testing.T) {
	bad := Offenders(commits, []string{"igor@example.com", "repokit@djachenko"})

	assert.Equal(t, []Commit{{"b2", "stranger@example.com", "two"}}, bad)
}

func TestOffenders_NoneAllowed(t *testing.T) {
	assert.Len(t, Offenders(commits, nil), 3)
}

// Matching is exact: a substring of an allowed address is not allowed.
func TestOffenders_ExactMatchOnly(t *testing.T) {
	bad := Offenders([]Commit{{"a1", "evil-igor@example.com", "x"}}, []string{"igor@example.com"})

	assert.Len(t, bad, 1)
}

// An empty entry in the allowed list must not permit an empty author.
func TestOffenders_EmptyAllowedEntryPermitsNothing(t *testing.T) {
	bad := Offenders([]Commit{{"a1", "", "x"}}, []string{""})

	assert.Len(t, bad, 1)
}

func TestEmails_DistinctInFirstSeenOrder(t *testing.T) {
	got := Emails([]Commit{
		{"a", "second@example.com", ""},
		{"b", "first@example.com", ""},
		{"c", "second@example.com", ""},
	})

	assert.Equal(t, []string{"second@example.com", "first@example.com"}, got)
}
