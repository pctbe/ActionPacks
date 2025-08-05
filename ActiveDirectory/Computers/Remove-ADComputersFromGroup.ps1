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
    Removes computers from an Active Directory group.
.DESCRIPTION
    Deletes specified computer accounts from a group.
.PARAMETER OUPath
    Active Directory path to search.
.PARAMETER GroupName
    Name of the group from which the computers are removed.
.PARAMETER ComputerNames
    SID, SAMAccountName, DistinguishedName or GUID of the computers to remove.
.PARAMETER DomainAccount
    Optional credential for remote execution.
.PARAMETER DomainName
    Name of the Active Directory domain.
.PARAMETER AuthType
    Authentication method to use.
.EXAMPLE
    .\Remove-ADComputersFromGroup.ps1 -OUPath "OU=Computers,DC=contoso,DC=com" -GroupName "Workstations" -ComputerNames "PC1"
#>

param(
    [Parameter(Mandatory = $true,ParameterSetName = "Local or Remote DC")]
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [string]$OUPath,
    [Parameter(Mandatory = $true,ParameterSetName = "Local or Remote DC")]
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [string]$GroupName,
    [Parameter(Mandatory = $true,ParameterSetName = "Local or Remote DC")]
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [string[]]$ComputerNames,
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [PSCredential]$DomainAccount,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$DomainName,
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

$cmdArgs = @{ 'ErrorAction' = 'Stop'; 'AuthType' = $AuthType }
if ($null -ne $DomainAccount) { $cmdArgs.Add('Credential',$DomainAccount) }
if ([string]::IsNullOrWhiteSpace($DomainName)) { $cmdArgs.Add('Current','LocalComputer') } else { $cmdArgs.Add('Identity',$DomainName) }
$Domain = Get-ADDomain @cmdArgs

$res = @()
$cmdArgs = @{ 'ErrorAction' = 'Stop'; 'Server' = $Domain.PDCEmulator; 'AuthType' = $AuthType; 'Identity' = '' }
$remArgs = @{ 'ErrorAction' = 'Stop'; 'Server' = $Domain.PDCEmulator; 'AuthType' = $AuthType; 'Confirm' = $false }
if ($null -ne $DomainAccount) { $cmdArgs.Add('Credential',$DomainAccount); $remArgs.Add('Credential',$DomainAccount) }

$cmpSAMAccountNames = @()
foreach ($name in ($ComputerNames -split ',')) {
    $cmdArgs['Identity'] = $name
    $comp = Get-ADComputer @cmdArgs | Select-Object SAMAccountName
    if ($null -ne $comp) { $cmpSAMAccountNames += $comp.SAMAccountName } else { $res += "Computer $name not found" }
}

foreach ($cmp in $cmpSAMAccountNames) {
    $cmdArgs['Identity'] = $GroupName
    $grp = Get-ADGroup @cmdArgs
    if ($null -ne $grp) {
        try {
            Remove-ADGroupMember @remArgs -Identity $grp -Members $cmp
            $res += "Computer $cmp removed from Group $($grp.Name)"
        } catch {
            $res += "Error: Remove computer $cmp from Group $($grp.Name) $_"
        }
    } else {
        $res += "Group $($grp.Name) not found"
    }
}
Write-Output $res

