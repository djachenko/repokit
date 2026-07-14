# repokit — Project Guide

## Цель

Bash-скрипт для бутстрапа новых GitHub-репозиториев. Создаёт репо, инициализирует git, пишет CI workflow-файлы, `pyproject.toml`, применяет ruleset.

Не Python-проект — чистый bash + шаблоны.

---

## Структура

```
repokit/
├── install.sh                     # curl | bash установщик
├── repokit                        # оркестратор (точка входа)
├── init/                          # подскрипты, порядок определяется номером
│   ├── 01_check_tools.sh          # git, gh, gh auth
│   ├── 02_git_init.sh             # git init
│   ├── 03_create_repo.sh          # gh repo create + remote
│   ├── 04_initial_commit.sh       # первый коммит + push
│   ├── 05_branch_prepare.sh       # создаёт / rebase-ит chore/repokit-setup
│   ├── 06_workflows.sh            # копирует wrapper workflows с подстановкой
│   ├── 07_ruleset.sh              # gh api ruleset (required checks, merge-only)
│   └── 08_branch_push.sh          # пушит ветку, открывает PR
└── languages/
    ├── python/
    │   ├── 06_language_setup.sh   # pyproject.toml + Claude skill
    │   ├── instructions.sh        # постустановочный чеклист (только первый запуск)
    │   ├── pyproject.toml         # шаблон, плейсхолдеры {{REPO}} {{OWNER}}
    │   ├── repokit_skill.md       # Claude skill, копируется в .claude/skills/repokit.md
    │   └── wrappers/              # wrapper workflows для клиентских репо
    │       ├── tests.yml
    │       ├── integration.yml
    │       └── release.yml
    └── dotfiles/
        ├── 05_branch_prepare.sh   # override: остаётся на master, не переключает ветку
        ├── 07_ruleset.sh          # override: пустой — dotfiles коммитит прямо в master
        ├── 08_branch_push.sh      # override: только инструкции, без PR
        ├── setup.sh               # кладёт adopt/install/watch/commit/uninstall/restart
        ├── instructions.sh        # постустановочный чеклист
        ├── templates/             # шаблоны скриптов
        └── wrappers/              # пустые yml — CI не нужен
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
3. `run_step 01_check_tools.sh` — проверки, выход с понятной ошибкой
4. Определяет состояние: есть ли локальный git, есть ли remote на GitHub
5. Создаёт git / remote / initial commit только если их нет
6. `run_step 05_branch_prepare.sh` — создаёт или rebase-ит `chore/repokit-setup`
7. `run_step 06_workflows.sh`, `languages/$LANGUAGE/setup.sh`, `run_step 07_ruleset.sh`
8. `run_step 08_branch_push.sh` — пушит ветку, открывает PR
9. `instructions.sh` — только на первом запуске

`run_step` проверяет наличие `languages/$LANGUAGE/<step>` и использует его вместо дефолтного `init/<step>`. Языки могут переопределять любой шаг.

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

`07_ruleset.sh` динамически вычисляет required status checks из wrapper workflows:
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
