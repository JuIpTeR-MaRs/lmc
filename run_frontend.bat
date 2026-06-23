@echo off
title Voting DApp Web Server
echo ==================================================
echo         Voting DApp Local Web Server
echo ==================================================
echo.
echo Starting local web server on port 8080...
echo.
echo Please keep this window open while testing.
echo opening http://localhost:8080 in your browser...
echo.

:: 自动打开浏览器
start http://localhost:8080

:: 使用 npx 启动 http-server，并指定监听 8080 端口
call npx -y http-server -p 8080

pause
