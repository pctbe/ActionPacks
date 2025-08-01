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
    Sets the properties of an Active Directory computer.
.DESCRIPTION
    Updates selected attributes of a computer account.
.PARAMETER OUPath
    Active Directory path to search.
.PARAMETER Computername
    DistinguishedName, DNSHostName or SAMAccountName of the computer.
.PARAMETER DomainAccount
    Optional credential for remote execution.
.PARAMETER DNSHostName
    Fully qualified domain name of the computer.
.PARAMETER Location
    Location of the computer.
.PARAMETER Description
    Description of the computer.
.PARAMETER OperatingSystem
    Operating system name.
.PARAMETER OSServicePack
    Operating system service pack.
.PARAMETER OSVersion
    Operating system version.
.PARAMETER TrustedForDelegation
    Indicates if the account is trusted for delegation.
.PARAMETER AllowDialin
    Network access permission.
.PARAMETER EnableCallback
    Enables callback options.
.PARAMETER CallbackNumber
    Callback number.
.PARAMETER NewSAMAccountName
    New SAMAccountName for the computer.
.PARAMETER DomainName
    Name of the Active Directory domain.
.PARAMETER SearchScope
    Scope of the Active Directory search.
.PARAMETER AuthType
    Authentication method to use.
.EXAMPLE
    .\Set-ADComputerProperties.ps1 -OUPath "OU=Computers,DC=contoso,DC=com" -Computername "PC1" -Description "Test"
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
    [string]$DNSHostName,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$Location,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$Description,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$OperatingSystem,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$OSServicePack,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$OSVersion,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [switch]$TrustedForDelegation,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [switch]$AllowDialin,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [switch]$EnableCallback,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$CallbackNumber,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$NewSAMAccountName,
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
if ($null -ne $DomainAccount) { $cmdArgs.Add('Credential', $DomainAccount) }
if ([string]::IsNullOrWhiteSpace($DomainName)) { $cmdArgs.Add('Current','LocalComputer') } else { $cmdArgs.Add('Identity',$DomainName) }
$Domain = Get-ADDomain @cmdArgs

$cmdArgs = @{ 'ErrorAction' = 'Stop'; 'AuthType' = $AuthType; 'Filter' = {(SamAccountName -eq $sam) -or (DNSHostName -eq $Computername) -or (DistinguishedName -eq $Computername)}; 'Server' = $Domain.PDCEmulator; 'SearchBase' = $OUPath; 'SearchScope' = $SearchScope; 'Properties' = '*' }
if ($null -ne $DomainAccount) { $cmdArgs.Add('Credential',$DomainAccount) }
$Cmp = Get-ADComputer @cmdArgs

if ($null -ne $Cmp) {
    if ($DNSHostName) { $Cmp.DNSHostName = $DNSHostName }
    if ($Location) { $Cmp.Location = $Location }
    if ($Description) { $Cmp.Description = $Description }
    if ($OperatingSystem) { $Cmp.OperatingSystem = $OperatingSystem }
    if ($OSServicePack) { $Cmp.OperatingSystemServicePack = $OSServicePack }
    if ($OSVersion) { $Cmp.OperatingSystemVersion = $OSVersion }
    if ($PSBoundParameters.ContainsKey('TrustedForDelegation')) { $Cmp.TrustedForDelegation = $TrustedForDelegation }
    $cmdArgs = @{ 'ErrorAction' = 'Stop'; 'AuthType' = $AuthType; 'Server' = $Domain.PDCEmulator; 'PassThru' = $null }
    if ($null -ne $DomainAccount) { $cmdArgs.Add('Credential',$DomainAccount) }
    $Cmp = Set-ADComputer @cmdArgs -Instance $Cmp
    $cmdArgs.Add('Identity',$Cmp.SamAccountName)
    if ($PSBoundParameters.ContainsKey('AllowDialin')) { $Cmp = Set-ADComputer @cmdArgs -Replace @{msnpallowdialin=$AllowDialin} }
    if ($PSBoundParameters.ContainsKey('EnableCallback') -and $EnableCallback) { $Cmp = Set-ADComputer @cmdArgs -Replace @{msRADIUSServiceType=4} }
    if ($PSBoundParameters.ContainsKey('EnableCallback') -and -not $EnableCallback) { $Cmp = Set-ADComputer @cmdArgs -Remove @{msRADIUSServiceType=4} }
    if ($CallbackNumber) { $Cmp = Set-ADComputer @cmdArgs -Replace @{'msRADIUSCallbackNumber'=$CallbackNumber;'msRADIUSServiceType'=4} }
    if ($NewSAMAccountName) { $Cmp = Set-ADComputer @cmdArgs -Replace @{SAMAccountName=$NewSAMAccountName} }
    Write-Output "Computer $Computername changed"
} else {
    Throw "Computer $Computername not found"
}

