@echo off
echo ========================================
echo Building Audio Manager executable...
echo ========================================
echo.

cd src

REM Check if virtual environment exists
if not exist .venv (
    echo Creating virtual environment...
    uv venv
    if %ERRORLEVEL% NEQ 0 (
        echo Failed to create virtual environment!
        cd ..
        pause
        exit /b 1
    )
    echo Virtual environment created.
    echo.
)

REM Check if dependencies are installed
if not exist .venv\Scripts\pyinstaller.exe (
    echo Installing dependencies...
    uv pip install -r requirements.txt
    if %ERRORLEVEL% NEQ 0 (
        echo Failed to install dependencies!
        cd ..
        pause
        exit /b 1
    )
    echo Dependencies installed.
    echo.
)

REM Build the executable
echo Building executable with PyInstaller...
.venv\Scripts\pyinstaller ^
    --onefile ^
    --name h2a_audio_manager ^
    --distpath dist ^
    --specpath build ^
    --clean ^
    manager.py

if %ERRORLEVEL% NEQ 0 (
    echo Build failed!
    cd ..
    pause
    exit /b 1
)

REM Copy to parent directory for easy access
if exist dist\h2a_audio_manager.exe (
    echo.
    echo Build successful!
    echo Copying executable to parent directory...
    copy /Y dist\h2a_audio_manager.exe ..\h2a_audio_manager.exe >nul
    echo.
    echo ========================================
    echo Build complete!
    echo Executable: h2a_audio_manager.exe
    echo ========================================
) else (
    echo Build failed - executable not found!
    cd ..
    pause
    exit /b 1
)

cd ..
pause
