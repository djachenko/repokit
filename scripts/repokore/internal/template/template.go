// Package template substitutes {{PLACEHOLDER}} markers in repokit's templates.
//
// This replaces `sed "s/{{REPO}}/$REPO/g"`, which breaks as soon as a value
// contains a slash or an ampersand — sed reads those as syntax, not as text.
package template

import (
	"crypto/sha256"
	"encoding/hex"
	"os"
	"strings"
)

// Render replaces every {{KEY}} with its value. Values are inserted literally:
// no character in them is special, and a value that itself looks like a
// placeholder is not expanded again.
func Render(src string, vars map[string]string) string {
	pairs := make([]string, 0, len(vars)*2)
	for key, value := range vars {
		pairs = append(pairs, "{{"+key+"}}", value)
	}

	return strings.NewReplacer(pairs...).Replace(src)
}

// RenderFile reads a template from disk and renders it.
func RenderFile(path string, vars map[string]string) (string, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}

	return Render(string(b), vars), nil
}

// MajorMinor reduces a repokit version to the ref client workflows pin
// themselves to: "0.9.8" becomes "0.9", so a patch release does not require
// regenerating every client repo's workflows.
//
// Anything that is not a dotted version — "master" when running from source —
// is a ref already and passes through untouched.
func MajorMinor(version string) string {
	parts := strings.Split(version, ".")
	if len(parts) < 3 {
		return version
	}

	return strings.Join(parts[:2], ".")
}

// Hash fingerprints rendered content so a later run can tell whether the
// template changed. Comparing template-to-template rather than template-to-file
// is what keeps the user's own edits from looking like a pending update.
func Hash(rendered string) string {
	sum := sha256.Sum256([]byte(rendered))

	return hex.EncodeToString(sum[:])
}
