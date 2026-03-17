@echo off
REM ============================================
REM  NeRFStudio Splatfacto Training — HIGH QUALITY
REM  Seated Buddha — 1080x1920 resolution
REM ============================================

echo [1/3] Loading Visual Studio C++ environment...
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Failed to load Visual Studio environment.
    pause
    exit /b 1
)

echo [2/3] Setting CUDA 12.4 environment...
set CUDA_HOME=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4
set PATH=%CUDA_HOME%\bin;%PATH%

where cl >nul 2>&1 && echo        cl.exe: OK || (echo ERROR: cl.exe not found && pause && exit /b 1)
nvcc --version 2>nul | findstr "release" >nul 2>&1 && echo        nvcc: OK || (echo ERROR: nvcc not found && pause && exit /b 1)

echo [3/3] Activating venv and starting training...
call D:\Sansarana\.venv_nerf\Scripts\activate.bat

echo.
echo ============================================
echo  HIGH QUALITY Splatfacto Training
echo  Resolution: 1080x1920 (highest available)
echo  Iterations: 50000
echo ============================================
echo.

REM Argument order: ns-train splatfacto [trainer args] colmap [dataparser args]
REM sh-degree defaults to 3 (max) already

ns-train splatfacto --max-num-iterations 50000 --steps-per-save 5000 colmap --data D:\Sansarana\outputs\nerf_seated_complete --downscale-factor 2
pause
