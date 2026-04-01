@echo off
echo Loading Visual Studio C++ environment...
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1

echo Setting CUDA environment...
set CUDA_HOME=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4
set PATH=%CUDA_HOME%\bin;%PATH%

echo Activating venv...
call D:\Sansarana\.venv_nerf\Scripts\activate.bat

echo Starting evaluation pipeline...
python evaluate_metrics.py
pause
