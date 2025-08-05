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
    Lists disabled or inactive computers.
.DESCRIPTION
    Retrieves computers that are disabled or inactive within the specified search scope.
.PARAMETER OUPath
    Active Directory path to search.
.PARAMETER Disabled
    Shows disabled computers.
.PARAMETER InActive
    Shows inactive computers.
.PARAMETER DomainAccount
    Optional credential for remote execution.
.PARAMETER DomainName
    Name of the Active Directory domain.
.PARAMETER SearchScope
    Scope of the Active Directory search.
.PARAMETER AuthType
    Specifies the authentication method to use.
.EXAMPLE
    .\Get-ADComputersWithDefinedStatus.ps1 -OUPath "OU=Computers,DC=contoso,DC=com" -Disabled
#>

param(
    [Parameter(Mandatory = $true,ParameterSetName = "Local or Remote DC")]
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [string]$OUPath,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [switch]$Disabled,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [switch]$InActive,
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [PSCredential]$DomainAccount,
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

$resultMessage = @()
$cmdArgs = @{ 'ErrorAction' = 'Stop'; 'AuthType' = $AuthType }
if ($null -ne $DomainAccount) { $cmdArgs.Add('Credential', $DomainAccount) }
if ([string]::IsNullOrWhiteSpace($DomainName)) { $cmdArgs.Add('Current','LocalComputer') } else { $cmdArgs.Add('Identity',$DomainName) }
$Domain = Get-ADDomain @cmdArgs

$cmdArgs = @{ 'ErrorAction' = 'Stop'; 'AuthType' = $AuthType; 'ComputersOnly' = $null; 'Server' = $Domain.PDCEmulator; 'SearchBase' = $OUPath; 'SearchScope' = $SearchScope }
if ($null -ne $DomainAccount) { $cmdArgs.Add('Credential', $DomainAccount) }
if ($Disabled) {
    $computers = Search-ADAccount @cmdArgs -AccountDisabled | Select-Object DistinguishedName,SAMAccountName | Sort-Object SAMAccountName
    if ($computers) {
        foreach ($itm in $computers) { $resultMessage += "Disabled: $($itm.DistinguishedName);$($itm.SamAccountName)" }
        $resultMessage += ''
    }
}
if ($InActive) {
    $computers = Search-ADAccount @cmdArgs -AccountInactive -SearchBase $OUPath -SearchScope $SearchScope | Select-Object DistinguishedName,SAMAccountName | Sort-Object SAMAccountName
    if ($computers) {
        foreach ($itm in $computers) { $resultMessage += "Inactive: $($itm.DistinguishedName);$($itm.SamAccountName)" }
    }
}
Write-Output $resultMessage

