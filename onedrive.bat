#onedrive無効化

@echo off
 
rem # Kill OneDrive task.
taskkill /f /im OneDrive.exe
 
rem # Disable OneDrive.
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v "DisableFileSyncNGSC" /t REG_DWORD /d "1" /f
 
rem # Remove OneDrive shortcut from explorer sidebar.
reg add "HKEY_CLASSES_ROOT\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d "0" /f
 
rem # Delete OneDrive application.
%SystemRoot%\SysWOW64\OneDriveSetup.exe /uninstall
 
pause
 
exit
