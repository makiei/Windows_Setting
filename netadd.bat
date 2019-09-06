#ネットワークアダプタ自動有効化

@echo off
netsh interface ipv4 set add name="イーサネット" source=dhcp
pause
exit

