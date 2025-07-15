<#
.SYNOPSIS
Reads and parses the user's OneDrive (for Business) SyncDiagnostics.log file to verify the sync status.

.DESCRIPTION
This script reads the user's OneDrive (for Business) SyncDiagnostics.log file located under the local profile and extracts key properties related to synchronization status.
It helps determine whether the OneDrive sync is operating properly or if there are any sync-related issues.

.EXAMPLE
.\win.Get-OneDriveSyncStatus.ps1

.NOTES
Author: Bartłomiej Tybura
Version: 1.0
Date: 2025-07-16
#>

# Load OneDrive Sync Diagnostics log content
$SyncDiag_Content = Get-Content "$env:USERPROFILE\AppData\Local\Microsoft\OneDrive\logs\Business1\SyncDiagnostics.log"

# Create a custom PowerShell object from log key-value pairs
$OneDrive_SyncDiag = New-Object PSObject

$SyncDiag_Content | Where-Object {
    ($_ -match '=') -or (($_ -match ':') -and ($_ -notlike "*==*"))
} | ForEach-Object {
    if ($_ -like "*=*") {
        $Item = ($_.Trim() -split '= ', 2).Trim()
    }
    elseif ($_ -like "*:*") {
        $Item = ($_.Trim() -split ': ', 2).Trim()
    }
    $OneDrive_SyncDiag | Add-Member -MemberType NoteProperty -Name $Item[0] -Value $Item[1] -ErrorAction SilentlyContinue
}

# Output the parsed OneDrive sync information
$OneDrive_SyncDiag
