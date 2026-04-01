@echo off
REM ============================================
REM  View Standing Buddha Gaussian Splat in Nerfstudio
REM ============================================

echo [1/3] Loading Visual Studio C++ environment...
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1

echo [2/3] Setting CUDA 12.4 environment...
set CUDA_HOME=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4
set PATH=%CUDA_HOME%\bin;%PATH%

echo [3/3] Activating venv and opening viewer...
call D:\Sansarana\.venv_nerf\Scripts\activate.bat

echo.
echo ============================================
echo  Opening Standing Buddha Splat in Viewer
echo  Use the viewer to create a camera path
echo  Then use render_standing_splat.bat to render
echo ============================================
echo.

ns-viewer --load-config D:\Sansarana\outputs\unnamed\splatfacto\2026-03-20_132014\config.yml
pause
