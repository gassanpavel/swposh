@echo off
cls
CD %~dp0
net session >nul 2>&1
if %errorLevel% == 0 (
	powershell -Command "& Unblock-File .\storagetest.ps1"
	Powershell.exe -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File ".\storagetest.ps1"
    ) else (
        echo Failure: Current permissions are not sufficient. 
	echo Please, start again with administrative privileges.
	pause > nul
    )

