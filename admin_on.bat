#ローカル管理者アカウントを有効にする


@echo off
net user administrator /active:yes
wmic useraccount where Name="administrator" set PasswordExpires=False
net localgroup "administrators" administrator /add
pause
exit

