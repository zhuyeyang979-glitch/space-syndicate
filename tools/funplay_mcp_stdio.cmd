@echo off
setlocal
set "ROOT=%~dp0.."
set "LOCAL_ROOT=%ROOT%\.codex-godot"

if not exist "%LOCAL_ROOT%\endpoint.txt" (
  >&2 echo Launch the role-local Godot editor before starting the MCP bridge.
  exit /b 2
)
if not exist "%LOCAL_ROOT%\auth.token" (
  >&2 echo Missing role-local Funplay MCP token.
  exit /b 2
)

set /p FUNPLAY_GODOT_MCP_URL=<"%LOCAL_ROOT%\endpoint.txt"
set /p FUNPLAY_GODOT_MCP_TOKEN=<"%LOCAL_ROOT%\auth.token"

set "BUNDLED_ROOT=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies"
set "PATH=%BUNDLED_ROOT%\node\bin;%PATH%"
set "PNPM=%BUNDLED_ROOT%\bin\fallback\pnpm.cmd"
if not exist "%PNPM%" set "PNPM=pnpm.cmd"

call "%PNPM%" --silent dlx funplay-godot-mcp@0.9.6
exit /b %ERRORLEVEL%
