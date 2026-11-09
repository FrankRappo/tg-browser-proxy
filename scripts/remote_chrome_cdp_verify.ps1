$ErrorActionPreference = 'Continue'

function Line($name, $value) {
  if ($value -is [bool]) { $value = $(if ($value) { 'true' } else { 'false' }) }
  Write-Output ($name + '=' + $value)
}

$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$policy = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Google\Chrome' -ErrorAction SilentlyContinue
Line 'chromeExe' (Test-Path -LiteralPath $chrome)
Line 'chromeVersion' ((& $chrome --version 2>&1 | Out-String).Trim())
Line 'chromeProxyMode' $policy.ProxyMode
Line 'chromeProxyPacUrl' $policy.ProxyPacUrl

$port = 9223
$base = 'http://127.0.0.1:' + $port
$work = 'C:\BT-Proxy\chrome_cdp_verify'
Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $work | Out-Null
$profile = Join-Path $work 'profile'
$argsText = @(
  '--headless'
  '--disable-gpu'
  '--no-first-run'
  '--no-default-browser-check'
  ('--user-data-dir="' + $profile + '"')
  ('--remote-debugging-port=' + $port)
  '--remote-allow-origins=*'
  '--proxy-pac-url=http://127.0.0.1:8081/proxy.pac'
  'about:blank'
) -join ' '

$proc = Start-Process -FilePath $chrome -ArgumentList $argsText -PassThru
$version = $null
for ($i = 0; $i -lt 30 -and $null -eq $version; $i++) {
  Start-Sleep -Milliseconds 500
  try {
    $version = Invoke-RestMethod -Uri ($base + '/json/version') -TimeoutSec 2
  } catch {}
}

Line 'cdpProcessAlive' (-not $proc.HasExited)
Line 'cdpVersionEndpoint' ($null -ne $version)
if ($null -ne $version) {
  Line 'cdpBrowser' $version.Browser
  Line 'cdpProtocolVersion' $version.ProtocolVersion

  $target = $null
  try {
    $target = Invoke-RestMethod -Method Put -Uri ($base + '/json/new?https://web.telegram.org/k/') -TimeoutSec 5
  } catch {
    Line 'cdpNewError' $_.Exception.Message
  }

  Line 'cdpTargetCreated' ($null -ne $target)
  if ($null -ne $target) {
    Line 'cdpTargetId' $target.id
    $observedUrl = ''
    $observedTitle = ''
    for ($i = 0; $i -lt 20; $i++) {
      Start-Sleep -Milliseconds 500
      try {
        $list = Invoke-RestMethod -Uri ($base + '/json/list') -TimeoutSec 2
        $current = $list | Where-Object { $_.id -eq $target.id } | Select-Object -First 1
        if ($null -ne $current) {
          $observedUrl = [string]$current.url
          $observedTitle = [string]$current.title
          if ($observedTitle -match 'Telegram' -or $observedUrl -match 'telegram') { break }
        }
      } catch {}
    }
    Line 'cdpTargetUrl' $observedUrl
    Line 'cdpTargetTitle' $observedTitle
    Line 'cdpTelegramObserved' (($observedUrl -match 'telegram') -or ($observedTitle -match 'Telegram'))
    try { Invoke-RestMethod -Method Put -Uri ($base + '/json/close/' + $target.id) -TimeoutSec 3 | Out-Null } catch {}
  }
}

try { taskkill /PID $proc.Id /T /F 2>&1 | Out-Null } catch {}
