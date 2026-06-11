# backlog — Идеи и отложенные фичи

<!-- Эта строка читается всегда. Остальное — по требованию. -->

### `repokit configure` — wizard первичной настройки

Идея: команда `repokit configure` (или wizard при первом запуске), которая интерактивно создаёт `~/.repokit`.

Сейчас `~/.repokit` нужно создавать вручную с `GITHUB_APP_ID=<id>`. Wizard мог бы:
1. Запросить список установленных GitHub Apps через gh API:
   ```bash
   gh api /user/installations --jq '.installations[] | {id: .app_id, name: .app_slug}'
   ```
   Если скоупы позволяют — показать список на выбор. Если нет — спросить вручную.
2. Записать результат в `~/.repokit`, включая `APP_SLUG` и `APP_ACTOR_ID`.

Это отдельная фича, не блокирует текущий PR.
