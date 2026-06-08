# repokit

Bootstrap script for new GitHub repositories. Works with existing local repos too.

## What it does

Runs a linear pipeline with gate checks at each step:

1. **Preflight** — verifies `git` and `gh` are installed and authenticated
2. **Local git** — if no `.git` found, runs `git init` and makes an initial commit
3. **GitHub repo** — if repo doesn't exist on GitHub, creates it and adds remote; pushes history
4. **Workflows** — copies CI workflow templates to `.github/workflows/` (skips files that already exist)
5. **pyproject.toml** — copies template if applicable (skips if already exists or not in template)
6. **Ruleset** — applies branch protection ruleset (idempotent: replaces if already exists)
7. **Checklist** — prints post-setup instructions

> **Abort case:** if a GitHub repo already exists but there's no local git — exits with an error. Clone it first.

## Ruleset

Applied to the default branch:

- No branch deletion
- No force push
- PR required to merge; only merge commits allowed (no squash, no rebase)
- Required status check: `integration` must pass before merge

## Templates

Select with `--template <name>`:

| Template | Language | Workflows |
|----------|----------|-----------|
| `python` | Python   | Tests (pytest + ruff + mypy), Integration (matrix + TestPyPI), Release (PSR + PyPI) |
| `bash`   | Bash     | Tests (shellcheck + shfmt), Integration (stub), Release (stub) |

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
repokit --template python
```

Repo name is taken from the current directory name.  
GitHub owner is taken from `gh auth`.

## Post-setup checklist (Python template)

1. Add `RELEASE_TOKEN` secret — PAT of your bot account (`contents: write`)
2. Give bot account write access to the repo
3. Add Trusted Publisher on [PyPI](https://pypi.org/manage/account/publishing/) — workflow: `release.yml`
4. Add Trusted Publisher on [TestPyPI](https://test.pypi.org/manage/account/publishing/) — workflow: `integration.yml`
