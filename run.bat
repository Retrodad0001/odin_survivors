echo off

cls
odin version

set OUT_DIR=build\debug\win64

echo Delete all previous compiled shader files
del /q "shader.frag"
del /q "shader.vert"
echo.

echo compile shaders
REM Make sure you have glslc installed and in your PATH (install the Vulkan SDK first)
glslc shader.glsl.frag -o shader.frag
IF %ERRORLEVEL% NEQ 0 exit /b 1
glslc shader.glsl.vert -o shader.vert
IF %ERRORLEVEL% NEQ 0 exit /b 1

echo run test
odin test survivors

echo create debug build directory
if exist %OUT_DIR% rmdir /s /q %OUT_DIR%
mkdir %OUT_DIR%
IF %ERRORLEVEL% NEQ 0 exit /b 1

echo create debug build
odin build survivors -out:%OUT_DIR%\survivors_debug.exe -strict-style -vet -debug
IF %ERRORLEVEL% NEQ 0 exit /b 1

xcopy /y /e /i assets %OUT_DIR%\assets > nul
IF %ERRORLEVEL% NEQ 0 exit /b 1

echo Debug build created in %OUT_DIR%

echo Copy SDL3 DLLs to output directory
xcopy /y D:\DevTools\Odin\vendor\sdl3\sdl3.dll %OUT_DIR% > nul
IF %ERRORLEVEL% NEQ 0 exit /b 1
xcopy /y D:\DevTools\Odin\vendor\sdl3\ttf\sdl3_ttf.dll %OUT_DIR% > nul
IF %ERRORLEVEL% NEQ 0 exit /b 1
xcopy /y D:\DevTools\Odin\vendor\sdl3\image\sdl3_image.dll %OUT_DIR% > nul
IF %ERRORLEVEL% NEQ 0 exit /b 1

%OUT_DIR%\survivors_debug.exe
echo.