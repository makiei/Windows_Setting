#マシン名変更

@echo off
set /p newname=PC name :
wmic computersystem where name="%computername%" call rename name="%newname%"
