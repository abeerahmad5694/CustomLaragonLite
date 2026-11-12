@echo off
setlocal EnableDelayedExpansion
title Server Debugger and Manager - Live Diagnostics

cls
echo ======================================================================
echo                 SERVER MANAGER - DEBUG ^& DIAGNOSTIC RUNNER              
echo ======================================================================
echo.

:: ==============================================================================
:: STEP 1: PATH RESOLUTION
:: ==============================================================================
echo [STEP 1] Detecting Installation Paths...
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
echo   Current Script Folder : %SCRIPT_DIR%

set "SERVER_ROOT="
set "APP_ROOT="

:: Check if script is in AppRoot with server\bin
if exist "%SCRIPT_DIR%\server\bin" (
    set "SERVER_ROOT=%SCRIPT_DIR%\server"
    set "APP_ROOT=%SCRIPT_DIR%"
    echo   [OK] Detected layout: Script in AppRoot, Server in .\server
    goto :PATHS_RESOLVED
)

:: Check if script is directly inside server\bin
if exist "%SCRIPT_DIR%\bin" (
    set "SERVER_ROOT=%SCRIPT_DIR%"
    for %%P in ("%SCRIPT_DIR%\..") do set "APP_ROOT=%%~fP"
    echo   [OK] Detected layout: Script directly inside Server directory
    goto :PATHS_RESOLVED
)

:: Check if script is in gobuild or subfolder 2 levels deep
if exist "%SCRIPT_DIR%\..\..\server\bin" (
    for %%P in ("%SCRIPT_DIR%\..\..") do set "APP_ROOT=%%~fP"
    set "SERVER_ROOT=!APP_ROOT!\server"
    echo   [OK] Detected layout: Grandparent contains \server folder
    goto :PATHS_RESOLVED
)

:: Check if script is in subfolder 1 level deep
if exist "%SCRIPT_DIR%\..\server\bin" (
    for %%P in ("%SCRIPT_DIR%\..") do set "APP_ROOT=%%~fP"
    set "SERVER_ROOT=!APP_ROOT!\server"
    echo   [OK] Detected layout: Parent contains \server folder
    goto :PATHS_RESOLVED
)

:: Fallback layout
if exist "%SCRIPT_DIR%\server" (
    set "SERVER_ROOT=%SCRIPT_DIR%\server"
    set "APP_ROOT=%SCRIPT_DIR%"
    echo   [WARN] Assuming ServerRoot is: %SCRIPT_DIR%\server
    goto :PATHS_RESOLVED
)

set "SERVER_ROOT=%SCRIPT_DIR%"
set "APP_ROOT=%SCRIPT_DIR%"
echo   [WARN] Assuming current folder is ServerRoot: %SCRIPT_DIR%

:PATHS_RESOLVED
echo   Resolved App Root     : %APP_ROOT%
echo   Resolved Server Root  : %SERVER_ROOT%

:: Setup log directory and files
set "LOGS_DIR=%SERVER_ROOT%\logs"
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%" 2>nul
set "DEBUG_LOG=%LOGS_DIR%\server-debug.log"
set "MYSQL_LOG=%LOGS_DIR%\mysql-service.log"
set "PHP_LOG=%LOGS_DIR%\php-service.log"

echo ====================================================== >> "%DEBUG_LOG%"
echo [%DATE% %TIME%] SERVER DEBUGGER STARTED >> "%DEBUG_LOG%"
echo Script Dir  : %SCRIPT_DIR% >> "%DEBUG_LOG%"
echo App Root    : %APP_ROOT% >> "%DEBUG_LOG%"
echo Server Root : %SERVER_ROOT% >> "%DEBUG_LOG%"

:: ==============================================================================
:: STEP 2: PARSE CONFIGURATION
:: ==============================================================================
echo.
echo [STEP 2] Parsing Configuration Files...
set "MYSQL_PORT=3306"
set "PHP_PORT=8010"
set "SERVER_INI="

if exist "%SERVER_ROOT%\bin\server.ini" set "SERVER_INI=%SERVER_ROOT%\bin\server.ini"
if not defined SERVER_INI if exist "%SERVER_ROOT%\server.ini" set "SERVER_INI=%SERVER_ROOT%\server.ini"
if not defined SERVER_INI if exist "%SERVER_ROOT%\usr\server.ini" set "SERVER_INI=%SERVER_ROOT%\usr\server.ini"

if defined SERVER_INI (
    echo   [FOUND] server.ini at: %SERVER_INI%
    echo [%DATE% %TIME%] Using server.ini: %SERVER_INI% >> "%DEBUG_LOG%"
    for /f "usebackq tokens=1* delims==" %%A in ("%SERVER_INI%") do (
        set "KEY=%%A"
        set "VAL=%%B"
        if defined VAL (
            if /i "!KEY!"=="mysql_port" set "MYSQL_PORT=!VAL!"
            if /i "!KEY!"=="php_port" set "PHP_PORT=!VAL!"
        )
    )
) else (
    echo   [INFO] server.ini not found. Using default ports.
)

:: Locate my.ini
set "MY_INI="
if exist "%SERVER_ROOT%\bin\mysql" (
    for /f "delims=" %%F in ('dir /b /s "%SERVER_ROOT%\bin\mysql\my.ini" 2^>nul') do (
        if exist "%%F" if not defined MY_INI set "MY_INI=%%F"
    )
)
if not defined MY_INI if exist "%SERVER_ROOT%\my.ini" set "MY_INI=%SERVER_ROOT%\my.ini"

if defined MY_INI (
    echo   [FOUND] my.ini at: %MY_INI%
    echo [%DATE% %TIME%] Found my.ini: %MY_INI% >> "%DEBUG_LOG%"
) else (
    echo   [INFO] No custom my.ini found. Using command-line defaults.
)

echo   Configured MySQL Port : %MYSQL_PORT%
echo   Configured PHP Port   : %PHP_PORT%

:: ==============================================================================
:: STEP 3: LOCATE BINARIES & COMPONENTS
:: ==============================================================================
echo.
echo [STEP 3] Locating Binaries and Components...

:: Locate mysqld.exe
set "MYSQLD_EXE="
if exist "%SERVER_ROOT%\bin\mysqld.exe" set "MYSQLD_EXE=%SERVER_ROOT%\bin\mysqld.exe"
if not defined MYSQLD_EXE if exist "%SERVER_ROOT%\bin\mysql" (
    for /f "delims=" %%F in ('dir /b /s "%SERVER_ROOT%\bin\mysql\mysqld.exe" 2^>nul') do (
        if exist "%%F" if not defined MYSQLD_EXE set "MYSQLD_EXE=%%F"
    )
)
if defined MYSQLD_EXE (
    echo   [OK] MySQL Server mysqld.exe : !MYSQLD_EXE!
    echo [%DATE% %TIME%] Found mysqld.exe: !MYSQLD_EXE! >> "%DEBUG_LOG%"
) else (
    echo   [ERROR] mysqld.exe NOT FOUND under %SERVER_ROOT%\bin
    echo [%DATE% %TIME%] ERROR: mysqld.exe NOT FOUND >> "%DEBUG_LOG%"
)

:: Locate mysql.exe client
set "MYSQL_CLIENT="
if exist "%SERVER_ROOT%\bin\mysql.exe" set "MYSQL_CLIENT=%SERVER_ROOT%\bin\mysql.exe"
if not defined MYSQL_CLIENT if exist "%SERVER_ROOT%\bin\mysql" (
    for /f "delims=" %%F in ('dir /b /s "%SERVER_ROOT%\bin\mysql\mysql.exe" 2^>nul') do (
        if exist "%%F" if not defined MYSQL_CLIENT set "MYSQL_CLIENT=%%F"
    )
)
if defined MYSQL_CLIENT (
    echo   [OK] MySQL Client mysql.exe  : !MYSQL_CLIENT!
) else (
    echo   [WARN] mysql.exe client not found
)

:: Locate php.exe
set "PHP_EXE="
if exist "%SERVER_ROOT%\bin\php.exe" set "PHP_EXE=%SERVER_ROOT%\bin\php.exe"
if not defined PHP_EXE if exist "%SERVER_ROOT%\bin\php" (
    for /f "delims=" %%F in ('dir /b /s "%SERVER_ROOT%\bin\php\php.exe" 2^>nul') do (
        if exist "%%F" if not defined PHP_EXE set "PHP_EXE=%%F"
    )
)
if defined PHP_EXE (
    echo   [OK] PHP Executable php.exe   : !PHP_EXE!
    echo [%DATE% %TIME%] Found php.exe: !PHP_EXE! >> "%DEBUG_LOG%"
) else (
    echo   [ERROR] php.exe NOT FOUND under %SERVER_ROOT%\bin
    echo [%DATE% %TIME%] ERROR: php.exe NOT FOUND >> "%DEBUG_LOG%"
)

:: Locate Adminer directory
set "ADMINER_DIR="
if exist "%SERVER_ROOT%\etc\apps\adminer" set "ADMINER_DIR=%SERVER_ROOT%\etc\apps\adminer"
if not defined ADMINER_DIR if exist "%SERVER_ROOT%\adminer" set "ADMINER_DIR=%SERVER_ROOT%\adminer"
if not defined ADMINER_DIR if exist "%SERVER_ROOT%\apps\adminer" set "ADMINER_DIR=%SERVER_ROOT%\apps\adminer"
if not defined ADMINER_DIR if exist "%SERVER_ROOT%\etc\adminer" set "ADMINER_DIR=%SERVER_ROOT%\etc\adminer"

if defined ADMINER_DIR (
    echo   [OK] Adminer Docroot          : !ADMINER_DIR!
    echo [%DATE% %TIME%] Found Adminer dir: !ADMINER_DIR! >> "%DEBUG_LOG%"
) else (
    echo   [ERROR] Adminer folder NOT FOUND under %SERVER_ROOT%
    echo [%DATE% %TIME%] ERROR: Adminer dir NOT FOUND >> "%DEBUG_LOG%"
)

:: Data Directory
set "DATA_DIR=%SERVER_ROOT%\data"
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
echo   [OK] MySQL Data Directory     : %DATA_DIR%

:: Validate requirements before starting
if not defined MYSQLD_EXE (
    echo.
    echo ======================================================================
    echo CRITICAL ERROR: mysqld.exe could not be found!
    echo Please verify that MySQL is installed inside %SERVER_ROOT%\bin\mysql\
    echo ======================================================================
    goto :HALT
)
if not defined PHP_EXE (
    echo.
    echo ======================================================================
    echo CRITICAL ERROR: php.exe could not be found!
    echo Please verify that PHP is installed inside %SERVER_ROOT%\bin\php\
    echo ======================================================================
    goto :HALT
)

:: ==============================================================================
:: STEP 4: CHECK PORT AVAILABILITY
:: ==============================================================================
echo.
echo [STEP 4] Checking Port Status...

netstat -ano | findstr /R /C:":%MYSQL_PORT% " >nul 2>&1
if %ERRORLEVEL%==0 (
    echo   [INFO] Port %MYSQL_PORT% is currently occupied.
    for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":%MYSQL_PORT% "') do (
        echo        - Occupied by PID: %%P
    )
) else (
    echo   [FREE] Port %MYSQL_PORT% is available for MySQL.
)

netstat -ano | findstr /R /C:":%PHP_PORT% " >nul 2>&1
if %ERRORLEVEL%==0 (
    echo   [INFO] Port %PHP_PORT% is currently occupied.
    for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":%PHP_PORT% "') do (
        echo        - Occupied by PID: %%P
    )
) else (
    echo   [FREE] Port %PHP_PORT% is available for Adminer.
)

:: ==============================================================================
:: STEP 5: INITIALIZE MYSQL DATA DIRECTORY IF NEEDED
:: ==============================================================================
echo.
echo [STEP 5] Checking MySQL Database Initialization...
if not exist "%DATA_DIR%\ibdata1" (
    echo   [INITIALIZING] ibdata1 not found. Initializing MySQL data directory...
    echo [%DATE% %TIME%] Initializing MySQL data dir: %DATA_DIR% >> "%DEBUG_LOG%"
    "%MYSQLD_EXE%" --initialize-insecure --datadir="%DATA_DIR%" > "%LOGS_DIR%\mysql-init.log" 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo   [FAILED] MySQL initialization failed!
        echo   Check log: %LOGS_DIR%\mysql-init.log
        type "%LOGS_DIR%\mysql-init.log"
        goto :HALT
    ) else (
        echo   [SUCCESS] MySQL data directory initialized successfully!
    )
) else (
    echo   [OK] MySQL database is already initialized.
)

:: ==============================================================================
:: STEP 6: START SERVICES
:: ==============================================================================
echo.
echo [STEP 6] Starting Background Services...

:: Build MySQL Arguments
set "MYSQL_ARGS=--datadir="%DATA_DIR%" --port=%MYSQL_PORT%"
if defined MY_INI set "MYSQL_ARGS=--defaults-file="%MY_INI%" %MYSQL_ARGS%"

echo   Starting MySQL: %MYSQLD_EXE% %MYSQL_ARGS%
echo [%DATE% %TIME%] Starting MySQL: "%MYSQLD_EXE%" %MYSQL_ARGS% >> "%DEBUG_LOG%"

start /B "" "%MYSQLD_EXE%" %MYSQL_ARGS% > "%MYSQL_LOG%" 2>&1

:: Probe MySQL port until ready
echo   Waiting for MySQL to listen on port %MYSQL_PORT%...
set "MYSQL_OK=0"
for /L %%i in (1,1,20) do (
    if !MYSQL_OK!==0 (
        powershell -NoProfile -Command "$c = New-Object Net.Sockets.TcpClient; try { $c.Connect('127.0.0.1', %MYSQL_PORT%); Write-Output 'OPEN'; $c.Close() } catch { Write-Output 'CLOSED' }" 2>nul | findstr "OPEN" >nul
        if !ERRORLEVEL!==0 (
            set "MYSQL_OK=1"
        ) else (
            <nul set /p =.
            ping -n 2 127.0.0.1 >nul
        )
    )
)
echo.

if !MYSQL_OK!==1 (
    echo   [SUCCESS] MySQL is RUNNING and accepting connections on port %MYSQL_PORT%!
    echo [%DATE% %TIME%] MySQL successfully started on port %MYSQL_PORT% >> "%DEBUG_LOG%"
) else (
    echo   [FAILED] MySQL failed to respond on port %MYSQL_PORT%!
    echo [%DATE% %TIME%] ERROR: MySQL failed to respond on port %MYSQL_PORT% >> "%DEBUG_LOG%"
    echo   ------------------------------------------------------------
    echo   Recent output from MySQL log:
    powershell -NoProfile -Command "Get-Content '%MYSQL_LOG%' -Tail 15 -ErrorAction SilentlyContinue"
    echo   ------------------------------------------------------------
)

:: Start Adminer PHP Server
echo.
echo   Starting PHP Built-in Server for Adminer on port %PHP_PORT%...
echo   Docroot: %ADMINER_DIR%
echo [%DATE% %TIME%] Starting PHP: "%PHP_EXE%" -S 127.0.0.1:%PHP_PORT% -t "%ADMINER_DIR%" >> "%DEBUG_LOG%"

start /B "" "%PHP_EXE%" -S 127.0.0.1:%PHP_PORT% -t "%ADMINER_DIR%" > "%PHP_LOG%" 2>&1

:: Probe PHP port until ready
set "PHP_OK=0"
for /L %%i in (1,1,10) do (
    if !PHP_OK!==0 (
        powershell -NoProfile -Command "$c = New-Object Net.Sockets.TcpClient; try { $c.Connect('127.0.0.1', %PHP_PORT%); Write-Output 'OPEN'; $c.Close() } catch { Write-Output 'CLOSED' }" 2>nul | findstr "OPEN" >nul
        if !ERRORLEVEL!==0 (
            set "PHP_OK=1"
        ) else (
            <nul set /p =.
            ping -n 2 127.0.0.1 >nul
        )
    )
)
echo.

if !PHP_OK!==1 (
    echo   [SUCCESS] Adminer/PHP is RUNNING and accessible at http://127.0.0.1:%PHP_PORT%!
    echo [%DATE% %TIME%] PHP successfully started on port %PHP_PORT% >> "%DEBUG_LOG%"
) else (
    echo   [FAILED] PHP failed to respond on port %PHP_PORT%!
    echo [%DATE% %TIME%] ERROR: PHP failed to respond on port %PHP_PORT% >> "%DEBUG_LOG%"
    echo   ------------------------------------------------------------
    echo   Recent output from PHP log:
    powershell -NoProfile -Command "Get-Content '%PHP_LOG%' -Tail 15 -ErrorAction SilentlyContinue"
    echo   ------------------------------------------------------------
)

:: ==============================================================================
:: STEP 7: STATUS SUMMARY
:: ==============================================================================
echo.
echo ======================================================================
echo                         STATUS SUMMARY                               
echo ======================================================================
if !MYSQL_OK!==1 (
    echo   MySQL Server    : ACTIVE - Port: %MYSQL_PORT%
) else (
    echo   MySQL Server    : FAILED - Port: %MYSQL_PORT%
)
if !PHP_OK!==1 (
    echo   Adminer UI      : ACTIVE - URL: http://127.0.0.1:%PHP_PORT%
) else (
    echo   Adminer UI      : FAILED - URL: http://127.0.0.1:%PHP_PORT%
)
echo.
echo   Log Files:
echo   - Master Debug Log  : %DEBUG_LOG%
echo   - MySQL Service Log : %MYSQL_LOG%
echo   - PHP Service Log   : %PHP_LOG%
echo ======================================================================
echo.

if !PHP_OK!==1 (
    echo Launching browser to http://127.0.0.1:%PHP_PORT%...
    start "" "http://127.0.0.1:%PHP_PORT%"
)

:: ==============================================================================
:: STEP 8: INTERACTIVE DEBUG CONSOLE LOOP
:: ==============================================================================
:MENU
echo.
echo Debug Control Actions:
echo   [1] Open Adminer in Browser
echo   [2] View Recent MySQL Log
echo   [3] View Recent PHP Log
echo   [4] View Full Master Debug Log
echo   [5] Test MySQL SQL Query via mysql.exe
echo   [6] Stop Services and Exit
echo.

choice /c 123456 /m "Select action [1-6]: "
if errorlevel 6 goto :SHUTDOWN
if errorlevel 5 goto :ACTION_SQL
if errorlevel 4 goto :ACTION_DEBUG_LOG
if errorlevel 3 goto :ACTION_PHP_LOG
if errorlevel 2 goto :ACTION_MYSQL_LOG
if errorlevel 1 goto :ACTION_BROWSER
goto :MENU

:ACTION_BROWSER
start "" "http://127.0.0.1:%PHP_PORT%"
goto :MENU

:ACTION_MYSQL_LOG
echo.
echo --- MySQL Service Log ---
powershell -NoProfile -Command "Get-Content '%MYSQL_LOG%' -Tail 30 -ErrorAction SilentlyContinue"
goto :MENU

:ACTION_PHP_LOG
echo.
echo --- PHP Service Log ---
powershell -NoProfile -Command "Get-Content '%PHP_LOG%' -Tail 30 -ErrorAction SilentlyContinue"
goto :MENU

:ACTION_DEBUG_LOG
echo.
echo --- Master Debug Log ---
powershell -NoProfile -Command "Get-Content '%DEBUG_LOG%' -Tail 30 -ErrorAction SilentlyContinue"
goto :MENU

:ACTION_SQL
echo.
if defined MYSQL_CLIENT (
    echo Testing query via mysql.exe...
    "%MYSQL_CLIENT%" -u root -P %MYSQL_PORT% -h 127.0.0.1 -e "SELECT VERSION() AS MySQL_Version, CURRENT_USER() AS User, NOW() AS Current_Time;"
) else (
    echo [WARN] mysql.exe client was not found.
)
goto :MENU

:: ==============================================================================
:: SHUTDOWN & CLEANUP
:: ==============================================================================
:SHUTDOWN
echo.
echo Stopping services...
echo [%DATE% %TIME%] Stopping services on user request >> "%DEBUG_LOG%"

taskkill /F /IM mysqld.exe >nul 2>&1
taskkill /F /IM php.exe >nul 2>&1

echo Services stopped successfully.
echo [%DATE% %TIME%] Services stopped >> "%DEBUG_LOG%"
goto :EOF

:HALT
echo.
echo Execution halted due to an error. Press any key to exit.
pause >nul
