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
    Creates a new Active Directory computer.
.DESCRIPTION
    Creates a computer account with optional properties.
.PARAMETER OUPath
    Active Directory path for the new computer.
.PARAMETER Computername
    Name of the computer.
.PARAMETER Description
    Description for the computer.
.PARAMETER DisplayName
    Display name of the computer.
.PARAMETER DNSHostname
    Fully qualified domain name of the computer.
.PARAMETER Enabled
    Computer is enabled.
.PARAMETER Homepage
    Home page URL.
.PARAMETER OperationSystem
    Operating system name.
.PARAMETER ManagedBy
    User or group that manages the computer.
.PARAMETER DomainAccount
    Optional credential for remote execution.
.PARAMETER DomainName
    Name of the Active Directory domain.
.PARAMETER AuthType
    Authentication method to use.
.EXAMPLE
    .\New-ADComputer.ps1 -OUPath "OU=Computers,DC=contoso,DC=com" -Computername "PC1" -Enabled
#>

param(
    [Parameter(Mandatory = $true,ParameterSetName = "Local or Remote DC")]
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [string]$OUPath,
    [Parameter(Mandatory = $true,ParameterSetName = "Local or Remote DC")]
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [string]$Computername,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$Description,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$DisplayName,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$DNSHostname,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [bool]$Enabled,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$Homepage,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$OperationSystem,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$ManagedBy,
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [PSCredential]$DomainAccount,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$DomainName,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [ValidateSet('Basic', 'Negotiate')]
    [string]$AuthType = "Negotiate"
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

$cmdArgs = @{ 'ErrorAction' = 'Stop'; 'AuthType' = $AuthType }
if ($null -ne $DomainAccount) { $cmdArgs.Add('Credential',$DomainAccount) }
if ([string]::IsNullOrWhiteSpace($DomainName)) { $cmdArgs.Add('Current','LocalComputer') } else { $cmdArgs.Add('Identity',$DomainName) }
$Domain = Get-ADDomain @cmdArgs

$cmdArgs = @{ 'ErrorAction' = 'Stop'; 'AuthType' = $AuthType; 'Name' = $Computername; 'Server' = $Domain.PDCEmulator; 'Path' = $OUPath; 'Confirm' = $false; 'PassThru' = $null }
if ($null -ne $DomainAccount) { $cmdArgs.Add('Credential',$DomainAccount) }
if ($PSBoundParameters.ContainsKey('Description')) { $cmdArgs.Add('Description',$Description) }
if ($PSBoundParameters.ContainsKey('Enabled')) { $cmdArgs.Add('Enabled',$Enabled) }
if ($PSBoundParameters.ContainsKey('DisplayName')) { $cmdArgs.Add('DisplayName',$DisplayName) }
if ($PSBoundParameters.ContainsKey('DNSHostname')) { $cmdArgs.Add('DNSHostname',$DNSHostname) }
if ($PSBoundParameters.ContainsKey('Homepage')) { $cmdArgs.Add('Homepage',$Homepage) }
if ($PSBoundParameters.ContainsKey('OperationSystem')) { $cmdArgs.Add('OperationSystem',$OperationSystem) }
if ($PSBoundParameters.ContainsKey('ManagedBy')) { $cmdArgs.Add('ManagedBy',$ManagedBy) }

$cmp = New-ADComputer @cmdArgs
Write-Output $cmp

