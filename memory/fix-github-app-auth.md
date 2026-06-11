# fix-github-app-auth — Переход на GitHub App auth, прямой CLI для PSR, git identity, pyproject фиксы. ЗАВЕРШЕНО.

<!-- Эта строка читается всегда. Остальное — по требованию. -->

### 2026-06-10 — DONE: Полный переход CI шаблонов с RELEASE_TOKEN + Docker action на GitHub App + прямой CLI

**Цель:** Устаревшая схема с `RELEASE_TOKEN` (PAT бот-аккаунта) и PSR Docker action не попала в шаблон после PR #3. Плюс несколько накопившихся фиксов из goodoc/shabbot.

**Сделано:**
- `release.yml` — GitHub App auth через `actions/create-github-app-token@v1` (APP_ID + APP_PRIVATE_KEY), PSR Docker action заменён прямым CLI (`pip install ".[release]"` + `semantic-release version --print`), git identity перед PSR, отдельный `python -m build`
- `integration.yml` — git identity перед `Merge master` через плейсхолдеры `{{APP_SLUG}}` и `{{APP_ACTOR_ID}}`
- `workflows.sh` — подстановка `{{APP_SLUG}}` и `{{APP_ACTOR_ID}}` с дефолтами (`github-actions` / `41898282`)
- `repokit` — читает `APP_SLUG`, `APP_ACTOR_ID`, `GITHUB_APP_ID` из `~/.repokit`, экспортирует в подскрипты
- `ruleset.sh` — добавляет `bypass_actors` с GitHub App если задан `GITHUB_APP_ID`
- `pyproject.toml` — `license-files = ["LICENSE"]` (PEP 639), `major_on_zero = false`, `[tool.mypy] ignore_missing_imports = true`
- `instructions.sh` — убраны инструкции про бот-аккаунт и RELEASE_TOKEN, добавлено APP_ID + APP_PRIVATE_KEY, условное предупреждение если GITHUB_APP_ID не задан
- `CLAUDE.md` — убраны устаревшие упоминания RELEASE_TOKEN и неверное утверждение про bypass_actors

**Решения:**
- `~/.repokit` как конфиг-файл вместо интерактивного ввода — APP_ID один для всех репо, незачем спрашивать каждый раз
- Плейсхолдеры `{{APP_SLUG}}` / `{{APP_ACTOR_ID}}` в шаблонах вместо хардкода — как `{{REPO}}` и `{{OWNER}}`, подстановка через sed в workflows.sh
- Дефолты для плейсхолдеров — `github-actions` / `41898282` (стандартный GitHub Actions бот) если конфиг не задан
- PSR прямым CLI вместо Docker action — нет зависимости от Docker Hub, явный контроль над git config и GH_TOKEN, версия PSR зафиксирована через `.[release]`

**Не делали:**
- `repokit configure` wizard — отложено в backlog
- `allow_zero_version` — пользователь сказал не трогать
- PSR baseline тег v0.0.0 — под сомнением, был разовым манёвром для конкретного репо
- `skip-existing: true` и retry loop в `integration.yml` smoke test — отложено в backlog

**Побочные эффекты:**
- Удалён старый файл `/Users/justin/projects/init_python.sh`
