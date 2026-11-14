@echo off
setlocal
set "GODOT_GAME=D:\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_GAME%" (
  echo Godot executable not found: %GODOT_GAME%
  pause
  exit /b 1
)
pushd "%~dp0"
start "" "%GODOT_GAME%" --path .
popd
endlocal
