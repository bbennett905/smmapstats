## Mapstats Web ##

This provides an easy-to-use ASP.NET Core interface for viewing the data online, and provides a much better alternative to the in-game viewer. An example can be found [here](https://mapstats.xenogamers.com).

#### Installation ####
*Note: This assumes you have a functioning web server and database already and know how to configure your reverse proxy*

This uses ASP.NET Core 2.0, so you must first [install the correct runtime](https://www.microsoft.com/net/download/linux-package-manager/ubuntu16-04/runtime-2.0.5) for your OS.
Once you've done that, download the contents of the [/MapStatsWeb/Published/](MapStatsWeb/Published/) folder to somewhere on your server.

Next, head into the *appsettings.json* file and replace the "DefaultConnection" string with your database information, and remove the comment above it.

You probably want to run this as a service, so set up a service by creating */etc/systemd/system/kestrel-mapstats.service*, which should look something like this:
```
[Unit]
Description=Mapstats Web Panel

[Service]
WorkingDirectory=/home/username/mapstatsweb
ExecStart=/usr/bin/dotnet /home/username/mapstatsweb/MapStatsWeb.dll
Restart=always
RestartSec=10  # Restart service after 10 seconds if dotnet service crashes
SyslogIdentifier=mapstatsweb
User=username
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

[Install]
WantedBy=multi-user.target
```
Make sure that your username, working directory, and the path to the DLL are correct, then run the following commands in your terminal:
```
systemctl enable kestrel-mapstats.service
systemctl start kestrel-hellomvc.service
systemctl status kestrel-hellomvc.service
```
If the status command shows that the service is active, then all that remains is to set up your reverse proxy! (The app defaults to running on all interfaces, port 5000)