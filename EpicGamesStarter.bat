@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "APPID=33956bcb55d4452d8c47e16b94e294bd%%3A729a86a5146640a2ace9e8c595414c56%%3A963137e4c29d4c79a81323b8fab03a40"
set "GAMENAME=Among Us.exe"

set "PF=%ProgramFiles%"
set "PFx86=%ProgramFiles(x86)%"

if not exist "%GAMENAME%" (
  echo No among us exe detected in current folder, cannot continue
  pause
  exit /b 1
)

echo %CD% | find /I "%PF%\" >nul && (
    echo Your AU copy is in Program Files, this may cause issues, please move it somewhere else
    pause
    exit /b 1
)

echo %CD% | find /I "%PFx86%\" >nul && (
    echo Your AU copy is in Program Files ^(x86^), this may cause issues, please move it somewhere else
    pause
    exit /b 1
)

echo Any open Among Us windows will be closed now
taskkill /IM "%GAMENAME%" /F >nul 2>&1
timeout /t 1 /nobreak >nul

echo Starting Among Us in the epic folder to retrieve arguments
start "" "com.epicgames.launcher://apps/%APPID%?action=launch&silent=true"

set "PROC_LINE="
for /l %%N in (1,1,30) do (
  for /f "usebackq delims=" %%L in (`
  powershell -NoProfile -Command "$p = @(Get-CimInstance Win32_Process -Filter ""Name = '%GAMENAME%'"" ); foreach ($x in $p) { if ($x.CommandLine -like '*-AUTH_LOGIN*') { Write-Output (('{0}|{1}' -f $x.ProcessId, $x.CommandLine)); break } }"
  `) do set "PROC_LINE=%%L"
  
  if defined PROC_LINE goto gotproc
  echo Waiting for Epic to launch the game...
  timeout /t 1 /nobreak >nul
)

echo Could not parse the process command line.
pause
exit /b 1

:gotproc
for /f "tokens=1* delims=|" %%A in ("!PROC_LINE!") do (
  set "PID=%%A"
  set "CMDLINE=%%B"
)

if not defined PID (
  echo Could not parse the process command line.
  pause
  exit /b 1
)

echo Starting the game in this folder and closing Epic's
start "" "%GAMENAME%" !ARGS!
taskkill /F /PID !PID! >nul 2>&1

echo done
pause
exit /b 0
