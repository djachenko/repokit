# Changelog
All notable changes to this project will be documented in this file. See [conventional commits](https://www.conventionalcommits.org/) for commit guidelines.

- - -
## 0.10.2 - 2026-07-11
#### Bug Fixes
- mask run_quiet exit code from set -e - (7ff7282) - Igor Djachenko

- - -

## 0.10.1 - 2026-07-11
#### Bug Fixes
- correct Trusted Publisher workflow paths and secret name - (65f5be8) - Igor Djachenko
#### Documentation
- update DECISIONS — bypass_actors and ruleset DELETE+POST - (3820880) - Igor Djachenko
- fix flag name and required checks description in README - (e6feaba) - Igor Djachenko

- - -

## 0.10.0 - 2026-07-08
#### Features
- add dotfiles language - (c98f3d8) - Igor Djachenko
#### Bug Fixes
- suppress shellcheck warnings for dynamic source and cross-shell variables - (cd802f9) - Igor Djachenko
#### Documentation
- update CLAUDE.md for dotfiles language and run_step mechanism - (36d0db9) - Igor Djachenko
#### Refactoring
- extract branch flow into init/05_branch_prepare.sh and init/08_branch_push.sh - (675ac2d) - Igor Djachenko
- add run_step language override mechanism - (47c5721) - Igor Djachenko
- renumber 05_workflows to 06 to make room for branch flow steps - (b2c0e8f) - Igor Djachenko
#### Miscellaneous Chores
- add _worktrees/ to .gitignore - (348703c) - Igor Djachenko

- - -

## 0.9.11 - 2026-07-08
#### Bug Fixes
- resolve version via --points-at HEAD in bash-release - (f226251) - Igor Djachenko
#### Miscellaneous Chores
- release 0 [no ci] - (1e45f36) - repokit
- add _worktrees/ to gitignore - (91ba5dd) - Igor Djachenko
- pin release deps, update min versions to latest - (29416fe) - Igor Djachenko
- add CLAUDE.local.md to gitignore - (10f8688) - Igor Djachenko
- sync pyproject.toml template with best practices - (5b90786) - Igor Djachenko

- - -

## 0.9.10 - 2026-07-08
#### Bug Fixes
- detect release via git tag sort instead of git describe - (7de3655) - Igor Djachenko
- update references after init script renames - (dee71b1) - Igor Djachenko
#### Documentation
- update Status — PR #47 merged, 0.9.9 released - (a0b29cb) - Igor Djachenko
- add comments to 01_check_tools and 02_git_init - (7d8ecdd) - Igor Djachenko
- update Status block with shell rc fix - (7cadfbc) - Igor Djachenko
- add line-by-line comments to bash scripts - (2778beb) - Igor Djachenko
- add extensive inline comments to bash scripts - (157f5fe) - Igor Djachenko
- expand repokit skill and update CLAUDE.md structure - (48d0305) - Igor Djachenko
#### Continuous Integration
- skip tests on master push (already ran via integration PR) - (1a5f14d) - Igor Djachenko
#### Refactoring
- add sequence numbers to language_setup and ruleset, meaning-first comments in repokit - (a177022) - Igor Djachenko
- rename language-specific setup scripts to language_setup.sh - (074be06) - Igor Djachenko
- add section comments, IS_FIRST_SETUP flag, cleaner variable names - (3156f93) - Igor Djachenko
#### Miscellaneous Chores
- set initial version to 0.0.0 in pyproject template - (93c5cc0) - Igor Djachenko
#### Style
- add blank lines to break up text walls in scripts - (c4ccea9) - Igor Djachenko

- - -

## 0.9.9 - 2026-07-07
#### Bug Fixes
- replace shell rc block with sourced shell.sh - (3fd267e) - Igor Djachenko

- - -

## 0.9.8 - 2026-07-03
#### Bug Fixes
- rebase setup branch instead of recreating it - (57f079e) - Igor Djachenko

- - -

## 0.9.7 - 2026-07-03
#### Bug Fixes
- use single quotes around git log range to satisfy shellcheck - (dd2f676) - Igor Djachenko
- clear base_branch unconditionally, stay on setup branch - (dbdfbc8) - Igor Djachenko
- suppress gh pr create stderr noise - (31d12c2) - Igor Djachenko
- compare against origin/BASE_BRANCH to avoid spurious push - (f24b555) - Igor Djachenko
- detect existing remote branch to skip redundant push attempt - (9228cbd) - Igor Djachenko

- - -

## 0.9.6 - 2026-07-03
#### Bug Fixes
- ensure .gitignore ends with newline before appending .repokit - (fe8826a) - Igor Djachenko

- - -

## 0.9.5 - 2026-07-01
#### Bug Fixes
- keep .github in installed copy so ruleset.sh can resolve reusable workflows - (d53189f) - Igor Djachenko

- - -

## 0.9.4 - 2026-07-01
#### Bug Fixes
- avoid non-fast-forward failures re-pushing chore/repokit-setup - (bd45377) - Igor Djachenko
- suppress noisy git/gh output unless a command fails - (559050c) - Igor Djachenko
- derive required status checks from generated workflow files - (20712c3) - Igor Djachenko
- skip re-prompting for repokit skill file when already in sync - (3a1b2d1) - Igor Djachenko

- - -

## 0.9.3 - 2026-07-01
#### Bug Fixes
- remove dead owner-email config that silently kills install.sh under set -e - (f738342) - Igor Djachenko

- - -

## 0.9.2 - 2026-07-01
#### Bug Fixes
- use repokit@djachenko as git author in python-release - (b727d1c) - Igor Djachenko
- set commit_author for python-semantic-release - (03d0fb7) - Igor Djachenko
#### Revert
- remove redundant commit_author from pyproject template - (dfac4e2) - Igor Djachenko
#### Miscellaneous Chores
- [repokit] setup - (4f4e83b) - Igor Djachenko

- - -

## 0.9.1 - 2026-06-27
#### Bug Fixes
- suppress release re-trigger on bot commit via no-ci marker - (33553e8) - Igor Djachenko

- - -

## 0.9.0 - 2026-06-27
#### Features
- add --version flag and show upgrade delta - (f9efd05) - Igor Djachenko
#### Bug Fixes
- skip release on bot commits, restore python-integration.yml version update - (ffbe92f) - Igor Djachenko
#### Refactoring
- extract ask_yn helper, use read -n 1 for y/N prompts - (cfa3a6d) - Igor Djachenko
#### Miscellaneous Chores
- release 0 - (8976377) - repokit

- - -

## 0.8.0 - 2026-06-27
#### Features
- store allowed emails in local git config instead of global - (0390dfd) - Igor Djachenko
- add allow once/allow always/deny prompt for unknown author emails - (f8c0259) - Igor Djachenko
#### Bug Fixes
- include python-integration.yml in release version update - (4e3c802) - Igor Djachenko
- use python regex to robustly remove repokit block from shell rc - (15614eb) - Igor Djachenko

- - -

## 0.7.0 - 2026-06-26
#### Features
- offer Claude skill installation during repokit setup - (2b99048) - Igor Djachenko
- dynamic Python version matrix from requires-python in pyproject.toml - (358dc26) - Igor Djachenko
#### Bug Fixes
- pin python-versions action to minor tag, update on release - (c43b167) - Igor Djachenko
- correct publish status check context name in ruleset - (37b6d93) - Igor Djachenko
- require publish job in ruleset status checks - (7ebfe0b) - Igor Djachenko
- reset setup branch from origin/base to stay up to date - (ec4e344) - Igor Djachenko
- clean up base_branch from .repokit when PR already exists - (a8ab173) - Igor Djachenko
#### Refactoring
- extract python version detection into composite action - (18abfae) - Igor Djachenko
#### Miscellaneous Chores
- ignore memory directory without trailing slash - (934642e) - Igor Djachenko

- - -

## 0.6.0 - 2026-06-25
#### Features
- skip install if already up to date, print version on done - (4658d59) - Igor Djachenko
- replace single email check with allowed emails whitelist in pre-push hook - (c69a957) - Igor Djachenko
#### Bug Fixes
- commit .gitignore when adding .repokit entry - (1674d87) - Igor Djachenko
- use OWNER and REPO variables in instructions checklist - (a379c78) - Igor Djachenko

- - -

## 0.5.12 - 2026-06-24
#### Bug Fixes
- use import check instead of --help in smoke test - (d37eb6f) - Igor Djachenko
- auto-install type stubs before mypy check - (62419a8) - Igor Djachenko

- - -

## 0.5.11 - 2026-06-21
#### Bug Fixes
- use create-github-app-token v3 with client-id in python release - (0f0fbbd) - Igor Djachenko
#### Miscellaneous Chores
- update release commit message - (91f88c7) - Igor Djachenko
- write full version in wrapper bump commit message - (940d4be) - Igor Djachenko

- - -

## 0.5.10 - 2026-06-21
#### Bug Fixes
- exclude tag pushes from repokit tests workflow - (6fbee00) - Igor Djachenko

- - -

## 0.5.9 - 2026-06-21
#### Bug Fixes
- exclude tag pushes from tests workflow - (6ba8835) - Igor Djachenko

- - -

## 0.5.8 - 2026-06-21
#### Bug Fixes
- trigger release test - (baacd1d) - Igor Djachenko

- - -

## 0.5.7 - 2026-06-20
#### Bug Fixes
- handle existing release on gh release create - (9e885da) - Igor Djachenko

- - -

## 0.5.6 - 2026-06-20
#### Bug Fixes
- remove duplicate cog bump step - (41e16fd) - Igor Djachenko
- use cocogitto-action v4.2.0 with command:bump - (c819798) - Igor Djachenko
- pin cocogitto-action to v4.1.0 (cog 6.5.0) - (0b0dc1d) - Igor Djachenko

- - -

## 0.5.5 - 2026-06-20
#### Bug Fixes
- remove duplicate cog bump step - (41e16fd) - Igor Djachenko
- use cocogitto-action v4.2.0 with command:bump - (c819798) - Igor Djachenko
- pin cocogitto-action to v4.1.0 (cog 6.5.0) - (0b0dc1d) - Igor Djachenko
- update instructions to use APP_CLIENT_ID instead of APP_ID - (2073d7e) - Igor Djachenko
#### Tests
- add github app token to bash release - (4218089) - Igor Djachenko
#### Miscellaneous Chores
- [repokit] bump wrappers to 0.5 - (06ecb50) - repokit

- - -

## 0.5.5 - 2026-06-20
#### Bug Fixes
- update instructions to use APP_CLIENT_ID instead of APP_ID - (2073d7e) - Igor Djachenko
#### Tests
- add github app token to bash release - (4218089) - Igor Djachenko

- - -

## 0.5.4 - 2026-06-20
#### Bug Fixes
- update cocogitto-action to v4.2.0 - (50fb8a7) - Igor Djachenko
- pin cocogitto-action to v4.1.0 for install-only support - (d914e28) - Igor Djachenko
- adapt to cocogitto-action v4 with install-only flag - (e6cb27b) - Igor Djachenko

- - -

## 0.5.3 - 2026-06-20
#### Bug Fixes
- revert cocogitto-action to v3 - (23464d7) - Igor Djachenko
- use github token directly, remove github app auth - (bcab6f8) - Igor Djachenko
- generate github app jwt manually to ensure integer iss claim - (9c5ac11) - Igor Djachenko
- switch to tibdex/github-app-token for correct integer iss claim - (8f95183) - Igor Djachenko
- use client-id instead of deprecated app-id in github app token - (c9296bf) - Igor Djachenko
- push release commit to master via github app token - (7f5bc0b) - Igor Djachenko

- - -

## 0.5.1 - 2026-06-20
#### Bug Fixes
- use client-id instead of deprecated app-id in github app token - (8b97ebf) - Igor Djachenko
- require tests check in branch ruleset - (1736a0e) - Igor Djachenko
#### Miscellaneous Chores
- remove redundant psr config keys - (62e5f72) - Igor Djachenko
#### Refactoring
- switch build backend to hatchling - (8b86a7b) - Igor Djachenko

- - -

Changelog generated by [cocogitto](https://github.com/cocogitto/cocogitto).