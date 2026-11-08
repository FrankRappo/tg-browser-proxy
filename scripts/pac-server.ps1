$ErrorActionPreference = 'Continue'
# BT-Proxy: локальный HTTP-сервер PAC-файла (127.0.0.1:8081 -> C:\BT-Proxy\proxy.pac)
# Яндекс/Chrome флагом --proxy-pac-url=http://127.0.0.1:8081/proxy.pac
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://127.0.0.1:8081/')
try { $listener.Start() } catch { Write-Output ("START_FAIL: " + $_.Exception.Message); exit 1 }
Write-Output "PAC_SERVER_LISTENING_127.0.0.1:8081"
while ($listener.IsListening) {
  try {
    $ctx = $listener.GetContext()
    $pac = [IO.File]::ReadAllBytes('C:\BT-Proxy\proxy.pac')
    $ctx.Response.ContentType = 'application/x-ns-proxy-autoconfig'
    $ctx.Response.ContentLength64 = $pac.Length
    $ctx.Response.OutputStream.Write($pac, 0, $pac.Length)
    $ctx.Response.Close()
  } catch { Start-Sleep -Milliseconds 200 }
}
