$ErrorActionPreference = 'Continue'
function Line($name, $value) {
  if ($value -is [bool]) { $value = $(if ($value) { 'true' } else { 'false' }) }
  Write-Output ($name + '=' + $value)
}
Line 'computer' $env:COMPUTERNAME
Line 'user' $env:USERNAME
Line 'tempPasswordRemoved' (-not (Test-Path -LiteralPath 'C:\BT-Proxy\.btproxy_password.tmp'))
Line 'tasks' ((Get-ScheduledTask -TaskName 'BT-Proxy*' -ErrorAction SilentlyContinue | ForEach-Object { $_.TaskName + ':' + $_.State }) -join ';')
Line 'ports' ((Get-NetTCPConnection -LocalPort 8081,1080 -ErrorAction SilentlyContinue | ForEach-Object { [string]$_.LocalPort + ':' + $_.State }) -join ';')
Line 'processes' ((Get-Process browser,plink -ErrorAction SilentlyContinue | ForEach-Object { $_.Name + ':' + $_.Id }) -join ';')

$chromePolicy = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Google\Chrome' -ErrorAction SilentlyContinue
Line 'chromeProxyMode' $chromePolicy.ProxyMode
Line 'chromeProxyPacUrl' $chromePolicy.ProxyPacUrl

try {
  $pac = Invoke-WebRequest -UseBasicParsing -TimeoutSec 8 'http://127.0.0.1:8081/proxy.pac'
  $pacText = if ($pac.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($pac.Content) } else { [string]$pac.Content }
  Line 'pacHttp' $pac.StatusCode
  Line 'pacHasTelegramRule' ([bool]($pacText -match 'telegram\.org'))
  Line 'pacHasSocksRule' ([bool]($pacText -match 'SOCKS5 127\.0\.0\.1:1080'))
  Line 'pacHasDirectFallback' ([bool]($pacText -match 'DIRECT'))
} catch {
  Line 'pacHttp' ('ERROR:' + $_.Exception.Message)
}

& curl.exe -sS -o NUL -m 15 --socks5-hostname 127.0.0.1:1080 https://web.telegram.org/k/
Line 'socksTelegramExit' $LASTEXITCODE

foreach ($target in @('C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Telegram.lnk','C:\Users\Public\Desktop\Telegram.lnk')) {
  if (Test-Path -LiteralPath $target) {
    $ws = New-Object -ComObject WScript.Shell
    $s = $ws.CreateShortcut($target)
    Line ('shortcut:' + $target) ('target=' + $s.TargetPath + ';args=' + $s.Arguments)
  } else {
    Line ('shortcut:' + $target) 'MISSING'
  }
}
