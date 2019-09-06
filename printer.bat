#プリンターインストール

@echo off
pushd %~dp0
cscript "C:\Windows\System32\Printing_Admin_Scripts\ja-JP\prndrvr.vbs" -a -m "プリンタ名" -v 3 -i "D:\D:\wingpluslipslxv120x6400.exe"
pause
exit
