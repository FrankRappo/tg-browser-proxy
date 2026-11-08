$ErrorActionPreference = 'Stop'
# BT-Proxy: ярлыки для сотрудников
# 1) Chrome: машинная политика ProxyMode=pac_script (см. ../chrome/README.md)
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v ProxyMode   /t REG_SZ /d pac_script /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v ProxyPacUrl /t REG_SZ /d "http://127.0.0.1:8081/proxy.pac" /f

# 2) Яндекс: ярлык «Telegram» с чистым профилем + PAC + сразу /k/ (см. ../yandex_broweser/README.md)
$ws = New-Object -ComObject WScript.Shell
$exe = 'C:\Program Files\Yandex\YandexBrowser\Application\browser.exe'
$arg = '--user-data-dir=C:\BT-Proxy\ya_tg --proxy-pac-url=http://127.0.0.1:8081/proxy.pac --no-first-run --no-default-browser-check https://web.telegram.org/k/'
foreach ($t in @(
  'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Telegram.lnk',
  'C:\Users\Public\Desktop\Telegram.lnk'
)) {
  $s = $ws.CreateShortcut($t)
  $s.TargetPath = $exe
  $s.Arguments = $arg
  $s.WorkingDirectory = 'C:\Program Files\Yandex\YandexBrowser\Application'
  $s.Description = 'Telegram Web via tunnel'
  $s.Save()
  Write-Output ('CREATED: ' + $t)
}
