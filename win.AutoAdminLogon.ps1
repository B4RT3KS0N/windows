<#
.SYNOPSIS
Enables AutoAdminLogon in the Windows registry for Autopilot Pre-Provisioning scenarios.

.DESCRIPTION
This script sets the registry key `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoAdminLogon` to "1", 
which forces Windows to automatically log on the local user. It also creates a registry key to serve as a detection method 
for Intune or similar solutions to verify that the change has been applied. This is typically used during Autopilot pre-provisioning 
to bypass manual logon steps temporarily or if the configuration profiles set AutoAdminLogon to 0 (use case if CIS benchmarks are applied).

.EXAMPLE
.\win.AutoAdminLogon.ps1
Runs the script and enables AutoAdminLogon with a detection registry key.

.NOTES
Author: Bartłomiej Tybura
Version: 1.0
Date: 2025-07-16
#>

# Enable AutoAdminLogon
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value "1"

# Wait to ensure registry propagation
Start-Sleep -Seconds 15

# Create detection rule registry key
New-Item -Path "HKLM:\SOFTWARE\FALCK\TemporaryAutoAdminLogon\v1.0" -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\FALCK\TemporaryAutoAdminLogon\v1.0" -Name "TemporaryAutoAdminLogon" -PropertyType DWord -Value 1 -Force | Out-Null

# Additional pause for consistency in deployment scripts
Start-Sleep -Seconds 15

Exit 0
