package workflow

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func jobs(t *testing.T, src string) []Job {
	t.Helper()

	got, err := Jobs([]byte(src))
	require.NoError(t, err)

	return got
}

// Contexts are derived in file order, so the ruleset does not churn between
// runs on nothing but map iteration order.
func TestJobs_KeepsFileOrder(t *testing.T) {
	got := jobs(t, `
jobs:
  zebra:
    runs-on: ubuntu-latest
  alpha:
    runs-on: ubuntu-latest
  middle:
    runs-on: ubuntu-latest
`)

	assert.Equal(t, []string{"zebra", "alpha", "middle"}, ids(got))
}

func TestJobs_ReadsUses(t *testing.T) {
	got := jobs(t, `
jobs:
  tests:
    uses: djachenko/repokit/.github/workflows/python-tests.yml@0.10
    secrets: inherit
  plain:
    runs-on: ubuntu-latest
`)

	require.Len(t, got, 2)
	assert.Equal(t, "djachenko/repokit/.github/workflows/python-tests.yml@0.10", got[0].Uses)
	assert.Empty(t, got[1].Uses)
}

func TestJobs_NoJobsSection(t *testing.T) {
	assert.Empty(t, jobs(t, "name: Tests\non: push\n"))
}

func TestJobs_BrokenYAML_IsAnError(t *testing.T) {
	_, err := Jobs([]byte("jobs:\n  a:\n   - unbalanced: [\n"))

	assert.Error(t, err)
}

// ── needs, in every spelling the schema allows ────────────────────────────────

// The awk parser only understood the flow form. A block list read as no
// dependencies at all, which made every job look terminal.
func TestJobs_Needs_BlockList(t *testing.T) {
	got := jobs(t, `
jobs:
  release:
    needs:
      - build
      - test
`)

	assert.Equal(t, []string{"build", "test"}, got[0].Needs)
}

func TestJobs_Needs_FlowList(t *testing.T) {
	got := jobs(t, "jobs:\n  release:\n    needs: [build, test]\n")

	assert.Equal(t, []string{"build", "test"}, got[0].Needs)
}

func TestJobs_Needs_Scalar(t *testing.T) {
	got := jobs(t, "jobs:\n  release:\n    needs: build\n")

	assert.Equal(t, []string{"build"}, got[0].Needs)
}

func TestJobs_Needs_Absent(t *testing.T) {
	got := jobs(t, "jobs:\n  build:\n    runs-on: ubuntu-latest\n")

	assert.Empty(t, got[0].Needs)
}

// ── terminal job ──────────────────────────────────────────────────────────────

func TestTerminal_FollowsTheChain(t *testing.T) {
	terminal, err := Terminal([]byte(`
jobs:
  build:
    runs-on: ubuntu-latest
  test:
    needs: build
  publish:
    needs: [test]
`))

	require.NoError(t, err)
	assert.Equal(t, "publish", terminal)
}

// Two endpoints means the check context cannot be derived. The awk version
// printed whichever came first out of a hash, so the ruleset silently required
// one of them and let the other fail unnoticed.
func TestTerminal_Ambiguous_IsAnError(t *testing.T) {
	_, err := Terminal([]byte(`
jobs:
  build:
    runs-on: ubuntu-latest
  lint:
    runs-on: ubuntu-latest
`))

	require.Error(t, err)
	assert.Contains(t, err.Error(), "ambiguous")
	assert.Contains(t, err.Error(), "build")
	assert.Contains(t, err.Error(), "lint")
}

func TestTerminal_Cycle_IsAnError(t *testing.T) {
	_, err := Terminal([]byte("jobs:\n  a:\n    needs: b\n  b:\n    needs: a\n"))

	require.Error(t, err)
	assert.Contains(t, err.Error(), "no terminal job")
}

// ── uses: ─────────────────────────────────────────────────────────────────────

func TestReusableName(t *testing.T) {
	assert.Equal(t, "python-tests.yml",
		ReusableName("djachenko/repokit/.github/workflows/python-tests.yml@0.10"))
	assert.Equal(t, "bash-tests.yml",
		ReusableName("djachenko/repokit/.github/workflows/bash-tests.yml@master"))

	// A local call has no ref to strip.
	assert.Equal(t, "local.yml", ReusableName("./.github/workflows/local.yml"))
}

func ids(jobs []Job) []string {
	out := make([]string, len(jobs))
	for i, job := range jobs {
		out[i] = job.ID
	}

	return out
}
