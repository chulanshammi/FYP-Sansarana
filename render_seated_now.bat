@echo off
echo [1/3] Loading Visual Studio C++ environment...
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1

echo [2/3] Setting CUDA 12.4 environment...
set CUDA_HOME=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4
set PATH=%CUDA_HOME%\bin;%PATH%

echo [3/3] Activating venv...
call D:\Sansarana\.venv_nerf\Scripts\activate.bat

echo.
echo ============================================
echo  Rendering Seated Buddha 4K Camera Video
echo ============================================
echo.

ns-render camera-path --load-config outputs\unnamed\splatfacto\2026-03-07_195535\config.yml --camera-path-filename D:\Sansarana\outputs\seated_4k\camera_paths\2026-03-27-16-39-26.json --output-path renders/seated_4k/2026-03-27-16-39-26.mp4
