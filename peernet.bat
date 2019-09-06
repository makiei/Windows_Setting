#PNRPsvc ファイル無効化

@echo off
sc.exe config "PNRPsvc" start= disabled
sc.exe config "p2psvc" start= disabled
sc.exe config "p2pimsvc" start= disabled
pause
exit
