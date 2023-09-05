@ECHO OFF
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "& """%~dp0build-runtime.ps1""" %*"
EXIT /B %ERRORLEVEL%
