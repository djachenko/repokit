# Backlog

## languages/swift — iOS release pipeline

Добавить поддержку Swift/iOS проектов по аналогии с `languages/python`.

### Что должно появиться

```
languages/swift/
├── instructions.sh
├── setup.sh
└── workflows/
    ├── integration.yml
    └── release.yml
```

### Дизайн пайплайна

**Инструментарий:** fastlane + `fastlane-plugin-semantic_release`.

| Роль | Инструмент |
|---|---|
| Семантическое версионирование | `fastlane-plugin-semantic_release` |
| Сборка `.ipa` | `fastlane gym` (xcodebuild archive) |
| Загрузка | GitHub Releases (бесплатный аккаунт) |
| Runner | `macos-latest` |

**Versioning:**
- `MARKETING_VERSION` — семантическая версия из conventional commits (`feat:` → minor, `fix:` → patch, `feat!:` → major)
- `CURRENT_PROJECT_VERSION` — `GITHUB_RUN_NUMBER`, сквозной, монотонный

**Подпись:** `fastlane match` с приватным репо для сертификатов. Development profile (не Ad Hoc/App Store — платный аккаунт не нужен).

**Триггеры:**
- `integration.yml` — на PR в main: тесты + dry-run build
- `release.yml` — на push в main **и** `schedule: cron` каждые 6 дней (development-сборки экспирируют через 7 дней)

**Артефакт:** `.ipa` публикуется в GitHub Releases. Рядом кладётся `version.json`:
```json
{ "build": 42, "expires_at": "2026-06-15" }
```

### In-app обновление

Приложение при запуске проверяет `version.json` на GitHub. Если `build` новее текущего — планирует локальное уведомление за 1-2 дня до `expires_at`. Тап → экран с инструкцией по установке.

### Установка на устройство (скрипт для пользователя)

```bash
# Скачать свежий ipa
curl -L https://github.com/owner/repo/releases/latest/download/App.ipa -o /tmp/App.ipa

# Установить — с Xcode
if command -v xcrun &>/dev/null; then
    xcrun devicectl device install app --device $UDID /tmp/App.ipa
else
    brew install ideviceinstaller
    ideviceinstaller -i /tmp/App.ipa
fi
```

Пользователю нужен Mac. Windows — отдельная задача.

### Ограничения (бесплатный Apple Developer аккаунт)

- TestFlight недоступен (требует $99/год)
- OTA-установка через браузер недоступна
- Максимум 3 зарегистрированных устройства в год
- UDID каждого устройства нужно добавить в provisioning profile вручную

### Secrets (аналог Python)

| Secret | Назначение |
|---|---|
| `RELEASE_TOKEN` | GitHub PAT для коммита version bump |
| `MATCH_GIT_URL` | Приватный репо с сертификатами |
| `MATCH_PASSWORD` | Пароль шифрования match |
| `MATCH_GIT_BASIC_AUTH` | PAT для доступа к репо с сертификатами |
