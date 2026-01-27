
@echo off
:: Windows Update Repair (safe reset of components)
:: Run as Administrator

echo Stopping services…
net stop wuauserv
net stop cryptSvc
net stop bits
net stop msiserver

echo Renaming SoftwareDistribution and Catroot2…
ren %systemroot%\SoftwareDistribution SoftwareDistribution.old
ren %systemroot%\System32\catroot2 catroot2.old

echo Resetting BITS and Windows Update…
Del "%ALLUSERSPROFILE%\Application Data\Microsoft\Network\Downloader\qmgr*.dat" >nul 2>&1
sc.exe sdset bits D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWRPWPLORC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)
sc.exe sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWRPWPLORC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)

echo Registering DLLs…
for %%i in (
    atl.dll urlmon.dll mshtml.dll shdocvw.dll browseui.dll jscript.dll vbscript.dll scrrun.dll msxml.dll msxml3.dll msxml6.dll
    actxprxy.dll softpub.dll wintrust.dll dssenh.dll rsaenh.dll gpkcsp.dll sccbase.dll slbcsp.dll cryptdlg.dll oleaut32.dll ole32.dll
    shell32.dll initpki.dll wuapi.dll wuaueng.dll wuaueng1.dll wucltui.dll wups.dll wups2.dll wuweb.dll qmgr.dll qmgrprxy.dll
    wucltux.dll muweb.dll wuwebv.dll
) do regsvr32 /s %%i

echo Resetting Winsock…
netsh winsock reset
netsh winhttp reset proxy

echo Starting services…
net start msiserver
net start bits
net start cryptSvc
net start wuauserv

echo Done. Reboot recommended.
pause
