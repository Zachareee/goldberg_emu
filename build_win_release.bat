@echo off
cd /d "%~dp0"
del /Q /S release\*
rmdir /S /Q release\experimental
rmdir /S /Q release\experimental_steamclient
rmdir /S /Q release\lobby_connect
rmdir /S /Q release
mkdir release

setlocal
call build_set_protobuf_directories.bat
"%PROTOC_X86_EXE%" -I.\dll\ --cpp_out=.\dll\ .\dll\net.proto
call build_env_x86.bat
cl /LD /DEMU_RELEASE_BUILD /DNDEBUG /I%PROTOBUF_X86_DIRECTORY%\include\ dll/*.cpp dll/*.cc "%PROTOBUF_X86_LIBRARY%" Iphlpapi.lib Ws2_32.lib Shell32.lib /EHsc /MP12 /Ox /link /debug:none /OUT:release\steam_api.dll

"%PROTOC_X64_EXE%" -I.\dll\ --cpp_out=.\dll\ .\dll\net.proto
call build_env_x64.bat
cl /LD /DEMU_RELEASE_BUILD /DNDEBUG /I%PROTOBUF_X64_DIRECTORY%\include\ dll/*.cpp dll/*.cc "%PROTOBUF_X64_LIBRARY%" Iphlpapi.lib Ws2_32.lib Shell32.lib /EHsc /MP12 /Ox /link /debug:none /OUT:release\steam_api64.dll
endlocal
copy Readme_release.txt release\Readme.txt
xcopy /s files_example\* release\
echo Building release experimental
call build_win_release_experimental.bat
echo Building release experimental steamclient
call build_win_release_experimental_steamclient.bat
echo Building lobby connect
call build_win_lobby_connect.bat
echo Building find interfaces
call build_win_find_interfaces.bat
