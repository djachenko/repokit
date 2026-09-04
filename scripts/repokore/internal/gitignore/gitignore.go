// Package gitignore keeps entries in a .gitignore file, and finds the files
// that ought to have one.
package gitignore

import (
	"bufio"
	"bytes"
	"os"
	"path/filepath"
	"strings"
)

// Sensitive lists the filename patterns that must never reach a remote.
var Sensitive = []string{
	".env", ".env.*",
	"*.pem", "*.key", "*.p8", "*.p12", "*.pfx",
	"secrets.*", "credentials.*", "*.secret",
}

// Add appends the patterns the file does not already list, and returns the ones
// it added. Comparison is whole-line and literal, so "key" is not considered
// present because "monkey.txt" is.
//
// A file not ending in a newline gets one first. Bash had this guard in the
// branch that adds .repokit and not in the branch that adds sensitive
// patterns — so the first pattern could be glued onto the last existing line,
// silently turning two entries into one that matches nothing.
func Add(path string, patterns []string) ([]string, error) {
	existing, err := lines(path)
	if err != nil {
		return nil, err
	}

	var missing []string

	for _, pattern := range patterns {
		if !existing[pattern] {
			missing = append(missing, pattern)
			existing[pattern] = true
		}
	}

	if len(missing) == 0 {
		return nil, nil
	}

	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return nil, err
	}

	defer f.Close()

	terminated, err := endsWithNewline(path)
	if err != nil {
		return nil, err
	}

	out := strings.Join(missing, "\n") + "\n"
	if !terminated {
		out = "\n" + out
	}

	if _, err := f.WriteString(out); err != nil {
		return nil, err
	}

	return missing, f.Close()
}

// Matching returns the patterns that match at least one name in dir.
//
// Only patterns that match something are worth adding: an entry for a file the
// project does not have is noise in a file the user reads.
func Matching(dir string, patterns []string) ([]string, error) {
	var matched []string

	for _, pattern := range patterns {
		hits, err := filepath.Glob(filepath.Join(dir, pattern))
		if err != nil {
			return nil, err
		}

		if len(hits) > 0 {
			matched = append(matched, pattern)
		}
	}

	return matched, nil
}

func lines(path string) (map[string]bool, error) {
	f, err := os.Open(path)
	if os.IsNotExist(err) {
		return map[string]bool{}, nil
	}

	if err != nil {
		return nil, err
	}

	defer f.Close()

	present := map[string]bool{}

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		present[scanner.Text()] = true
	}

	return present, scanner.Err()
}

func endsWithNewline(path string) (bool, error) {
	info, err := os.Stat(path)
	if os.IsNotExist(err) || (err == nil && info.Size() == 0) {
		return true, nil
	}

	if err != nil {
		return false, err
	}

	f, err := os.Open(path)
	if err != nil {
		return false, err
	}

	defer f.Close()

	last := make([]byte, 1)
	if _, err := f.ReadAt(last, info.Size()-1); err != nil {
		return false, err
	}

	return bytes.Equal(last, []byte("\n")), nil
}
