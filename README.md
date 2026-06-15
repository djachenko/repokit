# repokit

Bootstrap script for GitHub repositories. Works for new repos and existing local ones.

## What it does

Runs a linear pipeline with gate checks at each step:

1. **Preflight** — verifies `git` and `gh` are installed and authenticated
2. **Local git** — if no `.git` found, runs `git init` and makes an initial commit
3. **GitHub repo** — if repo doesn't exist on GitHub, creates it, adds remote, and pushes history
4. **Workflows** — copies CI wrappers from `languages/<name>/wrappers/` to `.github/workflows/`; skips files not owned by repokit
5. **Ruleset** — applies branch protection to the default branch (idempotent: replaces if already exists)
6. **Checklist** — prints post-setup instructions specific to the language

> **Abort case:** if a GitHub repo already exists but there's no local git — exits with an error. Clone it first.

## Architecture: reusable workflows

CI logic lives in repokit, not in the target repo. Each language has:

- `.github/workflows/<lang>-*.yml` — reusable workflows (`workflow_call`), logic lives here
- `languages/<name>/wrappers/` — thin trigger wrappers copied into the target repo

When repokit is updated, all repos using its shared workflows pick up the changes automatically — no need to update individual repos.

## Ownership and updates

`workflows.sh` tracks ownership via git author. A file written by repokit (`repokit@djachenko`) will be updated on subsequent runs; a file last modified by a human will be skipped.

To override the ownership check and force-overwrite:

```bash
repokit --language bash --skip-owner-check
```

## Ruleset

Applied to the default branch. Nobody can push directly — all changes go through a PR:

- No branch deletion
- No force push
- PR required to merge; only merge commits allowed (no squash, no rebase)
- Required status check: `integration / integration` must pass before merge

## Requirements

- [`git`](https://git-scm.com)
- [`gh`](https://cli.github.com) — authenticated (`gh auth login`)

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/djachenko/repokit/master/install.sh | bash
# restart shell or: source ~/.zshrc
```

Installs to `~/.local/share/repokit` and adds it to `PATH`.

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
.github/workflows/
└── <name>-*.yml     # reusable workflows (workflow_call), logic lives here

languages/<name>/
├── wrappers/        # thin trigger wrappers, copied into target repos
├── setup.sh         # language-specific setup (required, can be empty)
└── instructions.sh  # post-setup checklist printed to user
```

`setup.sh` is called by the orchestrator after workflows are copied. Has access to `$REPO`, `$OWNER`, `$SCRIPT_DIR` env vars.

---

## Python

**What repokit sets up:**

- `tests.yml` — pytest + ruff + mypy on every push
- `integration.yml` — matrix (ubuntu/macos/windows × Python 3.10–3.x) on PR; publishes dev build to TestPyPI
- `release.yml` — python-semantic-release + PyPI publish on push to master via GitHub App

**Post-setup checklist:**

1. Add GitHub App secrets: `APP_ID`, `APP_PRIVATE_KEY`
2. Add Trusted Publisher on [PyPI](https://pypi.org/manage/account/publishing/) — workflow: `.github/workflows/python-release.yml` in `djachenko/repokit`
3. Add Trusted Publisher on [TestPyPI](https://test.pypi.org/manage/account/publishing/) — workflow: `.github/workflows/python-integration.yml` in `djachenko/repokit`

---

## Bash

**What repokit sets up:**

- `tests.yml` — shellcheck + shfmt on every push
- `integration.yml` — stub with required `integration` job
- `release.yml` — cocogitto auto-versioning + GitHub release on push to master

Release flow: push to master → cocogitto bumps version from conventional commits (no commit to repo, tag only) → changelog goes into GitHub release body.

**Post-setup checklist:**

_(nothing required)_
