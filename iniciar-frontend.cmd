@echo off
rem App Flutter no navegador em http://localhost:8080
rem Uso: iniciar-frontend.cmd [chrome|edge|web-server]   (padrao: chrome)
cd /d "%~dp0tfc-paulo-vitor-diamantino-leao-main\frontend"
set DEVICE=%1
if "%DEVICE%"=="" set DEVICE=chrome
call flutter run -d %DEVICE% --web-port 8080 --dart-define=API_HOST=localhost
