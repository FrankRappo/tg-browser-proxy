# Яндекс-браузер — Telegram через plink-тоннель (только Telegram)

## Итоговое решение

**Отдельный значок «Telegram»**, который запускает Яндекс-браузер с ЧИСТЫМ профилем,
флагом PAC и сразу на рабочей странице:

```
Цель:   C:\Program Files\Yandex\YandexBrowser\Application\browser.exe
Аргументы:
  --user-data-dir=C:\BT-Proxy\ya_tg
  --proxy-pac-url=http://127.0.0.1:8081/proxy.pac
  --no-first-run --no-default-browser-check
  https://web.telegram.org/k/
```

Ярлыки создаются скриптом `../scripts/make-shortcuts.ps1` (рабочий стол `C:\Users\Public\Desktop\Telegram.lnk`
+ Пуск `...\Start Menu\Programs\Telegram.lnk`). Проверено: QR загружается через тоннель,
7+ ESTABLISHED-коннектов на 127.0.0.1:1080 от browser.exe.

⚠️ Дефолтный профиль Яндекса для Telegram НЕ использовать — см. «Исследование» ниже.

## Почему не работают «обычные» способы (исследование, проверено бинарными тестами)

Тест-метод: временно ставить прокси на мёртвый порт `127.0.0.1:9999`; рабочий канал обязан
показать SYN/коннекты на 9999. Яндекс их не показал НИ РАЗУ на всех перечисленных каналах:

| Канал | Результат |
|---|---|
| HKLM `SOFTWARE\Policies\Yandex\YandexBrowser` (Chromium-формат, `ProxyMode`) | игнорируется |
| HKCU `Software\Policies\Yandex\YandexBrowser` | игнорируется |
| HKLM `SOFTWARE\Policies\Chromium` | игнорируется |
| Родное дерево `HKLM\SOFTWARE\Yandex\YandexBrowser\Policies` | игнорируется |
| Системный WinINET (ProxyEnable/ProxyServer) | игнорируется |
| Системный PAC (AutoConfigURL HKCU/HKLM) | игнорируется |
| Флаг `--proxy-pac-url` в дефолтном профиле | PAC скачивается (видно в netlog, HTTP 200 с 127.0.0.1:8081), но решения отдаются как `[direct://]` |
| Prefs-инъекция `proxy:{mode:pac_script}` в `Default\Preferences` | работает ТОЛЬКО пока Яндекс закрыт; при чистом выходе Яндекс перезаписывает файл из памяти и затирает чужие ключи (поэтому у нас guard правит строго при закрытом браузере) |

**Корень**: в `Default\Secure Preferences` Яндекс держит СВОЙ PAC —
`"proxy":{"mode":"pac_script","pac_url":"data:application/x-ns-proxy-autoconfig;base64,<их скрипт стран-маршрутов>"}`
— который перекрывает всё перечисленное в дефолтном профиле. Удаление/подмена этого ключа
работает до первой синхронизации настроек.

Дополнительно: корневой `web.telegram.org` отдаёт легаси Angular-приложение, которое в
Яндексе даёт вечную белую страницу. Рабочее приложение — только `https://web.telegram.org/k/`.

## Дополнительно: guard (самовосстановление)

Задача `BT-Proxy Yandex Guard` (SYSTEM, раз в минуту, скрипт `../scripts/ya-guard.ps1`):
- работает только когда Яндекс ЗАКРЫТ;
- восстанавливает в `Default\Preferences`: `proxy` (PAC), `session.restore_on_startup=4`,
  `session.startup_urls=[https://web.telegram.org/k/]`, `profile.exit_type=Normal`;
- при сбое перезапускает тоннель.

## Проверка

1. Запустить ярлык **Telegram** → вкладка `/k/` → QR-код.
2. `netstat -ano | findstr ":1080"` → ESTABLISHED от browser.exe.
3. Обычные сайты в этом окне — напрямую (PAC: telegram→SOCKS, остальное→DIRECT).

## Ограничение (честно)

Яндекс без политик: если сотрудник сам залезет в `browser://tune`/настройки прокси в ЭТОМ
(dedicated) профиле — сможет сломать. Дефолтный профиль телеграм не откроет в принципе
(это и есть защита «по-другому не получится»). Для жёсткого принуждения используйте Chrome.
