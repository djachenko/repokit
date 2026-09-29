// Package config reads and writes the .repokit marker file: one key=value pair
// per line, no sections, no escaping.
//
// The format had four independent bash implementations that had already drifted
// apart — two of them collided as a merge conflict. This is the single one.
package config

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Get returns the value for key, or "" when the key or the file is absent.
// A missing file is not an error: the first run has no .repokit yet.
func Get(path, key string) (string, error) {
	f, err := os.Open(path)
	if os.IsNotExist(err) {
		return "", nil
	}

	if err != nil {
		return "", err
	}

	defer f.Close()

	prefix := key + "="

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		if line := scanner.Text(); strings.HasPrefix(line, prefix) {
			return strings.TrimPrefix(line, prefix), nil
		}
	}

	return "", scanner.Err()
}

// Set writes key=value, leaving every other line untouched and in place.
// An existing key keeps its position; a new one is appended.
func Set(path, key, value string) error {
	lines, err := readLines(path)
	if err != nil {
		return err
	}

	prefix := key + "="
	replacement := prefix + value
	replaced := false

	for i, line := range lines {
		if strings.HasPrefix(line, prefix) {
			lines[i] = replacement
			replaced = true

			break
		}
	}

	if !replaced {
		lines = append(lines, replacement)
	}

	return writeLines(path, lines)
}

func readLines(path string) ([]string, error) {
	f, err := os.Open(path)
	if os.IsNotExist(err) {
		return nil, nil
	}

	if err != nil {
		return nil, err
	}

	defer f.Close()

	var lines []string

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}

	return lines, scanner.Err()
}

// writeLines replaces the file atomically: a crash or a full disk halfway
// through must not leave .repokit truncated, since losing base_branch or
// template_hash silently changes what the next run does.
func writeLines(path string, lines []string) error {
	dir := filepath.Dir(path)

	tmp, err := os.CreateTemp(dir, ".repokit-*")
	if err != nil {
		return err
	}

	defer os.Remove(tmp.Name())

	for _, line := range lines {
		if _, err := fmt.Fprintln(tmp, line); err != nil {
			tmp.Close()

			return err
		}
	}

	if err := tmp.Close(); err != nil {
		return err
	}

	return os.Rename(tmp.Name(), path)
}
