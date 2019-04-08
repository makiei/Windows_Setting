#ネットワークインターフェースにDNSサフィックスを追加


@echo off
reg add "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\Tcpip\Parameters" /v "SearchList" /t REG_SZ /d ".local,.co.jp" /f
pause
exit
