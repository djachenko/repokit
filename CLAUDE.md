# repokit — Project Guide

## Цель

Bash-скрипт для бутстрапа новых GitHub-репозиториев. Создаёт репо, инициализирует git, пишет CI workflow-файлы, `pyproject.toml`, применяет ruleset.

Bash + шаблоны + Go-бинарь `repokore` для логики, которую bash тянет плохо (разбор форматов, обработка данных). Решение по языку: [`_claude/backlog/26.07.29.decision-implementation-language`](_claude/backlog/26.07.29.decision-implementation-language.md).

**Граница исполнения:** repokore — только локальная машина (установка, настройка репо, git-хуки, dotfiles). Всё, что крутится на CI-раннере, в него не переносится: установки repokit там нет. Поэтому `.github/actions/python-versions/get_versions.py` остаётся Python — единственный Python в проекте.

Бинарь обязателен: `install.sh` падает, если не смог его скачать, `01_check_tools.sh` проверяет наличие.

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
├── hooks/
│   └── pre-push                   # проверка author email, парсинг через repokore
├── scripts/
│   └── repokore/                  # Go: одна команда = строка в switch + пакет в internal/
│       ├── main.go                # диспетчер сабкоманд, больше ничего
│       └── internal/
│           ├── commands/          # разбор флагов, по файлу на команду
│           ├── config/            # формат .repokit (key=value)
│           ├── template/          # {{REPO}}/{{OWNER}}/{{VERSION}} + sha256
│           ├── pyproject/         # точечный merge TOML поверх lossless AST
│           ├── workflow/          # разбор workflow YAML, терминальная джоба
│           ├── gitignore/         # идемпотентный append + скан секретов
│           ├── authors/           # pre-push протокол и git log
│           └── changes/           # группировка git status по областям
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
├── python-release.yml
├── bash-tests.yml                 # собственный CI repokit: shellcheck + shfmt
├── bash-integration.yml           # заглушка, пока только checkout
├── bash-release.yml               # PSR + тег + обновление floating tag в wrappers
├── go-tests.yml                   # gofmt + vet + test для repokore
└── go-release.yml                 # кросс-компиляция repokore в артефакт
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

## repokore

Новая команда = строка в `switch` внутри `main.go` + пакет в `internal/`. Диспетчер без логики, логика без флагов.

| Команда | Кто зовёт |
|---------|-----------|
| `merge-pyproject` | `06_language_setup.sh` |
| `render-template` | `06_workflows.sh`, `06_language_setup.sh` |
| `config get/set` | оркестратор, `05_branch_prepare.sh`, `07_ruleset.sh` |
| `ruleset-checks` | `07_ruleset.sh` |
| `gitignore add/sensitive` | оркестратор, `dotfiles/setup.sh` |
| `check-authors ranges/filter` | `hooks/pre-push` |
| `group-changes keys/paths/message` | `dotfiles/templates/commit` |

Exit-код **3** у `merge-pyproject` = «шаблон не менялся», в отличие от `1` = ошибка.

Тесты: `cd scripts/repokore && go test ./...`. Без `./...` ничего не найдёт — в корневом пакете только `main.go`.

Merge правит текст поверх lossless AST, а не парсит в дерево и сериализует обратно. Тесты на него сравнивают **байты**, а не эквивалентность TOML: этот класс багов уже один раз проскочил мимо тестов на эквивалентность.

---

## Шаблоны и подстановка

Плейсхолдеры в wrapper workflows: `{{REPO}}`, `{{VERSION}}`.

`{{VERSION}}` — major.minor repokit (например `0.9`), чтобы patch-обновления repokit не требовали пересоздания workflows в клиентских репо. Сокращение делает `render-template`, ему передаётся полная версия. При запуске из source (нет файла `VERSION`) подставляется `master`.

Шаблоны — настоящие YAML/TOML файлы, редактируются напрямую.

---

## CI схема

**tests.yml** (wrapper) — push на любую ветку кроме master → `python-tests.yml`: pytest + ruff + mypy.
Тесты на master не гоняются — они уже прошли через integration до merge.

**integration.yml** (wrapper) — PR в master → `python-integration.yml`: матрица OS×Python (ubuntu/macos/windows × 3.10–3.x), pytest, затем сборка + TestPyPI + smoke test.

**release.yml** (wrapper) — push в master → `python-release.yml`: PSR тегирует, сборка, PyPI. Использует GitHub App token (APP_CLIENT_ID + APP_PRIVATE_KEY) для push тега обходя branch protection.

Версия определяется PSR по типам коммитов: `fix:` → patch, `feat:` → minor. Старт с `0.0.0`.

### Собственный CI repokit

Выше описано то, что уезжает в клиентские репо. У самого repokit схема своя:

**tests.yml** — push на любую ветку → `bash-tests.yml` (shellcheck + shfmt) и `go-tests.yml` (gofmt + vet + test) двумя параллельными джобами. Go-тесты стоят здесь, а не только в релизе: иначе сломанный бинарь блокирует релиз уже после мержа, вместо того чтобы блокировать PR.

**release.yml** — push в master, три джобы по порядку:

1. `build-go` → `go-release.yml`: кросс-компиляция `darwin/{amd64,arm64}` + `linux/{amd64,arm64}`, выгрузка артефакта `go-binaries`
2. `release` → `bash-release.yml`: PSR тегирует, отдаёт наружу `released` и `version`
3. `upload-go`: скачивает артефакт и `gh release upload` — только при `released == 'true'`

Сборка идёт **первой** осознанно: сломанный бинарь должен блокировать релиз, а не следовать за ним.

`install.sh` качает готовый ассет `repokore-<os>-<arch>` — Go у пользователя не нужен.

---

## Ruleset

`07_ruleset.sh` динамически вычисляет required status checks из wrapper workflows:
- `repokore ruleset-checks` парсит jobs в `tests.yml` и `integration.yml`, для reusable-джоб раскрывает terminal job из вызываемого файла и отдаёт готовый JSON-массив. Неоднозначная terminal job — ошибка, а не выбор наугад
- Скрипт применяет ruleset через GitHub API (delete + create)

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
