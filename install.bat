cd "C:\Program Files\Printerceptor"
regedit.exe /S RemoteSigned.reg
regedit.exe /S DefaultKeys.reg
xcopy "C:\Program Files\Printerceptor\printerceptor.lnk" %userprofile%\desktop /y
xcopy /e /i "PSTerminalServices" "C:\Windows\system32\WindowsPowerShell\v1.0\Modules/PSTerminalServices" /y
schtasks /delete /tn "Printerceptor" /f
schtasks /create  /tn "Printerceptor" /XML ./tasks/printerceptor.xml
schtasks /create  /tn "Printerceptor - isolate" /XML "./tasks/Printerceptor - Isolate.xml"
mkdir "C:\programdata\microsoft\Windows\Start Menu\Programs\Printerceptor" /y
xcopy "C:\Program Files\Printerceptor\printerceptor.lnk" "C:\programdata\microsoft\Windows\Start Menu\Programs\Printerceptor" /y

cscript MessageBox.vbs "Printerceptor UI will now open. It may take a few seconds to load..."