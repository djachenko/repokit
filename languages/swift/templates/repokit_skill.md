# Интеграция с repokit

Этот пакет настроен repokit. Повторный запуск `repokit --language swift` обновляет файлы ниже — но только пока их последний коммит от repokit: после ручной правки repokit файл больше не трогает.

## Что нельзя делать

- **Редактировать `.github/workflows/*.yml` вручную** — это обёртки над reusable workflow repokit. Менять шаблоны в repokit.
- **Править `.swiftlint_base.yml`** — общие правила SwiftLint, обновляются из repokit.
- **Править `Tests/.swiftlint.yml` и `cog.toml`** — тоже repokit.
- **Ставить и двигать теги руками** — версия пакета существует только как git-тег, в `Package.swift` её нет. Тег ставит release workflow по conventional commits (`fix:` → patch, `feat:` → minor) и двигает плавающие `X.Y` и `X`.

## Что можно

- **`.swiftlint.yml`** — свой файл репо, наследует базу через `parent_config`. Правила под этот репо — сюда, в том числе `strict: false`, чтобы постепенно разгребать warning'и.
