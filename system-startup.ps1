#!/bin/bash

# The MIT License (MIT)
#
# Copyright (c) 2015 Microsoft Azure
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# start loggings
New-Item -ItemType Directory c:\applogs -ErrorAction SilentlyContinue

# Firewall
netsh advfirewall firewall add rule name="http" dir=in action=allow protocol=TCP localport=80

# Folders
New-Item -ItemType Directory c:\temp -ErrorAction SilentlyContinue
New-Item -ItemType Directory c:\app -ErrorAction SilentlyContinue

# .NET framework 4.6.2 download and install
$dotnetExePath = "C:\temp\dotnetframework.exe"
if (!([System.IO.File]::Exists($dotnetExePath)))
{
    Invoke-WebRequest http://go.microsoft.com/fwlink/?linkid=780600 -outfile $dotnetExePath
    Start-Process $dotnetExePath -ArgumentList '/quiet' -Wait

    # Install IIS    
    Install-WindowsFeature web-server -IncludeManagementTools

    # Enable features on IIS
    Add-WindowsFeature Web-Server
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpErrors
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpRedirect
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationDevelopment
    Enable-WindowsOptionalFeature -online -FeatureName NetFx4Extended-ASPNET45
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-NetFxExtensibility45
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HealthAndDiagnostics
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpLogging
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-LoggingLibraries
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-RequestMonitor
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpTracing
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-Security
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-RequestFiltering
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-Performance
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerManagementTools
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-IIS6ManagementCompatibility
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-Metabase
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ManagementConsole
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-BasicAuthentication
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-StaticContent
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-DefaultDocument
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebSockets
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationInit
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ISAPIExtensions
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ISAPIFilter
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpCompressionStatic
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45
}

# Install the app for the first time
Invoke-WebRequest https://livecacheproxyblob.blob.core.windows.net/livecacheproxycontainer/app-startup.ps1 -OutFile c:\temp\app-startup.ps1
Invoke-Expression "powershell c:\temp\app-startup.ps1"

# Install IIS
if (Get-Website -Name "Default Web Site") 
{
    Remove-WebSite -Name "Default Web Site"
}

if (Get-Website -Name "Subliminal") 
{
    Remove-WebSite -Name "Subliminal"
}

if (!(Get-Website -Name "Underdog"))
{
    New-Website -Name "Underdog" -Port 80 -PhysicalPath C:\app\ -ApplicationPool DefaultAppPool
}

Set-ItemProperty IIS:\AppPools\DefaultAppPool\ managedRuntimeVersion v4.0
& iisreset

# Now set up a scheduled task so that on reboot, the latest app is installed
$action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "c:\temp\app-startup.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable
Register-ScheduledTask -TaskName "GetLatestApp" -Force -Action $action -Principal $principal -Trigger $trigger -Settings $settings -Description "Downloads the latest published version of the app"
