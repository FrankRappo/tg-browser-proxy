# tg-browser-proxy

**Telegram в браузерах через SSH-туннель (plink) — только Telegram через тоннель, всё остальное напрямую.**

Публичная документация + скрипты развёртывания. Секреты (пароли, приватные ключи) — в `secrets/`, в git НЕ попадают (см. `.gitignore`).

## Архитектура

```
Браузер (Chrome / Яндекс)
   │  PAC: только telegram-домены → SOCKS5
   ▼
127.0.0.1:8081  HTTP-сервер PAC-файла        (задача «BT-Proxy PAC Server»)
   │
   ▼
proxy.pac: telegram → SOCKS5 127.0.0.1:1080, остальное → DIRECT
   │
   ▼
127.0.0.1:1080  plink -D (SOCKS5)             (задача «BT-Proxy Telegram Tunnel»)
   │  SSH → btproxy@<VPS>  (nologin, только port-forwarding)
   ▼
VPS 5.182.86.160 → интернет (Telegram доступен)
```

Контроль целостности — раз в минуту (задача «BT-Proxy Tunnel Watchdog»): SOCKS-проба,
при сбое перезапуск тоннеля. Для Яндекс-браузера дополнительно «BT-Proxy Yandex Guard» —
восстанавливает настройки в профиле (Яндекс затирает чужие правки при выходе).

## Компоненты

| Компонент | Где | Запуск |
|---|---|---|
| plink-тоннель SOCKS5 | `C:\BT-Proxy\tunnel.cmd` → `plink.exe -D 1080 btproxy@VPS` | задача планировщика, ONSTART+ONLOGON, цикл рестарта 5с |
| PAC-сервер | `C:\BT-Proxy\pac-server.ps1` (HttpListener 8081) | задача планировщика, ONSTART+ONLOGON, цикл рестарта 5с |
| Watchdog | `C:\BT-Proxy\watchdog.ps1` — проба SOCKS раз в 1 мин | задача планировщика, SYSTEM |
| Yandex Guard | `C:\BT-Proxy\ya-guard.ps1` — чинит prefs при закрытом Яндексе | задача планировщика, SYSTEM |
| Chrome-политика | HKLM `SOFTWARE\Policies\Google\Chrome` `ProxyMode=pac_script` + `ProxyPacUrl` | реестр, переживает всё |
| Ярлык Telegram | Рабочий стол + Пуск: Яндекс с чистым профилем `C:\BT-Proxy\ya_tg` + флаг PAC + сразу `/k/` | файлы `.lnk` |

## Почему так (главные уроки)

1. **Chrome** — достаточно одной HKLM-политики `ProxyMode=pac_script` (значение именно
   `pac_script`, НЕ `pac` — невалидное значение Chromium молча игнорирует). Действует при
   любом способе запуска, командные флаги обхода старше не становятся, UI-настройки блокируются.
2. **Яндекс-браузер НЕ читает корпоративные политики вообще** (проверены HKLM/HKCU Chromium-формат
   `Policies\Yandex\YandexBrowser`, родное дерево `SOFTWARE\Yandex\YandexBrowser\Policies`,
   системный WinINET-proxy, флаг `--proxy-pac-url` в дефолтном профиле — всё игнорируется).
   В `Default\Secure Preferences` у него вшит СВОЙ PAC (`pac_url: data:application/...base64`),
   который перекрывает всё. Решение: **отдельный чистый профиль** (`--user-data-dir`) + флаг
   PAC + ярлык «Telegram». Дефолтный профиль для Telegram не использовать.
3. **plink не умеет keepalive** — мёртвое соединение висит вечно. Лечится внешним watchdog'ом
   (проба через SOCKS раз в минуту, при сбое рестарт задачи).
4. **VPS с IPv6-маршрутом, но Telegram по IPv6 недоступен из этой сети VPS** — резолв
   иногда выбирал AAAA → зависания. Фикс: IPv6 отключён на VPS (`sysctl disable_ipv6`).
5. Корневой `web.telegram.org` ведёт на легаси Angular-приложение (белая страница в Яндексе).
   Всегда открывать **`https://web.telegram.org/k/`**.
6. Правки `Preferences` Яндекса живут только пока браузер закрыт: при чистом выходе Яндекс
   переписывает файл из памяти. Guard правит строго при закрытом браузере.

## Быстрая проверка

```bat
:: тоннель жив?
curl.exe -s -o NUL -m 12 --socks5-hostname 127.0.0.1:1080 https://web.telegram.org/k/ && echo OK

:: PAC отдаётся?
curl.exe -s -m 8 http://127.0.0.1:8081/proxy.pac | findstr SOCKS5

:: задачи
schtasks /Query /FO TABLE | findstr /C:"BT-Proxy"
```

## Содержимое репо

- `chrome/` — настройка Chrome (политика, проверка, откат)
- `yandex_broweser/` — настройка Яндекс-браузера (ярлык Telegram, guard, исследование)
- `scripts/` — все скрипты + регистрация задач (пароли через плейсхолдеры)
- `secrets/` — **в git не входит**: пароли VPS/btproxy, приватный ключ канала управления

## Доступы (механика; секреты в secrets/, gitignored)

- **VPS тоннеля**: `root@5.182.86.160`, пароль в `secrets/vps_root_password.txt`.
  SSH-hostkey: `SHA256:sOdOKdjo61OP/czasg5y2dVRR5tBA0avP3jWurO+nrw` (ed25519).
- **Тоннельный юзер**: `btproxy` (nologin; `authorized_keys` — по паролю для plink-сессии
  машины), пароль в `secrets/btproxy_password.txt`.
- **Канал управления машиной** (для удалённой поддержки): reverse-туннель машины на релей
  `217.144.184.51`, порты 2353/2354; вход:
  `ssh -J root@217.144.184.51 -p 2353 User@127.0.0.1 -i secrets/support_ed25519`
  (ключ — копия `/work/help_bat/keys/support_ed25519`).
