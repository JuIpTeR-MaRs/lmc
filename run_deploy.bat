@echo off
title Voting Contract Deployer

echo ==================================================
echo         Voting DApp Deployment Helper
echo ==================================================
echo.
echo Please select the target deployment network:
echo [1] Auto-Start Node and Deploy to Localhost (Recommended)
echo [2] Deploy to Localhost Network (If you already started 'npx hardhat node')
echo [3] Deploy to Sepolia Testnet
echo [4] Deploy to Ephemeral Memory Network (For compile and deploy test only)
echo [5] Exit
echo.
set /p choice="Enter your choice (1-5): "

if "%choice%"=="1" goto AUTO_LOCAL
if "%choice%"=="2" goto LOCAL
if "%choice%"=="3" goto SEPOLIA
if "%choice%"=="4" goto MEMORY
if "%choice%"=="5" goto EXIT
goto INVALID

:AUTO_LOCAL
echo.
echo [Starting Hardhat local node in a new window...]
start npx.cmd hardhat node
echo Waiting 5 seconds for node to initialize...
ping 127.0.0.1 -n 6 > nul
echo.
echo [Deploying to Localhost Network...]
call npx.cmd hardhat run scripts/deploy.js --network localhost
goto END

:LOCAL
echo.
echo [Deploying to Localhost Network...]
call npx.cmd hardhat run scripts/deploy.js --network localhost
goto END

:SEPOLIA
echo.
echo [Deploying to Sepolia Testnet...]
call npx.cmd hardhat run scripts/deploy.js --network sepolia
goto END

:MEMORY
echo.
echo [Deploying to Ephemeral Memory Network...]
call npx.cmd hardhat run scripts/deploy.js
goto END

:INVALID
echo Invalid choice. Please run the script again.
pause
goto EXIT

:END
echo.
echo Deployment script execution finished.
pause

:EXIT
