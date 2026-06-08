# repokit

Bootstrap script for GitHub repositories. Works for new repos and existing local ones.

## What it does

Runs a linear pipeline with gate checks at each step:

1. **Preflight** — verifies `git` and `gh` are installed and authenticated
2. **Local git** — if no `.git` found, runs `git init` and makes an initial commit
3. **GitHub repo** — if repo doesn't exist on GitHub, creates it, adds remote, and pushes history
4. **Workflows** — copies CI workflows from `languages/<name>/` to `.github/workflows/` (skips existing files)
5. **Ruleset** — applies branch protection to the default branch (idempotent: replaces if already exists)
6. **Checklist** — prints post-setup instructions specific to the language

> **Abort case:** if a GitHub repo already exists but there's no local git — exits with an error. Clone it first.

> **Bot account:** the CI pipeline assumes a dedicated bot account for release commits. The bot needs write access to the repo and a PAT stored as `RELEASE_TOKEN` secret. This is set up manually after running the script (see per-language checklists below).

## Ruleset

Applied to the default branch. Nobody can push directly — all changes go through a PR:

- No branch deletion
- No force push
- PR required to merge; only merge commits allowed (no squash, no rebase)
- Required status check: `integration` must pass before merge

## Requirements

- [`git`](https://git-scm.com)
- [`gh`](https://cli.github.com) — authenticated (`gh auth login`)

## Installation

```bash
cd repokit
./install.sh
# restart shell or: source ~/.zshrc
```

## Usage

```bash
mkdir my-repo
cd my-repo
repokit --language python
```

Repo name is taken from the current directory name.  
GitHub owner is taken from `gh auth`.

---

## Adding a language

Create a folder under `languages/` — it will be picked up automatically:

```
languages/<name>/
├── workflows/    # CI workflows copied to .github/workflows/
└── setup.sh      # language-specific setup (required, can be empty)
```

`setup.sh` is called by the orchestrator after workflows are copied. Use it for anything language-specific (e.g. generating config files). Has access to `$REPO`, `$OWNER`, `$SCRIPT_DIR` env vars.

---

## Python

**What repokit sets up:**

- `tests.yml` — pytest + ruff + mypy on every push
- `integration.yml` — matrix (ubuntu/macos/windows × Python 3.10–3.x) on PR; publishes dev build to TestPyPI
- `release.yml` — python-semantic-release + PyPI publish on push to master
- `pyproject.toml` — minimal template with project metadata

**Post-setup checklist:**

1. Add `RELEASE_TOKEN` secret — PAT of your bot account (`contents: write`)
2. Give bot account write access to the repo
3. Add Trusted Publisher on [PyPI](https://pypi.org/manage/account/publishing/) — workflow: `release.yml`
4. Add Trusted Publisher on [TestPyPI](https://test.pypi.org/manage/account/publishing/) — workflow: `integration.yml`

---

## Bash

**What repokit sets up:**

- `tests.yml` — shellcheck + shfmt on every push
- `integration.yml` — stub with required `integration` job
- `release.yml` — stub (release flow TBD)

**Post-setup checklist:**

_(nothing required — no publishing pipeline yet)_
