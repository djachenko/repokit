// Package workflow reads GitHub Actions workflow files well enough to work out
// which check contexts a ruleset must require.
//
// It replaces two hand-written awk parsers that matched YAML by indentation
// depth. That worked only for the exact layout repokit ships: `needs:` written
// as a block list instead of `needs: [a, b]` was silently read as no
// dependencies at all, which makes every job look terminal.
package workflow

import (
	"fmt"
	"path"
	"strings"

	"gopkg.in/yaml.v3"
)

// Job is one entry under `jobs:`.
type Job struct {
	// ID is the key the job is written under, which is also what GitHub uses
	// to name its check context.
	ID string
	// Uses is the reusable workflow this job calls, empty for a normal job.
	Uses string
	// Needs lists the jobs that must finish first.
	Needs []string
}

// Jobs lists a workflow's jobs in the order the file declares them, so the
// contexts derived from them stay stable between runs.
func Jobs(src []byte) ([]Job, error) {
	var doc struct {
		Jobs yaml.Node `yaml:"jobs"`
	}

	if err := yaml.Unmarshal(src, &doc); err != nil {
		return nil, err
	}

	if doc.Jobs.Kind != yaml.MappingNode {
		return nil, nil
	}

	// A mapping node holds keys and values interleaved in one slice.
	jobs := make([]Job, 0, len(doc.Jobs.Content)/2)

	for i := 0; i+1 < len(doc.Jobs.Content); i += 2 {
		job := Job{ID: doc.Jobs.Content[i].Value}

		var body struct {
			Uses  string    `yaml:"uses"`
			Needs yaml.Node `yaml:"needs"`
		}

		if err := doc.Jobs.Content[i+1].Decode(&body); err != nil {
			return nil, fmt.Errorf("job %s: %w", job.ID, err)
		}

		needs, err := needsList(body.Needs)
		if err != nil {
			return nil, fmt.Errorf("job %s: %w", job.ID, err)
		}

		job.Uses = body.Uses
		job.Needs = needs

		jobs = append(jobs, job)
	}

	return jobs, nil
}

// needsList accepts both spellings the schema allows: a single job name, or a
// sequence of them in either flow or block style.
func needsList(node yaml.Node) ([]string, error) {
	switch node.Kind {
	case 0:
		return nil, nil

	case yaml.ScalarNode:
		return []string{node.Value}, nil

	case yaml.SequenceNode:
		var needs []string

		return needs, node.Decode(&needs)

	default:
		return nil, fmt.Errorf("unexpected needs: value")
	}
}

// Terminal returns the job every other job leads to — the one GitHub names the
// check context after.
//
// Ambiguity is an error, not a coin toss: the old awk version printed whichever
// job the shell hash order happened to yield first, so a workflow with two
// independent endpoints silently required only one of them.
func Terminal(src []byte) (string, error) {
	jobs, err := Jobs(src)
	if err != nil {
		return "", err
	}

	needed := map[string]bool{}
	for _, job := range jobs {
		for _, need := range job.Needs {
			needed[need] = true
		}
	}

	var terminal []string

	for _, job := range jobs {
		if !needed[job.ID] {
			terminal = append(terminal, job.ID)
		}
	}

	switch len(terminal) {
	case 1:
		return terminal[0], nil

	case 0:
		return "", fmt.Errorf("no terminal job: every job is depended on")

	default:
		return "", fmt.Errorf("ambiguous terminal job: %s", strings.Join(terminal, ", "))
	}
}

// ReusableName is the file a `uses:` value points at, without the @ref suffix
// or the owner/repo path in front of it.
func ReusableName(uses string) string {
	name, _, _ := strings.Cut(uses, "@")

	return path.Base(name)
}
