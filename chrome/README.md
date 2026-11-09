# Chrome — Telegram через plink-тоннель (только Telegram)

## Принцип

Одна машинная политика реестра заставляет Chrome при **любом** запуске (ярлык, панель,
exe, автозапуск) использовать PAC-файл. Политика:
- перекрывает командные флаги и настройки UI (прокси в настройках серые),
- переживает обновления Chrome и перезагрузки (реестр машины),
- требует, чтобы PAC-сервер был жив (у нас: задача `BT-Proxy PAC Server`).

⚠️ Значение `ProxyMode` должно быть **`pac_script`**. Значение `pac` невалидно — Chromium
его молча игнорирует и остаётся без прокси (нашли опытным путём через netstat+netlog).

## Установка (запуск на целевой машине, права администратора)

```bat
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v ProxyMode   /t REG_SZ /d pac_script /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v ProxyPacUrl /t REG_SZ /d "http://127.0.0.1:8081/proxy.pac" /f
```

PAC-файл (см. `../scripts/`, раздаётся локальным сервером на 127.0.0.1:8081):

```js
function FindProxyForURL(url, host) {
  if (dnsDomainIs(host, ".telegram.org") ||
      dnsDomainIs(host, ".t.me") ||
      dnsDomainIs(host, ".telegram.me") ||
      dnsDomainIs(host, ".telesco.pe") ||
      dnsDomainIs(host, ".telegram.dog")) {
    return "SOCKS5 127.0.0.1:1080";
  }
  return "DIRECT";
}
```

Дополнительно (страховка, не обязательно): системный PAC
`HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` → `AutoConfigURL` =
`http://127.0.0.1:8081/proxy.pac` и машинный
`HKLM\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\AutoConfigURL`.

## Проверка

1. `chrome://policy` → политики ProxyMode/ProxyPacUrl видны, статус OK.
2. Открыть `https://web.telegram.org/k/` → QR-код рисуется (вебсокет-хост
   `venus.web.telegram.org` должен проходить через тоннель — см. урок про IPv6 в корневом README).
3. Остальные сайты — без изменений (PAC возвращает DIRECT).
4. Сеть: во время загрузки телеграма `netstat -ano | findstr ":1080"` показывает
   ESTABLISHED-коннекты chrome.exe.

Для удалённой автоматической проверки используйте `../scripts/remote_proxy_verify.ps1`
и CDP-скрипт `../scripts/remote_chrome_cdp_verify.ps1`. На Chrome 157 пустой вывод
`--dump-dom` через PowerShell не является признаком ошибки: сначала смотрите PAC и
CDP-результат (`cdpTargetUrl`/`cdpTargetTitle`). Подробный разбор ложно-негативной
проверки — в [INCIDENT-2026-11-09.md](INCIDENT-2026-11-09.md).

## Откат

```bat
reg delete "HKLM\SOFTWARE\Policies\Google\Chrome" /v ProxyMode /f
reg delete "HKLM\SOFTWARE\Policies\Google\Chrome" /v ProxyPacUrl /f
```

## Уроки

- `ProxyMode=pac` (вместо `pac_script`) — политика не работает, браузер молча идёт напрямую.
- На дефолтном профиле Chrome 136+ флаг `--remote-debugging-port` блокируется — CDP-диагностика
  только на отдельном `--user-data-dir`.
- `--dump-dom` через удалённый PowerShell может вернуть пустой файл без stderr; для приёмки
  используйте CDP-проверку отдельного профиля, а не только длину DOM.
- Если тоннель в момент загрузки страницы перезапускается — страница покажет таймаут;
  F5 через 20–30 секунд (watchdog чинит тоннель за ~30 с).
