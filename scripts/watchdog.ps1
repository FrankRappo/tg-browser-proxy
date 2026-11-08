$ErrorActionPreference = 'Continue'
# BT-Proxy Tunnel Watchdog: раз в минуту проверяет SOCKS-тоннель, при сбое перезапускает задачу тоннеля
$log = 'C:\BT-Proxy\watchdog.log'
function Log($m) { Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) }
$ok = $false
try {
  $out = & curl.exe -s -o NUL -m 12 --socks5-hostname 127.0.0.1:1080 https://web.telegram.org/ 2>&1
  $ok = ($LASTEXITCODE -eq 0)
} catch { $ok = $false }
if (-not $ok) {
  Log 'CHECK_FAIL - restarting tunnel task'
  try {
    Stop-ScheduledTask -TaskName 'BT-Proxy Telegram Tunnel' -ErrorAction SilentlyContinue
    Get-Process plink -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Start-ScheduledTask -TaskName 'BT-Proxy Telegram Tunnel'
    Start-Sleep -Seconds 10
    $out2 = & curl.exe -s -o NUL -m 12 --socks5-hostname 127.0.0.1:1080 https://web.telegram.org/ 2>&1
    if ($LASTEXITCODE -eq 0) { Log 'RESTART_OK' } else { Log 'RESTART_STILL_FAIL' }
  } catch { Log ('RESTART_ERROR: ' + $_.Exception.Message) }
} else {
  Log 'CHECK_OK'
}
