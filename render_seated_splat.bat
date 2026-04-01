@echo off
REM ============================================
REM  Render Seated Buddha Camera Video
REM  Make sure you've created a camera path first
REM  using the viewer (view_seated_splat.bat)
REM ============================================

echo [1/3] Loading Visual Studio C++ environment...
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1

echo [2/3] Setting CUDA 12.4 environment...
set CUDA_HOME=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4
set PATH=%CUDA_HOME%\bin;%PATH%

echo [3/3] Activating venv...
call D:\Sansarana\.venv_nerf\Scripts\activate.bat

echo.
echo ============================================
echo  Rendering Seated Buddha Camera Video
echo  Output: renders\seated_buddha_render.mp4
echo ============================================
echo.

ns-render camera-path --load-config D:\Sansarana\outputs\unnamed\splatfacto\2026-03-07_195535\config.yml --camera-path-filename D:\Sansarana\outputs\unnamed\splatfacto\2026-03-07_195535\camera_path.json --output-path D:\Sansarana\renders\seated_buddha_render.mp4 --rendered-output-names rgb --output-format video
pause
