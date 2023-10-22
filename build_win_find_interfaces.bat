@echo off
cd /d "%~dp0"
mkdir release\tools
del /Q release\tools\*
setlocal
call build_env_x86.bat
cl generate_interfaces_file.cpp /EHsc /MP12 /Ox /link /debug:none /OUT:release\tools\generate_interfaces_file.exe
endlocal
del /Q /S release\tools\*.lib
del /Q /S release\tools\*.exp
copy Readme_generate_interfaces.txt release\tools\Readme_generate_interfaces.txt
