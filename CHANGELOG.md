# Changelog
All notable changes to this project will be documented in this file. See [conventional commits](https://www.conventionalcommits.org/) for commit guidelines.

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