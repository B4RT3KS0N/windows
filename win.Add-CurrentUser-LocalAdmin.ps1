<#
.SYNOPSIS
Adds the currently logged-in user to the local Administrators group.

.DESCRIPTION
This script retrieves the currently logged-in username in DOMAIN\username format, converts it into UPN format (username@domain.com), 
and attempts to add the user to the local Administrators group as an AzureAD account.

This solution is useful in hybrid environments where users authenticate via AzureAD but require temporary local administrative permissions on their machines.

**Important limitation:**  
This script assumes that the local SAMAccountName (the username portion after DOMAIN\) is identical to the user's AzureAD primary SMTP address prefix (mail nickname).  
If the user's primary SMTP address has been manually changed or differs from their original UPN or SAMAccountName, this script will fail because it will generate an invalid UPN.

.EXAMPLE
.\win.Add-CurrentUser-LocalAdmin.ps1
Adds the currently logged-in user to the local Administrators group.

.NOTES
Author: Bartłomiej Tybura
Version: 1.0
Date: 2025-07-16
#>

# Get current user in DOMAIN\username format
$sam = (Get-WMIObject -ClassName Win32_ComputerSystem).Username

# Extract only the username (remove DOMAIN\)
$trimmed = $sam -replace '^.*\\', ''

# Create UPN for AzureAD
$name = "$trimmed@domain.com"

# Attempt to add user to local administrators group
$result = cmd /c "Net localgroup administrators AzureAD\$name /add"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Local Admin Rights have been assigned to user $name."
    Show-Message -message "Local admin rights assigned to user $name. Please restart your computer for the changes to take effect." -title "Installation Successful"
    Exit 0
} else {
    throw "Error adding user $name to local administrators group. Exit code $LASTEXITCODE."
    Exit 1
}
