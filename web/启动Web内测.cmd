@echo off
setlocal
rem ASCII content: works from paths containing Chinese characters.
set "PYTHON="
set "PY_ARGS="
for /f "delims=" %%V in ('python -c "import pathlib,http.server,zlib,webbrowser; assert hasattr(pathlib.Path,'is_relative_to'); print('BEATCARD_PYTHON_OK')" 2^>nul') do if "%%V"=="BEATCARD_PYTHON_OK" set "PYTHON=python"
if defined PYTHON goto :run
for /f "delims=" %%V in ('py -3 -c "import pathlib,http.server,zlib,webbrowser; assert hasattr(pathlib.Path,'is_relative_to'); print('BEATCARD_PYTHON_OK')" 2^>nul') do if "%%V"=="BEATCARD_PYTHON_OK" set "PYTHON=py"
if defined PYTHON set "PY_ARGS=-3"
if defined PYTHON goto :run
set "FALLBACK=C:\Users\Administrator\.codex\skills\sprite-gen\.venv\Scripts\python.exe"
if not exist "%FALLBACK%" goto :missing
for /f "delims=" %%V in ('%FALLBACK% -c "import pathlib,http.server,zlib,webbrowser; assert hasattr(pathlib.Path,'is_relative_to'); print('BEATCARD_PYTHON_OK')" 2^>nul') do if "%%V"=="BEATCARD_PYTHON_OK" set "PYTHON=%FALLBACK%"
if not defined PYTHON goto :missing
:run
"%PYTHON%" %PY_ARGS% "%~dp0serve.py" --directory "%~dp0." --port 18765 --open
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" pause
exit /b %RESULT%
:missing
echo Python 3.9 or later was not found. Install Python, then run this file again.
echo This launcher runs locally and does not require Godot.
pause
exit /b 1
