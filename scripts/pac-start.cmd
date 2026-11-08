@echo off
rem BT-Proxy: обёртка PAC-сервера с циклом рестарта
:LOOP
powershell -NoProfile -ExecutionPolicy Bypass -File C:\BT-Proxy\pac-server.ps1 >> C:\BT-Proxy\pac-server.log 2>&1
echo [%date% %time%] pac server exited, retry in 5 sec >> C:\BT-Proxy\pac-server.log
timeout /t 5 /nobreak >nul
goto LOOP
