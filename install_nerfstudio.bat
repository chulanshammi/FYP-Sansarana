@echo off
echo Setting up Visual Studio Environment...
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
cd /d d:\Sansarana
set "PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8\bin;%PATH%"
set "CUDA_HOME=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8"

echo Upgrading pip and installing ninja...
.venv_nerf\Scripts\python -m pip install --upgrade pip setuptools ninja

echo Installing tiny-cuda-nn (This make take 5-15 minutes to compile C++ Extensions. Please be patient) ...
.venv_nerf\Scripts\pip install ninja git+https://github.com/NVlabs/tiny-cuda-nn/#subdirectory=bindings/torch

echo Installing nerfstudio...
.venv_nerf\Scripts\pip install nerfstudio

echo Done installing Nerfstudio!
