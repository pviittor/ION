@echo off
rem Vanna API (Flask) em http://localhost:5000, usando o backend local
cd /d "%~dp0tfc-paulo-vitor-diamantino-leao-main\Vanna API"
set NODE_BACKEND_URL=http://localhost:3000
set PYTHONUTF8=1
".venv\Scripts\python.exe" app.py
