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
    Adds computers to Active Directory groups.
.DESCRIPTION
    Adds the specified computers to one or more groups in Active Directory.
.PARAMETER OUPath
    Active Directory path of the target domain or OU.
.PARAMETER ComputerNames
    SAMAccountName, SID, DistinguishedName or GUID of the computers to add.
.PARAMETER GroupNames
    Names of the groups the computers will be added to.
.PARAMETER DomainAccount
    Optional credential for remote execution.
.PARAMETER DomainName
    Name of the Active Directory domain.
.PARAMETER AuthType
    Specifies the authentication method to use.
.EXAMPLE
    .\Add-ADComputersToGroups.ps1 -OUPath "OU=Computers,DC=contoso,DC=com" -ComputerNames "PC1" -GroupNames "Workstations"
#>

param(
    [Parameter(Mandatory = $true,ParameterSetName = "Local or Remote DC")]
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [string]$OUPath,
    [Parameter(Mandatory = $true,ParameterSetName = "Local or Remote DC")]
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [string[]]$ComputerNames,
    [Parameter(Mandatory = $true,ParameterSetName = "Local or Remote DC")]
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [string[]]$GroupNames,
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

[hashtable]$cmdArgs = @{ 'ErrorAction' = 'Stop'; 'AuthType' = $AuthType }
if ($null -ne $DomainAccount) {
    $cmdArgs.Add('Credential', $DomainAccount)
}
if ([string]::IsNullOrWhiteSpace($DomainName)) {
    $cmdArgs.Add('Current', 'LocalComputer')
} else {
    $cmdArgs.Add('Identity', $DomainName)
}
$Domain = Get-ADDomain @cmdArgs

[string[]]$res = @()
[string[]]$cmpSAMAccountNames = @()
$cmdArgs = @{ 'ErrorAction' = 'Stop'; 'Server' = $Domain.PDCEmulator; 'AuthType' = $AuthType; 'Identity' = '' }
if ($null -ne $DomainAccount) {
    $cmdArgs.Add('Credential', $DomainAccount)
}
foreach ($name in ($ComputerNames -split ',')) {
    $cmdArgs['Identity'] = $name
    $cmp = Get-ADComputer @cmdArgs | Select-Object SAMAccountName
    if ($null -ne $cmp) {
        $cmpSAMAccountNames += $cmp.SAMAccountName
    } else {
        $res += "Computer $name not found"
    }
}

$groupArgs = @{ 'ErrorAction' = 'Stop'; 'AuthType' = $AuthType; 'Server' = $Domain.PDCEmulator; 'Identity' = '' }
$cmdArgs = @{ 'ErrorAction' = 'Stop'; 'Server' = $Domain.PDCEmulator; 'AuthType' = $AuthType }
if ($null -ne $DomainAccount) {
    $cmdArgs.Add('Credential', $DomainAccount)
    $groupArgs.Add('Credential', $DomainAccount)
}
foreach ($comp in $cmpSAMAccountNames) {
    foreach ($itm in ($GroupNames -split ',')) {
        $groupArgs['Identity'] = $itm
        $grp = Get-ADGroup @groupArgs
        if ($null -ne $grp) {
            try {
                Add-ADGroupMember @cmdArgs -Identity $grp -Members $comp
                $res += "Computer $comp added to Group $itm"
            } catch {
                $res += "Error: Add computer $comp to Group $itm $_"
            }
        } else {
            $res += "Group $itm not found"
        }
    }
}
Write-Output $res
