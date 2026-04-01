@echo off
REM ============================================
REM  NeRFStudio Splatfacto Training — ULTRA QUALITY
REM  Standing Buddha — 4K Dataset
REM ============================================

echo [1/3] Loading Visual Studio C++ environment...
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1

echo [2/3] Setting CUDA 12.4 environment...
set CUDA_HOME=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4
set PATH=%CUDA_HOME%\bin;%PATH%

echo [3/3] Activating venv and starting training...
call D:\Sansarana\.venv_nerf\Scripts\activate.bat

echo.
echo ============================================
echo  ULTRA QUALITY Splatfacto Training (4K source)
echo  Standing Statue
echo  Resolution: 1920x1080 (downscale 2 from 4K)
echo  Iterations: 60000 
echo ============================================
echo.

REM Original images are 3840x2160.
REM Downscale factor 2 means training runs at 1920x1080 (perfect for 12GB VRAM).
REM 60k iterations for max refinement.

ns-train splatfacto --max-num-iterations 60000 --steps-per-save 5000 colmap --data D:\Sansarana\outputs\standing_4k --downscale-factor 2
pause
