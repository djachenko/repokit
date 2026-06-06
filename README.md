# init_python

Bootstrap script for new Python GitHub repositories.

## What it does

- Creates a GitHub repository
- Initializes git with a remote
- Writes CI workflows (Tests, Integration, Release)
- Writes a `pyproject.toml` template
- Applies branch ruleset (merge-only, required status checks)
- Prints a post-setup checklist

## Requirements

- [`git`](https://git-scm.com)
- [`gh`](https://cli.github.com) — authenticated (`gh auth login`)

## Installation

```bash
cd init_python
./install.sh
# restart shell or: source ~/.zshrc
```

## Usage

```bash
mkdir my-repo
cd my-repo
init_python.sh
```

Repo name is taken from the current directory name.
GitHub owner is taken from `gh auth`.

## Post-setup checklist

After running the script:

1. Add `RELEASE_TOKEN` secret — PAT of your bot account (`contents: write`)
2. Give bot account write access to the repo
3. Add Trusted Publisher on [PyPI](https://pypi.org/manage/account/publishing/) — workflow: `release.yml`
4. Add Trusted Publisher on [TestPyPI](https://test.pypi.org/manage/account/publishing/) — workflow: `integration.yml`
