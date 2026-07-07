# repokit — Project Guide

## Status

- **Последнее** — fix: replace shell rc block with sourced shell.sh (PR #47, merged, 0.9.9). .zshrc больше не коррупируется.
- **Следующее** — merge PR #48 (readability refactor), проверить реальную установку после 0.9.9
- **Блокеры** — —
- **Состояние** — активная разработка

## Цель

Bash-скрипт для бутстрапа новых GitHub-репозиториев. Создаёт репо, инициализирует git, пишет CI workflow-файлы, `pyproject.toml`, применяет ruleset.

Не Python-проект — чистый bash + шаблоны.

---

## Структура

```
repokit/
├── install.sh                     # curl | bash установщик
├── repokit                        # оркестратор (точка входа)
├── init/                          # подскрипты, вызываются в порядке номеров
│   ├── 01_check_tools.sh          # git, gh, gh auth
│   ├── 02_git_init.sh             # git init
│   ├── 03_create_repo.sh          # gh repo create + remote
│   ├── 04_initial_commit.sh       # первый коммит + push
│   ├── 05_workflows.sh            # копирует wrapper workflows с подстановкой
│   └── 07_ruleset.sh              # gh api ruleset (required checks, merge-only)
└── languages/
    └── python/
        ├── 06_language_setup.sh   # pyproject.toml + Claude skill
        ├── instructions.sh        # постустановочный чеклист (только первый запуск)
        ├── pyproject.toml         # шаблон, плейсхолдеры {{REPO}} {{OWNER}}
        ├── repokit_skill.md       # Claude skill, копируется в .claude/skills/repokit.md
        └── wrappers/              # wrapper workflows для клиентских репо
            ├── tests.yml
            ├── integration.yml
            └── release.yml
```

Reusable workflows (не попадают в клиентские репо):

```
.github/workflows/
├── python-tests.yml
├── python-integration.yml
└── python-release.yml
```

---

## Как работает оркестратор

1. Читает `.repokit` (язык, base branch) если файл существует — повторный запуск
2. Парсит флаги: `--language`, `--force-workflows`, `--force-pyproject`
3. `01_check_tools.sh` — проверки, выход с понятной ошибкой
4. Определяет состояние: есть ли локальный git, есть ли remote на GitHub
5. Создаёт git / remote / initial commit только если их нет
6. Создаёт или rebases ветку `chore/repokit-setup` на base branch
7. Запускает `05_workflows.sh`, `${LANGUAGE}_setup.sh`, `06_ruleset.sh`
8. Пушит ветку, открывает PR
9. `instructions.sh` — только на первом запуске (когда `.repokit` не было до старта)

---

## Шаблоны и подстановка

Плейсхолдеры в wrapper workflows: `{{REPO}}`, `{{VERSION}}`.

`{{VERSION}}` — major.minor repokit (например `0.9`), чтобы patch-обновления repokit не требовали пересоздания workflows в клиентских репо. При запуске из source (нет файла `VERSION`) подставляется `master`.

Шаблоны — настоящие YAML/TOML файлы, редактируются напрямую.

---

## CI схема

**tests.yml** (wrapper) — push на любую ветку кроме master → `python-tests.yml`: pytest + ruff + mypy.
Тесты на master не гоняются — они уже прошли через integration до merge.

**integration.yml** (wrapper) — PR в master → `python-integration.yml`: матрица OS×Python (ubuntu/macos/windows × 3.10–3.x), pytest, затем сборка + TestPyPI + smoke test.

**release.yml** (wrapper) — push в master → `python-release.yml`: PSR тегирует, сборка, PyPI. Использует GitHub App token (APP_CLIENT_ID + APP_PRIVATE_KEY) для push тега обходя branch protection.

Версия определяется PSR по типам коммитов: `fix:` → patch, `feat:` → minor. Старт с `0.0.0`.

---

## Ruleset

`06_ruleset.sh` динамически вычисляет required status checks из wrapper workflows:
- Парсит jobs в `tests.yml` и `integration.yml`
- Для reusable workflow jobs раскрывает terminal job из reusable файла
- Применяет ruleset через GitHub API (delete + create)

Правила: только merge (no squash, no rebase), required checks, no force-push.

---

## Постустановочный чеклист

1. GitHub App: создать, дать permissions Contents(write) + Metadata(read), установить на репо
2. Secrets: `APP_CLIENT_ID`, `APP_PRIVATE_KEY`
3. Trusted Publisher PyPI: workflow `languages/python/workflows/release.yml`
4. Trusted Publisher TestPyPI: workflow `languages/python/workflows/integration.yml`

---

## Известные ограничения

- Smoke test предполагает что пакет импортируется по имени репо. Для пакетов с другим import name — менять вручную.
- `pyproject.toml` минимальный — `description`, `classifiers`, `dependencies` добавляются вручную.
