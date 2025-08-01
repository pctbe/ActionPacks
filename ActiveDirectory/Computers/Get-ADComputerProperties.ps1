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
    Gets properties of an Active Directory computer.
.DESCRIPTION
    Retrieves selected properties of a computer account from Active Directory.
.PARAMETER OUPath
    Active Directory path to search.
.PARAMETER Computername
    DistinguishedName, DNSHostName or SAMAccountName of the computer.
.PARAMETER DomainAccount
    Optional credential for remote execution.
.PARAMETER Properties
    List of properties to display. Use * for all.
.PARAMETER DomainName
    Name of the Active Directory domain.
.PARAMETER SearchScope
    Scope of the Active Directory search.
.PARAMETER AuthType
    Specifies the authentication method to use.
.EXAMPLE
    .\Get-ADComputerProperties.ps1 -OUPath "OU=Computers,DC=contoso,DC=com" -Computername "PC1" -Properties Name,IPv4Address
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
    [ValidateSet('*','Name','DistinguishedName','DNSHostName','Enabled','Description','IPv4Address','IPv6Address','LastLogonDate','LastBadPasswordAttempt','SID','Location','SAMAccountName','OperatingSystem','OperatingSystemServicePack','CanonicalName','AccountExpires')]
    [string[]]$Properties = @('Name','DistinguishedName','DNSHostName','Enabled','Description','IPv4Address','IPv6Address','LastBadPasswordAttempt','Location','OperatingSystem','SAMAccountName'),
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

if ($Properties -contains '*') {
    $Properties = @('*')
}
[string]$sam = $Computername
if (-not $sam.EndsWith('$')) { $sam += '$' }
$cmdArgs = @{ 'ErrorAction' = 'Stop'; 'AuthType' = $AuthType }
if ($null -ne $DomainAccount) { $cmdArgs.Add('Credential', $DomainAccount) }
if ([string]::IsNullOrWhiteSpace($DomainName)) { $cmdArgs.Add('Current','LocalComputer') } else { $cmdArgs.Add('Identity',$DomainName) }
$Domain = Get-ADDomain @cmdArgs

$cmdArgs = @{ 'ErrorAction' = 'Stop'; 'AuthType' = $AuthType; 'Filter' = {(SamAccountName -eq $sam) -or (DNSHostName -eq $Computername) -or (DistinguishedName -eq $Computername)}; 'Server' = $Domain.PDCEmulator; 'SearchBase' = $OUPath; 'SearchScope' = $SearchScope; 'Properties' = '*' }
if ($null -ne $DomainAccount) { $cmdArgs.Add('Credential',$DomainAccount) }
$Cmp = Get-ADComputer @cmdArgs

if ($null -ne $Cmp) {
    $resultMessage = [ordered]@{}
    if ($Properties -eq '*') {
        foreach ($itm in $Cmp.PropertyNames) {
            if ($null -ne $Cmp[$itm].Value) { $resultMessage[$itm] = $Cmp[$itm].Value }
        }
    } else {
        foreach ($itm in $Properties) { $resultMessage[$itm] = $Cmp[$itm.Trim()].Value }
    }
    $resultMessage | Format-Table -HideTableHeaders -AutoSize | Out-String | Write-Output
} else {
    Throw "Computer $Computername not found"
}

