@echo off
setlocal enabledelayedexpansion

echo ========================================
echo      Kiosk Server Service Manager
echo ========================================
echo.

REM Set the executable name and service name
set EXE_NAME=store-app-windows-amd64.exe
set SERVICE_NAME=KioskServer

REM Check if executable exists
if not exist "%EXE_NAME%" (
    echo ERROR: %EXE_NAME% not found!
    echo Please ensure the executable is in the same directory.
    pause
    exit /b 1
)

REM Display menu if no arguments provided
if "%~1"=="" (
    echo Available operations:
    echo.
    echo   [1] Install and start service
    echo   [2] Uninstall service
    echo   [3] Start service
    echo   [4] Stop service
    echo   [5] Check service status
    echo   [6] Show service info
    echo.
    echo   [0] Exit
    echo.

    choice /c 1234560 /n /m "Select operation: "

    if %errorlevel% equ 1 set OPERATION=install
    if %errorlevel% equ 2 set OPERATION=uninstall
    if %errorlevel% equ 3 set OPERATION=start
    if %errorlevel% equ 4 set OPERATION=stop
    if %errorlevel% equ 5 set OPERATION=status
    if %errorlevel% equ 6 set OPERATION=info
    if %errorlevel% equ 7 (
        echo Exiting...
        exit /b 0
    )
) else (
    set OPERATION=%~1
)

REM Convert operation to lowercase and trim spaces
set OPERATION=%OPERATION: =%
for /f "usebackq delims=" %%i in (`powershell "[string]::new('!OPERATION!').ToLower()"`) do set OPERATION=%%i

echo DEBUG: Operation is "%OPERATION%"

if "%OPERATION%"=="" (
    echo ERROR: No operation specified!
    goto :end
)

echo.
echo ========================================
echo Operation: %OPERATION%
echo ========================================
echo.

goto :operation_%OPERATION% 2>nul || (
    echo ERROR: Invalid operation '%OPERATION%'
    echo.
    echo Valid operations: install, uninstall, start, stop, status, info
    goto :end
)

:operation_install
    echo Installing %SERVICE_NAME% service...
    %EXE_NAME% install

    if %errorLevel% equ 0 (
        echo Service installed successfully!
        echo.
        echo Starting service...
        %EXE_NAME% start

        if %errorLevel% equ 0 (
            echo Service started successfully!
            goto :show_success
        ) else (
            echo WARNING: Service installed but failed to start.
            echo Check Event Viewer for details.
        )
    ) else (
        echo ERROR: Failed to install service!
    )
    goto :end

:operation_uninstall
    echo Checking if service is running...
    sc query "%SERVICE_NAME%" | findstr /i "RUNNING" >nul
    if !errorlevel! equ 0 (
        echo Service is running, stopping it first...
        call :stop_service
        timeout /t 3 /nobreak >nul
    )

    echo Uninstalling %SERVICE_NAME% service...
    %EXE_NAME% uninstall

    if %errorLevel% equ 0 (
        echo Service uninstalled successfully!
    ) else (
        echo ERROR: Failed to uninstall service!
        echo Try: sc delete "%SERVICE_NAME%"
    )
    goto :end

:operation_start
    echo Checking service status...
    sc query "%SERVICE_NAME%" | findstr /i "RUNNING" >nul
    if !errorlevel! equ 0 (
        echo Service is already running!
    ) else (
        echo Starting %SERVICE_NAME% service...
        %EXE_NAME% start

        if %errorLevel% equ 0 (
            echo Service started successfully!
        ) else (
            echo ERROR: Failed to start service!
            echo Trying alternative method...
            sc start "%SERVICE_NAME%"
        )
    )
    goto :end

:operation_stop
    call :stop_service
    goto :end

:operation_status
    echo Checking %SERVICE_NAME% service status...
    echo.
    sc query "%SERVICE_NAME%" 2>nul && (
        echo.
        echo Alternative check:
        net start | findstr /i "%SERVICE_NAME%" && (
            echo Service appears to be running (per NET command)
        ) || (
            echo Service is not running (per NET command)
        )
    ) || (
        echo Service '%SERVICE_NAME%' not found or not installed.
    )
    goto :end

:operation_info
    echo %SERVICE_NAME% Service Information:
    echo =================================
    echo.
    echo Executable: %EXE_NAME%
    echo Service Name: %SERVICE_NAME%
    echo Current Directory: %CD%
    echo.
    echo Available commands:
    echo   - Install:   %EXE_NAME% install
    echo   - Uninstall: %EXE_NAME% uninstall
    echo   - Start:     %EXE_NAME% start   OR   sc start "%SERVICE_NAME%"
    echo   - Stop:      %EXE_NAME% stop    OR   sc stop "%SERVICE_NAME%"
    echo   - Status:    sc query "%SERVICE_NAME%"
    echo.
    echo Batch file usage:
    echo   %~nx0 [install^|uninstall^|start^|stop^|status^|info]
    echo.
    echo Example: %~nx0 stop
    goto :end
:stop_service
    echo Checking if service exists...
    sc query "%SERVICE_NAME%" >nul 2>&1
    if !errorlevel! neq 0 (
        echo Service '%SERVICE_NAME%' not found!
        echo Cannot stop a service that doesn't exist.
        exit /b 1
    )

    echo Checking if service is running...
    sc query "%SERVICE_NAME%" | findstr /i "RUNNING" >nul
    if !errorlevel! neq 0 (
        echo Service is not running or is stopped.
        exit /b 0
    )

    echo Stopping %SERVICE_NAME% service...
    echo Method 1: Using "%EXE_NAME%" stop
    "%EXE_NAME%" stop

    if !errorlevel! equ 0 (
        echo Service stopped successfully via %EXE_NAME%!
    ) else (
        echo Method 1 failed, trying Method 2: SC command...
        sc stop "%SERVICE_NAME%"

        if !errorlevel! equ 0 (
            echo Service stopped successfully via SC!
        ) else (
            echo Method 2 failed, trying Method 3: NET command...
            net stop "%SERVICE_NAME%"

            if !errorlevel! equ 0 (
                echo Service stopped successfully via NET!
            ) else (
                echo ERROR: All stop methods failed!
                echo.
                echo Troubleshooting steps:
                echo 1. Check if service exists: sc query "%SERVICE_NAME%"
                echo 2. Try manually: sc stop "%SERVICE_NAME%"
                echo 3. Try manually: net stop "%SERVICE_NAME%"
                echo 4. Force stop (if stuck): taskkill /F /IM "%EXE_NAME%"
            )
        )
    )

    REM Verify service stopped
    timeout /t 2 /nobreak >nul
    sc query "%SERVICE_NAME%" | findstr /i "STOPPED" >nul
    if !errorlevel! equ 0 (
        echo Verification: Service is confirmed STOPPED.
    )
    exit /b 0


:show_success
    echo.
    echo ========================================
    echo SUCCESS! %SERVICE_NAME% is now running.
    echo ========================================
    echo.
    echo The service will start automatically on Windows boot.
    echo.

:end
if "%~1"=="" (
    echo.
    echo Press any key to exit...
    pause >nul
)
