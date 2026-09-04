package changes

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func parse(t *testing.T, porcelain string) []Change {
	t.Helper()

	got, err := Parse(strings.NewReader(porcelain))
	require.NoError(t, err)

	return got
}

func TestParse(t *testing.T) {
	got := parse(t, " M nvim/lua/init.lua\n?? new.txt\n D old.txt\n")

	assert.Equal(t, []Change{
		{" M", "nvim/lua/init.lua"},
		{"??", "new.txt"},
		{" D", "old.txt"},
	}, got)
}

// A path with spaces is still one path: the status is fixed-width, so the rest
// of the line is the name.
func TestParse_PathWithSpaces(t *testing.T) {
	got := parse(t, " M my dir/some file.txt\n")

	assert.Equal(t, "my dir/some file.txt", got[0].Path)
}

// ── grouping ──────────────────────────────────────────────────────────────────

func TestGroups_ByDepth(t *testing.T) {
	groups := Groups(parse(t,
		" M nvim/lua/init.lua\n"+
			" M nvim/lua/keys.lua\n"+
			" M zsh/.zshrc\n"+
			" M README.md\n"))

	assert.Equal(t, []string{".", "nvim/lua", "zsh"}, keys(groups))

	deep, ok := Find(groups, "nvim/lua")
	require.True(t, ok)
	assert.Len(t, deep.Changes, 2)
}

// Four segments group by the first two, same as three.
func TestGroups_DeeperThanTwoStillGroupsAtTwo(t *testing.T) {
	groups := Groups(parse(t, " M a/b/c/d.txt\n M a/b/e.txt\n"))

	assert.Equal(t, []string{"a/b"}, keys(groups))
	assert.Len(t, groups[0].Changes, 2)
}

func TestGroups_Empty(t *testing.T) {
	assert.Empty(t, Groups(nil))
}

// Ordered by key, so the same working tree always produces the same sequence of
// commits.
func TestGroups_StableOrder(t *testing.T) {
	groups := Groups(parse(t, " M zsh/.zshrc\n M nvim/init.lua\n M abc/x\n"))

	assert.Equal(t, []string{"abc", "nvim", "zsh"}, keys(groups))
}

func TestFind_Missing(t *testing.T) {
	_, ok := Find(Groups(parse(t, " M a/b.txt\n")), "nope")

	assert.False(t, ok)
}

// ── message ───────────────────────────────────────────────────────────────────

func TestMessage(t *testing.T) {
	group, ok := Find(Groups(parse(t,
		"?? nvim/lua/new.lua\n"+
			" D nvim/lua/gone.lua\n"+
			" M nvim/lua/init.lua\n")), "nvim/lua")
	require.True(t, ok)

	assert.Equal(t,
		"auto: nvim/lua (3 files)\n\n+ new.lua\n- gone.lua\n~ init.lua\n",
		group.Message())
}

// Singular for one file — the old script picked the noun with a test on the
// line count.
func TestMessage_SingleFile(t *testing.T) {
	group := Groups(parse(t, " M zsh/.zshrc\n"))[0]

	assert.Contains(t, group.Message(), "auto: zsh (1 file)\n")
}

func TestMessage_Symbols(t *testing.T) {
	for status, want := range map[string]string{
		"??": "+", "A ": "+", " D": "-", "D ": "-",
		" M": "~", "M ": "~", "R ": "~", "UU": "~",
	} {
		assert.Equal(t, want, symbol(status), "status %q", status)
	}
}

// A staged addition and an untracked file both read as "+".
func TestMessage_StagedAndUntrackedBothAdd(t *testing.T) {
	group := Groups(parse(t, "A  dir/staged.txt\n?? dir/untracked.txt\n"))[0]

	assert.Contains(t, group.Message(), "+ staged.txt")
	assert.Contains(t, group.Message(), "+ untracked.txt")
}

func keys(groups []Group) []string {
	out := make([]string, len(groups))
	for i, group := range groups {
		out[i] = group.Key
	}

	return out
}
