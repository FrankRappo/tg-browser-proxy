$ErrorActionPreference = 'Stop'
# BT-Proxy: регистрация всех задач планировщика (запуск от администратора на целевой машине)
# Предусловия: C:\BT-Proxy\ содержит plink.exe, tunnel.cmd (с паролем), proxy.pac,
#              pac-server.ps1, pac-start.cmd, watchdog.ps1, ya-guard.ps1

function New-Task($name, $exe, $arg, $limit) {
  $action = New-ScheduledTaskAction -Execute $exe -Argument $arg
  $t1 = New-ScheduledTaskTrigger -AtStartup
  $t2 = New-ScheduledTaskTrigger -AtLogOn
  $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit $limit -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
  Register-ScheduledTask -TaskName $name -Action $action -Trigger $t1,$t2 -Principal $principal -Settings $settings -Force | Out-Null
  Write-Output ("REGISTERED: " + $name)
}

# 1) Тоннель: бесконечный cmd-цикл с рестартом внутри, поэтому без внешнего лимита
New-Task 'BT-Proxy Telegram Tunnel' 'cmd.exe' '/c C:\BT-Proxy\tunnel.cmd' ([TimeSpan]::Zero)
# 2) PAC-сервер: аналог
New-Task 'BT-Proxy PAC Server' 'cmd.exe' '/c C:\BT-Proxy\pac-start.cmd' ([TimeSpan]::Zero)

# 3) Watchdog: раз в минуту
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\BT-Proxy\watchdog.ps1'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration ([TimeSpan]::FromDays(3650))
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::FromMinutes(5)) -MultipleInstances IgnoreNew -StartWhenAvailable
Register-ScheduledTask -TaskName 'BT-Proxy Tunnel Watchdog' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Output 'REGISTERED: BT-Proxy Tunnel Watchdog'

# 4) Yandex Guard: при входе + раз в минуту
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\BT-Proxy\ya-guard.ps1'
$t1 = New-ScheduledTaskTrigger -AtLogOn
$t2 = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration ([TimeSpan]::FromDays(3650))
Register-ScheduledTask -TaskName 'BT-Proxy Yandex Guard' -Action $action -Trigger $t1,$t2 -Principal $principal -Settings $settings -Force | Out-Null
Write-Output 'REGISTERED: BT-Proxy Yandex Guard'

# Старт
foreach ($n in 'BT-Proxy Telegram Tunnel','BT-Proxy PAC Server','BT-Proxy Tunnel Watchdog','BT-Proxy Yandex Guard') {
  Start-ScheduledTask -TaskName $n
}
Write-Output 'ALL_STARTED'
