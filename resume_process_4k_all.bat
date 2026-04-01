@echo off
REM ============================================
REM  Run COLMAP on 4K frames — All Statues
REM ============================================

echo [1/3] Loading Visual Studio C++ environment...
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1

echo [2/3] Setting CUDA 12.4 and COLMAP environment...
set CUDA_HOME=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4
set PATH=%CUDA_HOME%\bin;D:\Sansarana\colmap\COLMAP-3.9.1-windows-cuda;%PATH%

echo [3/3] Activating venv and running COLMAP...
call D:\Sansarana\.venv_nerfstudio\Scripts\activate.bat

echo.
echo ============================================
echo  Processing All Statues 4K frames
echo  Running COLMAP (this may take a while)
echo ============================================
echo.

ns-process-data images --data D:\Sansarana\outputs\all_4k\images --output-dir D:\Sansarana\outputs\all_4k --matching-method vocab_tree --skip-image-processing
pause
