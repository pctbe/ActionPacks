#Requires -Version 5.0
<#
.NOTES
    Author: pb
    Date: 2025-08-01 20:54
    Version: 0.1
    Requires: PowerShell 5.0, Module ActiveDirectory
    Changelog:
        2025-08-01 - v0.1 - pb - Skript-Ersterstellung
.SYNOPSIS
    Enables or disables an Active Directory computer.
.DESCRIPTION
    Changes the enabled status of a computer account.
.PARAMETER OUPath
    Active Directory path to search.
.PARAMETER Computername
    DistinguishedName, DNSHostName or SAMAccountName of the computer.
.PARAMETER DomainAccount
    Optional credential for remote execution.
.PARAMETER EnableStatus
    Use 'Enable' or 'Disable' to set the computer state.
.PARAMETER DomainName
    Name of the Active Directory domain.
.PARAMETER SearchScope
    Scope of the Active Directory search.
.PARAMETER AuthType
    Authentication method to use.
.EXAMPLE
    .\Set-ADComputerStatus.ps1 -OUPath "OU=Computers,DC=contoso,DC=com" -Computername "PC1" -EnableStatus Disable
#>

param(
    [Parameter(Mandatory = $true,ParameterSetName = "Local or Remote DC")]
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [string]$OUPath,
    [Parameter(Mandatory = $true,ParameterSetName = "Local or Remote DC")]
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [string]$Computername,
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [PSCredential]$DomainAccount,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [ValidateSet('Enable','Disable')]
    [string]$EnableStatus='Enable',
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$DomainName,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [ValidateSet('Base','OneLevel','SubTree')]
    [string]$SearchScope='SubTree',
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [ValidateSet('Basic', 'Negotiate')]
    [string]$AuthType="Negotiate"
)

$moduleName = 'ActiveDirectory'
if (-not (Get-Module -ListAvailable -Name $moduleName)) {
    try {
        Install-Module -Name $moduleName -Force -Scope CurrentUser
    } catch {
        Write-Error "Module $moduleName could not be installed: $_"
        exit 1
    }
}
Import-Module $moduleName -ErrorAction Stop

[string]$sam = $Computername
if (-not $sam.EndsWith('$')) { $sam += '$' }
$cmdArgs = @{ 'ErrorAction' = 'Stop'; 'AuthType' = $AuthType }
if ($null -ne $DomainAccount) { $cmdArgs.Add('Credential',$DomainAccount) }
if ([string]::IsNullOrWhiteSpace($DomainName)) { $cmdArgs.Add('Current','LocalComputer') } else { $cmdArgs.Add('Identity',$DomainName) }
$Domain = Get-ADDomain @cmdArgs

$cmdArgs = @{ 'ErrorAction' = 'Stop'; 'AuthType' = $AuthType; 'Filter' = {(SamAccountName -eq $sam) -or (DNSHostName -eq $Computername) -or (DistinguishedName -eq $Computername)}; 'Server' = $Domain.PDCEmulator; 'SearchBase' = $OUPath; 'SearchScope' = $SearchScope; 'Properties' = '*' }
if ($null -ne $DomainAccount) { $cmdArgs.Add('Credential',$DomainAccount) }
$Cmp = Get-ADComputer @cmdArgs

if ($null -ne $Cmp) {
    $cmdArgs = @{ 'ErrorAction' = 'Stop'; 'AuthType' = $AuthType; 'Identity' = $Cmp.SamAccountName; 'Server' = $Domain.PDCEmulator }
    if ($null -ne $DomainAccount) { $cmdArgs.Add('Credential',$DomainAccount) }
    if ($EnableStatus -eq 'Enable') {
        if (-not $Cmp.Enabled) {
            Enable-ADAccount @cmdArgs
            $res = "Computer $($Cmp.Name) enabled"
        } else {
            $res = "Computer $($Cmp.Name) is not disabled"
        }
    } else {
        if ($Cmp.Enabled) {
            Disable-ADAccount @cmdArgs
            $res = "Computer $($Cmp.Name) disabled"
        } else {
            $res = "Computer $($Cmp.Name) is not enabled"
        }
    }
    Write-Output $res
} else {
    Throw "Computer $Computername not found"
}

