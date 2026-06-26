# Интеграция с repokit

Этот проект использует repokit для CI. Repokit берёт на себя:
- тесты, линт, mypy — `tests.yml`
- матрицу OS×Python и публикацию на TestPyPI — `integration.yml`
- релиз через PSR и публикацию на PyPI — `release.yml`

## Что делает проект сам

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
