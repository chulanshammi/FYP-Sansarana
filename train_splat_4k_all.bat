@echo off
REM ============================================
REM  NeRFStudio Splatfacto Training
REM  ALL Statues Combined — 4K Dataset
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
echo  Splatfacto Training — ALL Statues Combined
echo  Images: ~3196 (registered by COLMAP)
echo  Resolution: 960x540 (downscale 4 from 4K)
echo  Iterations: 60000
echo ============================================
echo.

REM Downscale factor 4 = 960x540 to fit 12GB VRAM with 3196 images
REM Use images_on_gpu=False to avoid OOM with large dataset
ns-train splatfacto --max-num-iterations 60000 --steps-per-save 5000 colmap --data D:\Sansarana\outputs\all_4k --downscale-factor 4
pause
