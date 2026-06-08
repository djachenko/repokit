# initial-build — Первичная сборка проекта init_python с нуля

<!-- Эта строка читается всегда. Остальное — по требованию. -->

### 2026-06-08 — Спроектировали и написали весь проект init_python

Переписали старый монолитный `init_python.sh` (лежал в корне `projects/`) в полноценный проект: оркестратор + подскрипты + шаблоны. Проект живёт в `/Users/justin/projects/init_python/`, git инициализирован локально, на GitHub пока не выложен. Старый файл `/Users/justin/projects/init_python.sh` остался — нужно удалить. CI схема: `tests.yml` (push, без матрицы), `integration.yml` (PR на master, матрица в job `test` + PSR/TestPyPI в job `integration`), `release.yml` (push на master, PSR + PyPI OIDC). Smoke test предполагает CLI-команду `{{REPO}} --help` — для библиотек без CLI надо менять вручную.
