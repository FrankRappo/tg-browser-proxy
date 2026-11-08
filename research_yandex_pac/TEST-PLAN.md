# МЕТОДИКА: воспроизводимые тесты (проверяйте руками, не верьте на слово)

## T1. Бинарный тест канала прокси (мёртвый порт)

```bat
:: 1) поставить тестируемый канал на 127.0.0.1:9999 (см. варианты в EVIDENCE.md)
:: 2) убить и запустить Яндекс
taskkill /IM browser.exe /F
ping -n 4 127.0.0.1 >nul
"C:\Program Files\Yandex\YandexBrowser\Application\browser.exe" https://web.telegram.org/k/
:: 3) через ~30 сек:
netstat -ano | findstr ":9999"
powershell -c "(Get-Process browser -EA SilentlyContinue).Id"
:: Есть строки ESTABLISHED/SYN_SENT на 9999 от PID'ов browser.exe → канал РАБОТАЕТ.
:: Пусто → канал игнорируется.
```

## T2. Нетлог-захват прокси-решений

```bat
taskkill /IM browser.exe /F
"C:\Program Files\Yandex\YandexBrowser\Application\browser.exe" ^
  --proxy-pac-url=http://127.0.0.1:8081/proxy.pac ^
  --log-net-log=C:\BT-Proxy\netlog.json --net-log-capture-mode=IncludeSensitive ^
  https://web.telegram.org/k/
:: подождать 30 сек, ЗАКРЫТЬ БРАУЗЕР КРЕСТИКОМ (не taskkill — файл допишется), затем анализировать
```

Анализ (python): события `"type":35` (RESOLVED_PROXY_LIST) — параметр `proxy_chain`;
`"type":40` = PAC_JAVASCRIPT_ERROR. Поиск фетча PAC: строки с `8081` и `HTTP/1.1 200`.
Пример скрипта-парсера см. в истории сессии (регексп по строкам events, JSON обрезан
если браузер убит насильно).

## T3. PAC «всё в SOCKS» (дифференциация «не исполняется» vs «не матчится»)

Заменить содержимое `C:\BT-Proxy\proxy.pac` (сервер 8081 читает файл на каждый запрос):

```js
function FindProxyForURL(url, host) {
  if (shExpMatch(host, "localhost") || shExpMatch(host, "127.0.0.1")) return "DIRECT";
  return "SOCKS5 127.0.0.1:1080";
}
```

Если и при этом весь трафик идёт напрямую (netstat: 0 коннектов к 1080 от browser.exe)
— движок PAC не влияет на дефолтном профиле ВООБЩЕ (факт установлен, см. EVIDENCE #8b).

## T4. Дамп их внутреннего data-PAC (снять на следующей живой машине!)

```powershell
$sp='C:\Users\<user>\AppData\Local\Yandex\YandexBrowser\User Data\Default\Secure Preferences'
$raw=Get-Content $sp -Raw -Encoding UTF8
$m=[regex]::Match($raw,'"pac_url":"(data:[^"]+)"')
$m.Groups[1].Value -replace '^data:.*?base64,','' | ForEach-Object { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) }
```
⚠️ НЕ модифицировать файл до снятия копии (бэкап: `Copy-Item $sp "$sp.bak"`).

## T5. Чистый профиль (контрольная группа)

```
browser.exe --user-data-dir=C:\temp\ya_fresh --proxy-pac-url=http://127.0.0.1:8081/proxy.pac https://web.telegram.org/k/
```
Ожидание: PAC работает (проверено). Использовать как референс при diff-анализе
поведения двух профилей (netlog T2 на обоих, сравнить события 33/34/35).

## T6. Выход из Яндекс-аккаунта / отключение синхронизации (проверка H2)

На дефолтном профиле: браузер → настройки → выключить синхронизацию (или выйти) →
T1/T3 повторить. Если игнор пропал — победа записывается в H2.

## Правила для агента-реверсера (обязательно к передаче вместе с задачей)

- Все файлы — только в папке проекта /work/tg_broweser/, /tmp не использовать.
- Секреты (пароли/ключи) не выносить из secrets/, в git не коммитить (gitignore уже стоит).
- Машина-донор — боевая: ничего не перезапускать/не убивать на ней без команды владельца
  (тоннель и задачи BT-Proxy* не трогать, окно батника поддержки не закрывать).
- >2 неудач на шаг = стоп и отчёт владельцу.
