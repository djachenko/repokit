# Интеграция с repokit

Это приложение настроено repokit. Повторный запуск `repokit --language swift-app` обновляет файлы ниже — но только пока их последний коммит от repokit: после ручной правки repokit файл больше не трогает.

## Что нельзя делать

- **Редактировать `.github/workflows/*.yml` вручную** — это обёртки над reusable workflow repokit. Менять шаблоны в repokit.
- **Править `.swiftlint_base.yml`** рядом с проектом — общие правила SwiftLint, обновляются из repokit.
- **Править `.swiftlint.yml` в папках тестов и `cog.toml`** — тоже repokit.
- **Менять `MARKETING_VERSION` и ставить теги руками** — версию пишет release workflow: по conventional commits (`fix:` → patch, `feat:` → minor) обновляет `MARKETING_VERSION` во всех таргетах, коммитит и ставит тег.

## Что можно

- **`.swiftlint.yml` рядом с проектом** — свой файл репо, наследует базу через `parent_config`. Правила под этот репо — сюда, в том числе `strict: false`, чтобы постепенно разгребать warning'и.
- **Схема и test plan** — CI запускает `xcodebuild test` схемы с именем workspace (или проекта); какие тесты гонять, решает её test plan.
