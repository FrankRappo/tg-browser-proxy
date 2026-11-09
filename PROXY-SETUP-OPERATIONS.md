# Операционная инструкция: прокси для Chrome и Яндекс.Браузера

Документ описывает, что делать при каждом новом подключении ПК через BAT-канал поддержки и как настроить Telegram-only прокси для Chrome и Яндекс.Браузера.

## 1. Подключение к новому ПК

1. Убедиться, что пользователь запустил BAT и на экране есть `[STEP 4] OK - connected`.
2. Определить профиль BAT (например, `babaeva`) и актуальное имя Windows-пользователя.
3. Проверить relay-порты профиля: `ssh root@217.144.184.51 "ss -H -ltn | grep -E ':23(3|4|5|6|7)[0-9]'"`.
4. Проверить свежую регистрацию в `/home/help_<profile>/pc-reg.log` и stage-маяки в `/var/log/nginx/access.log` (`/support/bt/<profile>/<PC>/<stage>`).
5. Подключиться к ПК:

   ```bash
   SUPPORT_WIN_USER='<имя пользователя Windows>' \
     bash /work/help_bat/support_enter.sh <profile> 'whoami & hostname & ver'
   ```

   Если при входе появляется `REMOTE HOST IDENTIFICATION HAS CHANGED` — сменился ПК за общим портом профиля. Удалить устаревший ключ и повторить вход:

   ```bash
   ssh-keygen -f /work/help_bat/operators/<profile>/windows_known_hosts -R '[127.0.0.1]:<порт>'
   ```

6. Если `SUPPORT_WIN_USER` неизвестен — взять его из `/home/help_<profile>/pc-reg.log` (формат `PC/USERNAME`) или из диагностики в `/home/help_<profile>/diagnostics/`.

## 2. Установка прокси на ПК

Все действия выполняются через канал поддержки, без изменения локального стенда.

1. Создать каталоги на ПК: `C:\BT-Proxy\`, `C:\BT-Proxy\ya_tg\`.
2. Загрузить файлы из репозитория в `C:\BT-Proxy\`:
   - `scripts/proxy.pac`
   - `scripts/pac-server.ps1`
   - `scripts/pac-start.cmd`
   - `scripts/watchdog.ps1`
3. Загрузить одноразовый файл пароля туннеля в `C:\BT-Proxy\.btproxy_password.tmp` (из `secrets/btproxy_password.txt`, пароль никуда не выводить).
4. Загрузить и запустить `scripts/remote_proxy_prepare.ps1` — скачает официальный `plink.exe` и проверит подпись.
5. Загрузить и запустить `scripts/remote_proxy_install.ps1` — создаст `tunnel.cmd`, задачи, политику Chrome и ярлык Яндекс.
6. Загрузить и запустить `scripts/remote_proxy_verify.ps1` для проверки.
7. Удалить временные файлы с ПК.

## 3. Что устанавливается

- PAC-сервер `127.0.0.1:8081` — отдаёт `proxy.pac`.
- SOCKS5-туннель `127.0.0.1:1080` через `plink` к VPS Telegram.
- Watchdog — раз в минуту проверяет туннель и перезапускает его.
- Chrome: HKLM `SOFTWARE\Policies\Google\Chrome` `ProxyMode=pac_script`, `ProxyPacUrl=http://127.0.0.1:8081/proxy.pac`.
- Яндекс: ярлык `Telegram` с отдельным профилем `C:\BT-Proxy\ya_tg` и PAC-флагом.
- PAC направляет Telegram-домены в SOCKS5, всё остальное — напрямую.

## 4. Проверка после установки

```text
pacHttp=200
pacHasTelegramRule=true
pacHasSocksRule=true
pacHasDirectFallback=true
socksTelegramExit=0
chromeProxyMode=pac_script
chromeProxyPacUrl=http://127.0.0.1:8081/proxy.pac
```

Проверить ярлык Яндекс: TargetPath должен указывать на `browser.exe`, Arguments должны содержать `--user-data-dir=C:\BT-Proxy\ya_tg` и `--proxy-pac-url=http://127.0.0.1:8081/proxy.pac`.

## 5. Типовые проблемы

- `REMOTE HOST IDENTIFICATION HAS CHANGED` — сменился ПК за портом профиля; обновить `known_hosts` командой из раздела 1.
- `Permission denied (publickey)` — неверный `SUPPORT_WIN_USER`; взять имя из регистрации.
- Порты профиля не слушают — BAT не поднял reverse-туннель; проверить маячки и окно BAT.
- `pacHttp=ERROR` — PAC-сервер не запущен; проверить задачу `BT-Proxy PAC Server`.
- `socksTelegramExit` не равен 0 — проверить `plink.exe`, задачу `BT-Proxy Telegram Tunnel` и порт 1080.
- Chrome не применяет PAC — проверить `chrome://policy` и значение `ProxyMode=pac_script`.
- Первая headless-проверка Chrome вернула `domLen=0` — это не повод менять PAC. На Chrome 157
  `--dump-dom` через PowerShell может молча не сохранять stdout; сначала проверить PAC и
  реестр, затем CDP-скриптом `scripts/remote_chrome_cdp_verify.ps1` дождаться
  `cdpTargetUrl=https://web.telegram.org/k/` и `cdpTargetTitle=Telegram Web`.
- Яндекс не открывает Telegram — использовать только ярлык `Telegram`, корневой `web.telegram.org` не использовать.

Подробный разбор ложно-негативной проверки Chrome и причины ошибки `9009` в probe `.cmd` —
в `chrome/INCIDENT-2026-11-09.md`.

## 6. Безопасность

- Пароли и ключи остаются в `secrets/` и не попадают в git.
- После установки удалить `.btproxy_password.tmp` и временные скрипты с ПК.
- Не останавливать BAT и не трогать сторонние процессы пользователя.
