# init_python — Project Guide

## Цель

Bash-скрипт для бутстрапа новых Python GitHub-репозиториев. Создаёт репо, инициализирует git, пишет CI workflow-файлы, `pyproject.toml`, применяет ruleset, выводит чеклист.

Не Python-проект — чистый bash + шаблоны.

---

## Структура

```
init_python/
├── install.sh           # добавляет папку в PATH (.zshrc/.bashrc)
├── repokit       # оркестратор
├── init/
│   ├── preflight.sh     # проверяет git, gh, gh auth
│   ├── repo.sh          # gh repo create + git init + remote
│   ├── workflows.sh     # копирует шаблоны workflow с подстановкой {{REPO}}
│   ├── pyproject.sh     # копирует pyproject.toml с подстановкой {{REPO}}/{{OWNER}}
│   ├── commit.sh        # git add + commit + push -u origin master
│   ├── ruleset.sh       # gh api ruleset
│   └── instructions.sh  # постустановочный чеклист
└── templates/
    ├── pyproject.toml
    └── workflows/
        ├── tests.yml
        ├── integration.yml
        └── release.yml
```

---

## Как работает оркестратор

1. `--help` / `-h` — справка и выход
2. `REPO` = `$(basename "$PWD")` — имя всегда из текущей папки
3. `preflight.sh` — проверки, выход с понятной ошибкой если что-то не так
4. `OWNER` = `gh api user --jq '.login'` — после preflight, гарантированно работает
5. Подтверждение: `Init repo 'owner/repo' in ...? [y/N]`
6. Последовательный запуск подскриптов

---

## Шаблоны

Плейсхолдеры: `{{REPO}}`, `{{OWNER}}`.

Подстановка через `sed` при копировании в `workflows.sh` и `pyproject.sh`.

Шаблоны — настоящие YAML/TOML файлы, редактируются независимо.

---

## CI схема (что генерируется)

**tests.yml** — push на любую ветку, ubuntu + 3.x, pytest + ruff + mypy. Pytest с `|| [ $? -eq 5 ]` — 0 тестов не ломает CI.

**integration.yml** — PR на master, два job-а:
- `test` — матрица OS × python (ubuntu/macos/windows × 3.10–3.x), pytest
- `integration` — depends on test, merge master → PSR version (no commit) → dev suffix (.devN) → build → TestPyPI → smoke test

**release.yml** — push на master, PSR + PyPI (OIDC Trusted Publisher) + smoke test. Использует `RELEASE_TOKEN` для checkout и PSR.

---

## Ruleset

- Только merge (no squash, no rebase)
- Required status check: `integration` (один контекст, не матрица)
- Без `bypass_actors` (не работает для personal repos через API)

---

## Постустановочный чеклист (instructions.sh)

1. `RELEASE_TOKEN` secret в репо — PAT бот-аккаунта, scope `contents: write`
2. Бот-аккаунту write access к репо
3. Trusted Publisher на PyPI — workflow: `release.yml`
4. Trusted Publisher на TestPyPI — workflow: `integration.yml`

---

## Известные ограничения / TODO

- Smoke test в шаблонах предполагает что у пакета есть CLI-команда (`{{REPO}} --help`). Для библиотек без CLI надо менять вручную.
- `pyproject.toml` шаблон минимальный — `description`, `classifiers`, `dependencies` добавляются вручную после.
- Старый файл `/Users/justin/projects/repokit` — удалить.
