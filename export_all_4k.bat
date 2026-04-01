@echo off
REM ============================================
REM  Export All-Statues Splatfacto Model to .ply
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
echo  Exporting All-Statues Combined SPLAT
echo  Output: D:\Sansarana\exports\all_4k\splat.ply
echo ============================================
echo.

if not exist D:\Sansarana\exports\all_4k mkdir D:\Sansarana\exports\all_4k
ns-export gaussian-splat --load-config outputs\unnamed\splatfacto\2026-03-27_173343\config.yml --output-dir exports\all_4k
