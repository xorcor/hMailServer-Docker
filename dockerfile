FROM mcr.microsoft.com/windows/servercore:1803

LABEL Description="hMail-WindowsServer" Vendor="Microsoft, hMailServer" Version="1803,5.6.8,1"

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ENV SQL "hMail_121818.sql"

ENV NETFX3 "microsoft-windows-netfx3-ondemand-package.cab"

ENV MARIA_BASE_URL "https://downloads.mariadb.org/f"
ENV MARIA_VERSION "mariadb-10.3.11"

ENV HMAIL_URL "https://www.hmailserver.com/files/hMailServer-5.6.7-B2425.exe"
ENV HMAIL_INSTALLER "hMailServer-5.6.7-B2425.exe"

RUN mkdir C:\\build;
ADD build\\${SQL} /build
ADD build\\microsoft-windows-netfx3-ondemand-package.cab /build
ADD build\\vc_redist_x86.exe /build
ADD build\\oledlg.dll /Windows/System32

RUN DISM /Online /Add-Package /PackagePath:C:\\build\\microsoft-windows-netfx3-ondemand-package.cab ;

RUN Start-Process "C:\\build\vc_redist_x86.exe" -ArgumentList "/install"

#WAS GETTING ERRORS ON Start-Process of hMAIL, OLE needed?
RUN REGSVR32 /S /I C:\\Windows\\System32\\oledlg.dll

RUN $ErrorActionPreference = 'Stop'; \
	Set-ExecutionPolicy -ExecutionPolicy Bypass ; \
	[Net.ServicePointManager]::SecurityProtocol = 'Ssl3', 'Tls', 'Tls11', 'Tls12' ; \
	Invoke-WebRequest -Method GET -Uri "$env:MARIA_BASE_URL/$env:MARIA_VERSION/winx64-packages/$env:MARIA_VERSION-winx64.zip?serve" -UseBasicParsing -Outfile "C:\\build\\$env:MARIA_VERSION-winx64.zip" ; \
	Invoke-WebRequest -Method GET -Uri "$env:HMAIL_URL" -UseBasicParsing -Outfile "C:\\build\\$env:HMAIL_INSTALLER" ; \
	Expand-Archive -Path "C:\\build\\$env:MARIA_VERSION-winx64.zip" -DestinationPath "C:\\" ; 

RUN	cmd.exe /c '$env:Path += ";C:\\$env:MARIA_VERSION-winx64\\bin"'; \
	cmd.exe /c "setx PATH $env:path /M";
	
RUN Start-Process -FilePath "C:\\$env:MARIA_VERSION-winx64\\bin\\mysql_install_db.exe" -ArgumentList "--datadir=C:\db","--service=MySQL","--password=*" -Wait ; \
	Start-Service MySQL; \
	cmd.exe /c "C:\$env:MARIA_VERSION-winx64\bin\mysql.exe -u root -p* `< C:\\build\\$env:SQL" ;

RUN Start-Process -FilePath "C:\\build\$env:HMAIL_INSTALLER" -ArgumentList "/verysilent","/SUPPRESSMSGBOXES","/SP" -Wait;

RUN Remove-Item "C:\\build\\$env:MARIA_VERSION-winx64.zip" -Force ; \
	Remove-Item "C:\\build\\$env:HMAIL_INSTALLER" -Force ; \
	Remove-Item "C:\\build\\microsoft-windows-netfx3-ondemand-package.cab" -Force ; \
	Remove-Item "C:\\build\\vc_redist_x86.exe" -Force


ENV HMAIL_LOCATION "C:/Program Files (x86)/hMailServer/Bin/"
ADD build\\hMailServer.ini ${HMAIL_LOCATION}
ADD build\\dh2048.pem ${HMAIL_LOCATION}
ADD build\\libmysql.dll ${HMAIL_LOCATION}

RUN Start-Process -FilePath "$env:HMAIL_LOCATION/hMailServer.exe"

EXPOSE 25
