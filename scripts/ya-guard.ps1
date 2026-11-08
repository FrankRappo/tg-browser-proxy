$ErrorActionPreference = 'Continue'
# BT-Proxy Yandex Guard: правит prefs дефолтного профиля Яндекса ТОЛЬКО пока браузер закрыт.
# Яндекс при чистом выходе перезаписывает Preferences из памяти и затирает чужие ключи,
# поэтому guard работает циклически и восстанавливает настройки к каждому запуску.
$log = 'C:\BT-Proxy\ya-guard.log'
function Log($m) { Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) }
if (Get-Process browser -ErrorAction SilentlyContinue) { exit 0 }
$ud = 'C:\Users\User\AppData\Local\Yandex\YandexBrowser\User Data'
$prefs = Join-Path $ud 'Default\Preferences'
if (-not (Test-Path $prefs)) { Log 'NO_PREFS_FILE'; exit 1 }
try {
  $j = Get-Content $prefs -Raw -Encoding UTF8 | ConvertFrom-Json
  $changed = $false
  $proxyObj = [PSCustomObject]@{ mode = 'pac_script'; pac_url = 'file:///C:/BT-Proxy/proxy.pac' }
  if ($j.PSObject.Properties['proxy']) {
    if ($j.proxy.mode -ne 'pac_script' -or $j.proxy.pac_url -ne 'file:///C:/BT-Proxy/proxy.pac') { $j.proxy = $proxyObj; $changed = $true }
  } else { $j | Add-Member -MemberType NoteProperty -Name proxy -Value $proxyObj; $changed = $true }
  if (-not $j.PSObject.Properties['session']) { $j | Add-Member -MemberType NoteProperty -Name session -Value ([PSCustomObject]@{}); $changed = $true }
  if ($j.session.restore_on_startup -ne 4) {
    if ($j.session.PSObject.Properties['restore_on_startup']) { $j.session.restore_on_startup = 4 } else { $j.session | Add-Member -MemberType NoteProperty -Name restore_on_startup -Value 4 }
    $changed = $true
  }
  $urls = @('https://web.telegram.org/k/')
  if (-not $j.session.PSObject.Properties['startup_urls'] -or ($j.session.startup_urls -join ';') -ne ($urls -join ';')) {
    if ($j.session.PSObject.Properties['startup_urls']) { $j.session.startup_urls = $urls } else { $j.session | Add-Member -MemberType NoteProperty -Name startup_urls -Value $urls }
    $changed = $true
  }
  if ($j.PSObject.Properties['profile']) {
    if ($j.profile.PSObject.Properties['exit_type'] -and $j.profile.exit_type -ne 'Normal') { $j.profile.exit_type = 'Normal'; $changed = $true }
    if ($j.profile.PSObject.Properties['exited_cleanly'] -and -not $j.profile.exited_cleanly) { $j.profile.exited_cleanly = $true; $changed = $true }
  }
  if ($changed) {
    $j | ConvertTo-Json -Depth 100 | Set-Content $prefs -Encoding UTF8
    Log 'PREFS_FIXED'
  }
  $sessFiles = @('Default\Current Session','Default\Current Tabs','Default\Last Session','Default\Last Tabs')
  $removed = 0
  foreach ($f in $sessFiles) {
    $fp = Join-Path $ud $f
    if (Test-Path $fp) { Remove-Item -LiteralPath $fp -Force -ErrorAction SilentlyContinue; $removed++ }
  }
  if ($removed -gt 0) { Log ('SESSION_FILES_CLEARED: ' + $removed) }
} catch { Log ('ERROR: ' + $_.Exception.Message) }
$tunnelTask = Get-ScheduledTask -TaskName 'BT-Proxy Telegram Tunnel' -ErrorAction SilentlyContinue
if ($tunnelTask -and $tunnelTask.State -ne 'Running') { Start-ScheduledTask -TaskName 'BT-Proxy Telegram Tunnel'; Log 'TUNNEL_RESTARTED' }
