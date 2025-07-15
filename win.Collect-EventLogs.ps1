<#
.SYNOPSIS
Collects and summarizes selected Windows Event Logs entries from the past 30 days.

.DESCRIPTION
The script checks for the existence of specific Windows Event Logs and extracts entries from the past 30 days. For the "Security" log, it collects only "FailureAudit" entries. For other logs, it collects "Critical", "Error", or "Warning" entries.
It counts and summarizes identical log entries and saves the results to text files, grouped by log name.

.EXAMPLE
.\win.Collect-EventLogs.ps1

.NOTES
Author: Bartłomiej Tybura
Version: 1.0
Date: 2025-07-16
#>

# Variables declaration
$logpath = "C:\Audit"
if (!(Test-Path $logpath)) {
    New-Item $logpath -ItemType Directory -Force
}

$lonames = "Security"  #,"System","DNS Server","Application","Directory Service","DFS Replication","Hardware Events","Active Directory Web Services","Windows PowerShell"
$compname = [Environment]::MachineName

$lonames | ForEach-Object {
    $name = $_
    $flname = "$compname $name.txt"
    $nolog = "$logpath\$compname nolog.txt"
    $tmpfile = "$logpath\$flname"

    if ((Get-EventLog -List).Log -contains $name) {
        $header = "ID|Level|Source|Message|EvnCount"
        $header | Out-File -FilePath $tmpfile -Force
        
        Write-Host "Reading log $name started" -BackgroundColor Green
        
        if ($name -like "Security") {
            $alllogs = Get-EventLog -LogName $name -After (Get-Date).AddDays(-30) | Where-Object { $_.EntryType -like "FailureAudit" }
        }
        else {
            $alllogs = Get-EventLog -LogName $name -After (Get-Date).AddDays(-30) | Where-Object { $_.EntryType -in @("Critical", "Error", "Warning") }
        }

        $alllogs | ForEach-Object {
            $message = $_.Message.Split("`n").Trim().Replace("`t", "")[0..40]
            [string]$eventID = $_.EventID
            [string]$source = $_.Source
            [string]$level = $_.EntryType
            [string]$check = "$eventID|$level|$source|$message"

            [string]$existingEntry = Get-Content $tmpfile -ErrorAction SilentlyContinue | Select-String -Pattern $check -CaseSensitive -SimpleMatch
            if ($existingEntry) {
                [int]$currentCount = $existingEntry -replace '.*\|', ''
                $newCount = $currentCount + 1
                $newEntry = $existingEntry -replace "\|$currentCount", "|$newCount"
                $fileContent = Get-Content $tmpfile -ErrorAction SilentlyContinue
                $fileContent = $fileContent.Replace($existingEntry, $newEntry)
                $fileContent | Out-File -FilePath $tmpfile -Force
            }
            else {
                Add-Content -Path $tmpfile -Value "$check|1"
            }
        }

        Write-Host "Reading log $name completed" -BackgroundColor Red
    }
    else {
        $message = "Log $name does not exist on computer $compname"
        Write-Host $message -BackgroundColor Red -ForegroundColor White
        $message | Out-File -FilePath $nolog -Append
    }
}
