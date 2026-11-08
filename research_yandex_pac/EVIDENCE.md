# УЛИКИ: все эксперименты и их результаты

Методика бинарных тестов: ставим прокси-настройку на заведомо мёртвый порт
`127.0.0.1:9999`. Если браузер настройку применяет — в netstat появляются его
SYN/коннекты к 9999 (и сайты отваливаются). Ровно так доказано, что Chrome
политики слушается. Яндекс — ни разу.

## Таблица каналов (дефолтный профиль, Яндекс 26.10)

| # | Канал | Факт установки | Результат |
|---|---|---|---|
| 1 | HKLM `SOFTWARE\Policies\Yandex\YandexBrowser`: ProxyMode=fixed_servers, ProxyServer=127.0.0.1:9999 | reg query подтверждён, браузер перезапущен | **игнор**: 0 коннектов к 9999, 16+ прямых ESTABLISHED |
| 2 | HKCU `Software\Policies\Yandex\YandexBrowser` (то же) | подтверждён | **игнор** |
| 3 | HKLM `SOFTWARE\Policies\Chromium` (generic-ключ, то же) | подтверждён | **игнор** |
| 4 | HKLM `SOFTWARE\Yandex\YandexBrowser\Policies` (родное дерево Яндекса, то же) | подтверждён | **игнор** |
| 5 | HKCU `Software\Yandex\YandexBrowser\Policies` (то же) | подтверждён | **игнор** |
| 6 | WinINET: HKCU `...\Internet Settings` ProxyEnable=1, ProxyServer=127.0.0.1:9999 | подтверждён, перезапуск | **игнор**: 0 к 9999, 23 прямых |
| 7 | WinINET: AutoConfigURL=http://127.0.0.1:8081/proxy.pac (HKCU и HKLM Policies) | подтверждён | **игнор**: 0 фетчей 8081 от browser.exe |
| 8 | Флаг `--proxy-pac-url=http://127.0.0.1:8081/proxy.pac` | виден в Win32_Process CommandLine | **PAC скачивается, но резолвы = direct://** (нетлог) |
| 8b | Тот же флаг + PAC «всё в SOCKS5» (кроме localhost) | сервер отдаёт (curl видит) | **всё равно direct**: 0 коннектов к 1080, 21 прямой |
| 9 | Prefs-инъекция `proxy:{mode:pac_script,pac_url:file:///C:/BT-Proxy/proxy.pac}` в `Default\Preferences` | проверено на диске до запуска | **работает ~интермиттирующе**: 2 раза QR грузился (скриншоты), чаще direct; при чистом выходе Яндекс переписывает Preferences из памяти и затирает чужие ключи |
| 10 | Замена их `pac_url` (data:...) на `file:///C:/BT-Proxy/proxy.pac` в Secure Preferences | REPLACE подтверждён на диске | файл при следующем старте пересобирается (94172 → 19359 байт), их узел исчезает, наш PAC всё равно не применяется |

## Ключевые факты из netlog (файл `evidence/netlog.json`, обрезан брутальным kill'ом)

Захват: `browser.exe --proxy-pac-url=http://127.0.0.1:8081/proxy.pac --log-net-log=C:\BT-Proxy\netlog.json --net-log-capture-mode=IncludeSensitive`

- `{"pac_url":"http://127.0.0.1:8081/proxy.pac"}`, source: `Custom PAC URL` — флаг виден.
- Фетч PAC: `HTTP/1.1 200 OK`, `Content-Length: 388`, `Content-Type: application/x-ns-proxy-autoconfig`.
- Резолв `https://web.telegram.org/k/` → `"proxy_chain":"[direct://]"` (тип 35 RESOLVED_PROXY_LIST).
- Событий PAC_JAVASCRIPT_ERROR (тип 40) в events-секции **нет** — скрипт не падает, просто не влияет.
- `PROXY_RESOLUTION_SERVICE_WAITING_FOR_INIT_PAC` (34) — 93 события, инициализация PAC-резолвера шла.

## Что работает (для полноты картины)

- **Свежий профиль** + флаг 8 → PAC исполняется, SOCKS-тоннель используется, QR Telegram загружается. Доказано многократно (скриншоты, netstat: 7+ ESTABLISHED на 127.0.0.1:1080).
- **Chrome 157** на той же машине: HKLM-политика `ProxyMode=pac_script` + `ProxyPacUrl` → работает при любом запуске. Значит сам PAC-сервер, PAC-скрипт и тоннель корректны.
- plink-тоннель и PAC-сервер поднимаются службами; SOCKS-проба через `curl.exe --socks5-hostname` — OK.

## Состояние дефолтного профиля, важное для реверса

- `Default\Secure Preferences` содержал их узел `proxy.pac_url = data:...base64,Y29uc3QgY291bnRyaWVzP...`
  (полный base64 на живой машине не успели снять — узел удалён в ходе экспериментов;
  префикс `Y29uc3QgY291bnRyaWVzP` = `const countriesP`).
- После наших правок файл был пересобран браузером до 19359 байт (защищённые MAC-значения сброшены).
- Профиль залогинен в Яндекс-аккаунт: настройки могут восстанавливаться облачной синхронизацией.
