# Codex RU Dictation Fix

Фикс вставки текста из глобальной диктовки OpenAI Codex Desktop при русской раскладке клавиатуры на macOS.

## Проблема

Codex Desktop после диктовки кладёт распознанный текст в clipboard и вызывает paste через AppleScript:

```applescript
tell application "System Events" to keystroke "v" using command down
```

На английской раскладке это работает как `Cmd+V`. На русской раскладке символ `"v"` не маппится на физическую клавишу V, поэтому вставка не происходит — голос записывается, текст распознаётся, но не вставляется.

Upstream issue: [openai/codex#19710](https://github.com/openai/codex/issues/19710)

## Решение

Небольшой one-shot AppleScript, который запускается **только** когда файл `~/.codex/transcription-history.jsonl` изменяется (то есть когда завершается диктовка). Проверяет русскую раскладку и вставляет текст через `key code 9` (физическая клавиша V, независима от раскладки).

### Чем отличается от [оригинального фикса](https://github.com/iAlexeyRu/Codex-dictation-fix)

| | Оригинал | Этот фикс |
|---|---|---|
| Механизм | Polling каждые 50мс (20 раз/сек) | macOS `WatchPaths` (kernel-level событие) |
| Нагрузка | Постоянная (`tail`, `python3` спавнятся непрерывно) | Нулевая, пока нет диктовки |
| Запуск | `RunAtLoad` + бесконечный цикл | Запускается один раз при изменении файла |
| Архитектура | Daemon (всегда работает) | One-shot (запустился, сделал, завершился) |

## Установка

```bash
cd ~/Documents/codex-ru-dictation-fix
chmod +x install.sh uninstall.sh
./install.sh
```

После установки добавьте приложение в **Accessibility**:

```
System Settings → Privacy & Security → Accessibility → + → /Applications/Codex RU Dictation Fix.app
```

Без этого macOS не разрешит скрипту отправлять нажатия клавиш.

## Удаление

```bash
./uninstall.sh
```

При необходимости удалите приложение из Accessibility вручную.

## Как работает

1. Диктуете текст (Fn или другая горячая клавиша)
2. Codex записывает результат в `~/.codex/transcription-history.jsonl`
3. macOS kernel замечает изменение файла и запускает `Codex RU Dictation Fix.app`
4. Скрипт проверяет: русская раскладка? этот `id` транскрипции ещё не обрабатывался?
5. Если да — отправляет `Cmd+V` через `key code 9` (раскладко-независимо)
6. Скрипт завершается. Никакого фонового процесса до следующей диктовки.

## Требования

- macOS 13+
- OpenAI Codex Desktop с настроенной глобальной диктовкой
- Русская раскладка клавиатуры в системе

## Лог

```
~/.codex/log/codex-ru-dictation-fix.log
```
