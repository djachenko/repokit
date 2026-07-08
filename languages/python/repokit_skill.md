# Интеграция с repokit

Этот проект использует repokit для CI/CD. Repokit управляет `.github/workflows/` и настройкой репозитория.

## Что нельзя делать

- **Редактировать `.github/workflows/*.yml` вручную** — repokit перезапишет их при следующем запуске. Нужно менять шаблоны в repokit и обновлять через `repokit --language python`.
- **Вручную менять `version` в `pyproject.toml`** — версией управляет python-semantic-release (PSR) автоматически. Ручной bump сломает PSR.

## Когда что запускается

| Workflow | Триггер | Что делает |
|----------|---------|------------|
| `tests.yml` | push в любую ветку (кроме master) | pytest + ruff + mypy |
| `integration.yml` | PR в master | матрица OS×Python, публикация на TestPyPI |
| `release.yml` | push в master | PSR тегирует, сборка, публикация на PyPI |

## Флоу релиза

Merge PR в master → PSR автоматически определяет новую версию по коммитам → создаёт тег → собирает wheel/sdist → публикует на PyPI. Ничего делать вручную не нужно.

Версия определяется типом коммитов: `fix:` → patch, `feat:` → minor. `BREAKING CHANGE` → major (но пока `major_on_zero = false`, так что до 1.0.0 major не растёт).

## Mypy и зависимости без стабов

Для зависимостей без стаб-пакетов на PyPI добавить в `pyproject.toml`:

```toml
[[tool.mypy.overrides]]
module = "some_package.*"
ignore_missing_imports = true
```

Не нужно: вручную добавлять `types-*` пакеты в зависимости, прописывать `--ignore-missing-imports` глобально — CI ставит доступные стабы сам.

## Обновление workflows

```
repokit --language python
```

Запускать из корня проекта. Создаст ветку `chore/repokit-setup` и PR с изменениями.
