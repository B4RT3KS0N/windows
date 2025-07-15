<#
.SYNOPSIS
Prompts the user for credentials and stores them securely in the Windows Credential Manager.

.DESCRIPTION
This script prompts the user via a graphical form (username and password fields) and saves the credentials into the Windows Credential Manager.  
It is designed to support scenarios where automated login or silent authentication is needed without prompting the user during script execution.  
Credentials are stored under a specified target name and can later be retrieved programmatically by applications or scripts that support Credential Manager.  
The script also creates a simple status reporting mechanism by generating `success.txt` or `failure.txt` in a dedicated directory to confirm whether credentials were stored successfully.

The script overwrites any existing credentials for the target if they already exist.  
A maximum of 3 attempts is allowed to input non-empty credentials.

.EXAMPLE
.\win.CreateWinCredentials.ps1

.NOTES
Author: Bartłomiej Tybura
Version: 1.0
Date: 2025-07-16
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Security

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class CredMan
{
    public const int CRED_TYPE_GENERIC = 1;
    public const int CRED_TYPE_DOMAIN_PASSWORD = 2;
    public const int CRED_PERSIST_LOCAL_MACHINE = 2;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL
    {
        public uint Flags;
        public uint Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public uint CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint Persist;
        public uint AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern bool CredWrite(ref CREDENTIAL userCredential, uint flags);

    public static bool SaveCredential(string target, string user, string password)
    {
        var byteArray = System.Text.Encoding.Unicode.GetBytes(password);
        IntPtr passwordPtr = Marshal.AllocCoTaskMem(byteArray.Length);
        Marshal.Copy(byteArray, 0, passwordPtr, byteArray.Length);

        CREDENTIAL cred = new CREDENTIAL();
        cred.Flags = 0;
        cred.Type = CRED_TYPE_DOMAIN_PASSWORD;
        cred.TargetName = target;
        cred.CredentialBlobSize = (uint)byteArray.Length;
        cred.CredentialBlob = passwordPtr;
        cred.Persist = CRED_PERSIST_LOCAL_MACHINE;
        cred.AttributeCount = 0;
        cred.Attributes = IntPtr.Zero;
        cred.TargetAlias = null;
        cred.UserName = user;
        cred.Comment = null;

        bool written = CredWrite(ref cred, 0);
        Marshal.FreeCoTaskMem(passwordPtr);
        return written;
    }
"@

function Test-WindowsCredential {
    param(
        [string]$TargetName
    )

    $cred = cmdkey /list | Select-String -Pattern $TargetName
    return ($cred -ne $null)
}

function Remove-WindowsCredential {
    param(
        [string]$TargetName
    )

    cmdkey /delete:$TargetName
}

$path = "C:\Scripts\CredentialsStatus"
If (!(Test-Path -PathType Container $path)) {
    New-Item -ItemType Directory -Path $path
}

#region variables
$target = "example.com"
$UserName = $null
$Password = $null
#endregion

#region success.txt
$success = "$path\success.txt"
If (Test-Path -Path $success -PathType Leaf) {
    Remove-Item -Path $success -Force
}
#endregion

#region failure.txt
$failure = "$path\failure.txt"
If (Test-Path -Path $failure -PathType Leaf) {
    Remove-Item -Path $failure -Force
}
#endregion

#region check_for_existing_cred
if (Test-WindowsCredential -TargetName $target) {
    Remove-WindowsCredential -TargetName $target
}
#endregion

# Max 3 attempts
$attempts = 0
do {
    $attempts++

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "System Login"
    $form.Width = 300
    $form.Height = 200
    $form.StartPosition = "CenterScreen"

    $labelUser = New-Object System.Windows.Forms.Label
    $labelUser.Text = "Username:"
    $labelUser.Top = 20
    $labelUser.Left = 10
    $form.Controls.Add($labelUser)

    $textUser = New-Object System.Windows.Forms.TextBox
    $textUser.Top = 40
    $textUser.Left = 10
    $textUser.Width = 260
    $form.Controls.Add($textUser)

    $labelPass = New-Object System.Windows.Forms.Label
    $labelPass.Text = "Password:"
    $labelPass.Top = 70
    $labelPass.Left = 10
    $form.Controls.Add($labelPass)

    $textPass = New-Object System.Windows.Forms.TextBox
    $textPass.Top = 90
    $textPass.Left = 10
    $textPass.Width = 260
    $textPass.UseSystemPasswordChar = $true
    $form.Controls.Add($textPass)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Top = 130
    $okButton.Left = 200
    $okButton.Add_Click({ $form.Close() })
    $form.Controls.Add($okButton)

    $form.ShowDialog() | Out-Null

    $UserName = $textUser.Text
    $Password = $textPass.Text | ConvertTo-SecureString -AsPlainText -Force -ErrorAction SilentlyContinue

} while (([string]::IsNullOrWhiteSpace($UserName) -or [string]::IsNullOrWhiteSpace($Password)) -and $attempts -lt 3)

if ($attempts -ge 3 -or [string]::IsNullOrWhiteSpace($UserName) -or [string]::IsNullOrWhiteSpace($Password)) {
    New-Item -Path $path -Name "failure.txt" -ItemType "File" -Value "Credentials not saved due to empty fields." -Force
    Exit 1
}

$credential = New-Object System.Management.Automation.PSCredential($UserName, $Password)

$Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)
try {
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Ptr)
}

if ([CredMan]::SaveCredential($target, $UserName, $plainPassword)) {
    New-Item -Path $path -Name "success.txt" -ItemType "File" -Value "Credentials $target saved correctly in Credential Manager." -Force
    Exit 0
} else {
    $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    New-Item -Path $path -Name "failure.txt" -ItemType "File" -Value "Credentials not saved due to error $errorCode." -Force
    Exit 1
}
