@echo off
cd /d "%~dp0"
mkdir release\experimental
del /Q release\experimental\*
setlocal
call build_set_protobuf_directories.bat
mkdir deps
"%PROTOC_X86_EXE%" -I.\dll\ --cpp_out=.\dll\ .\dll\net.proto
call build_env_x86.bat
cl /LD /DEMU_RELEASE_BUILD /DEMU_EXPERIMENTAL_BUILD /DCONTROLLER_SUPPORT /DEMU_OVERLAY /DNDEBUG /IImGui /I%PROTOBUF_X86_DIRECTORY%\include\ /Ioverlay_experimental /Fodeps/ dll/*.cpp dll/*.cc detours/*.cpp controller/gamepad.c ImGui/*.cpp ImGui/backends/imgui_impl_dx*.cpp ImGui/backends/imgui_impl_win32.cpp ImGui/backends/imgui_impl_vulkan.cpp ImGui/backends/imgui_impl_opengl3.cpp ImGui/backends/imgui_win_shader_blobs.cpp overlay_experimental/*.cpp overlay_experimental/windows/*.cpp overlay_experimental/System/*.cpp "%PROTOBUF_X86_LIBRARY%" opengl32.lib Iphlpapi.lib Ws2_32.lib Shell32.lib Winmm.lib /EHsc /MP12 /Ox /link /debug:none /OUT:release\experimental\steam_api.dll
cl /LD /DEMU_RELEASE_BUILD /DEMU_EXPERIMENTAL_BUILD /DNDEBUG steamclient.cpp /EHsc /MP4 /Ox /link /OUT:release\experimental\steamclient.dll
rmdir /S /Q deps

mkdir deps
"%PROTOC_X64_EXE%" -I.\dll\ --cpp_out=.\dll\ .\dll\net.proto
call build_env_x64.bat
cl /LD /DEMU_RELEASE_BUILD /DEMU_EXPERIMENTAL_BUILD /DCONTROLLER_SUPPORT /DEMU_OVERLAY /DNDEBUG /IImGui /I%PROTOBUF_X64_DIRECTORY%\include\ /Ioverlay_experimental /Fodeps/ dll/*.cpp dll/*.cc detours/*.cpp controller/gamepad.c ImGui/*.cpp ImGui/backends/imgui_impl_dx*.cpp ImGui/backends/imgui_impl_win32.cpp ImGui/backends/imgui_impl_vulkan.cpp ImGui/backends/imgui_impl_opengl3.cpp ImGui/backends/imgui_win_shader_blobs.cpp overlay_experimental/*.cpp overlay_experimental/windows/*.cpp overlay_experimental/System/*.cpp "%PROTOBUF_X64_LIBRARY%" opengl32.lib Iphlpapi.lib Ws2_32.lib Shell32.lib Winmm.lib /EHsc /MP12 /Ox /link /debug:none /OUT:release\experimental\steam_api64.dll
cl /LD /DEMU_RELEASE_BUILD /DEMU_EXPERIMENTAL_BUILD /DNDEBUG steamclient.cpp /EHsc /MP4 /Ox /link /OUT:release\experimental\steamclient64.dll
endlocal
rmdir /S /Q deps
copy Readme_experimental.txt release\experimental\Readme.txt
