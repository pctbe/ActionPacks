#Requires -Version 5.0
<#
.NOTES
    Author: pb
    Date: 2025-08-01 20:54
    Version: 0.3
    Requires: PowerShell 5.0, Module ActiveDirectory
    Changelog:
        2025-08-01 - v0.1 - pb - Skript-Ersterstellung
        2025-08-04 - v0.2 - pb - Parameter-Set Problem behoben
        2025-08-04 - v0.3 - pb - OUPath optional gemacht, erweiterte Dokumentation
.SYNOPSIS
    Retrieves detailed properties of an Active Directory computer account.
.DESCRIPTION
    This script searches for a computer in Active Directory and displays selected properties.
    It can search in a specific Organizational Unit (OU) or across the entire domain.
    The script automatically handles different computer name formats and provides flexible output options.
.PARAMETER OUPath
    OPTIONAL: The Distinguished Name of the Organizational Unit to search in.
    If not specified, the script searches the entire domain.
    
    Format: "OU=SubOU,OU=ParentOU,DC=domain,DC=com"
    Examples:
    - "OU=Computers,DC=contoso,DC=com" (Standard computer container)
    - "OU=mobil,OU=abt01,OU=fab-computer,DC=faba,DC=fab,DC=de" (Nested OUs)
    - "DC=contoso,DC=com" (Domain root)
.PARAMETER Computername
    REQUIRED: The name or identifier of the computer to search for.
    Accepts multiple formats:
    - Computer name: "PC001", "LAPTOP-ABC123"
    - DNS Host Name: "pc001.domain.com"
    - SAM Account Name: "PC001$"
    - Distinguished Name: "CN=PC001,OU=Computers,DC=domain,DC=com"
.PARAMETER DomainAccount
    OPTIONAL: PSCredential object for authentication when accessing remote domains.
    Use when your current credentials don't have sufficient permissions.
    
    Example: $cred = Get-Credential; -DomainAccount $cred
.PARAMETER Properties
    OPTIONAL: Array of properties to display. Default shows most common properties.
    
    Available options:
    - Specific properties: Name,IPv4Address,OperatingSystem
    - All properties: * (shows everything available)
    
    Common properties:
    - Name, DNSHostName, SAMAccountName
    - IPv4Address, IPv6Address
    - OperatingSystem, OperatingSystemServicePack
    - Enabled, Description, Location
    - LastLogonDate, LastBadPasswordAttempt
    - DistinguishedName, CanonicalName
    - SID, AccountExpires
    
    Default properties: Name, DistinguishedName, DNSHostName, Enabled, Description, 
    IPv4Address, IPv6Address, LastBadPasswordAttempt, Location, OperatingSystem, SAMAccountName
.PARAMETER DomainName
    OPTIONAL: The name of the Active Directory domain to query.
    If not specified, uses the current computer's domain.
    
    Format: "domain.com", "subdomain.domain.com"
    Examples: "contoso.com", "faba.fab.de"
.PARAMETER SearchScope
    OPTIONAL: Defines how deep to search within the specified OU.
    
    Options:
    - Base: Only the specified OU itself
    - OneLevel: The specified OU and its direct child objects
    - SubTree: The specified OU and all nested child objects (DEFAULT)
.PARAMETER AuthType
    OPTIONAL: Authentication method for the Active Directory connection.
    
    Options:
    - Negotiate: Uses Kerberos if possible, falls back to NTLM (DEFAULT)
    - Basic: Uses basic authentication (less secure)
.EXAMPLE
    .\Get-ADComputerProperties.ps1 -Computername "pc001"
    
    Searches for computer "pc001" in the current domain using default properties.
    This is the simplest usage - just specify the computer name.
.EXAMPLE
    .\Get-ADComputerProperties.ps1 -Computername "pc001" -DomainName "faba.fab.de"
    
    Searches for computer "pc001" in the entire "faba.fab.de" domain.
    Uses default properties for display.
.EXAMPLE
    .\Get-ADComputerProperties.ps1 -OUPath "OU=mobil,OU=abt01,OU=fab-computer,DC=faba,DC=fab,DC=de" -Computername "pc001"
    
    Searches for computer "pc001" only within the specific OU path.
    More targeted search when you know the exact location.
.EXAMPLE
    .\Get-ADComputerProperties.ps1 -Computername "pc001" -Properties Name,IPv4Address,OperatingSystem,LastLogonDate
    
    Shows only specific properties: computer name, IP address, operating system, and last logon.
    Perfect for quick network inventory.
.EXAMPLE
    .\Get-ADComputerProperties.ps1 -Computername "pc001" -Properties *
    
    Shows ALL available properties for the computer.
    Useful for detailed troubleshooting or complete inventory.
.EXAMPLE
    $cred = Get-Credential
    .\Get-ADComputerProperties.ps1 -Computername "pc001" -DomainName "remote.domain.com" -DomainAccount $cred
    
    Searches in a remote domain using alternative credentials.
    Prompts for username and password first.
.EXAMPLE
    .\Get-ADComputerProperties.ps1 -Computername "pc001" -Properties Name,Enabled,LastLogonDate,LastBadPasswordAttempt
    
    Security-focused view: Shows computer status and authentication history.
    Useful for security audits.
.EXAMPLE
    .\Get-ADComputerProperties.ps1 -Computername "pc001" -Properties Name,IPv4Address,IPv6Address,DNSHostName -DomainName "faba.fab.de"
    
    Network-focused view: Shows all network-related information.
    Perfect for network administrators.
.EXAMPLE
    .\Get-ADComputerProperties.ps1 -Computername "LAPTOP-ABC123" -Properties Name,OperatingSystem,OperatingSystemServicePack,Description,Location
    
    System information view: Shows hardware and system details.
    Useful for inventory management.
.EXAMPLE
    .\Get-ADComputerProperties.ps1 -OUPath "OU=abt01,OU=fab-computer,DC=faba,DC=fab,DC=de" -Computername "pc001" -SearchScope OneLevel
    
    Searches only in the specified OU and its direct children, not in nested sub-OUs.
    Useful when you want to limit search depth.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$OUPath,
    
    [Parameter(Mandatory = $true)]
    [string]$Computername,
    
    [Parameter(Mandatory = $false)]
    [PSCredential]$DomainAccount,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('*','Name','DistinguishedName','DNSHostName','Enabled','Description','IPv4Address','IPv6Address','LastLogonDate','LastBadPasswordAttempt','SID','Location','SAMAccountName','OperatingSystem','OperatingSystemServicePack','CanonicalName','AccountExpires')]
    [string[]]$Properties = @('Name','DistinguishedName','DNSHostName','Enabled','Description','IPv4Address','IPv6Address','LastBadPasswordAttempt','Location','OperatingSystem','SAMAccountName'),
    
    [Parameter(Mandatory = $false)]
    [string]$DomainName,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Base','OneLevel','SubTree')]
    [string]$SearchScope='SubTree',
    
    [Parameter(Mandatory = $false)]
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
if ([string]::IsNullOrWhiteSpace($DomainName)) { 
    $cmdArgs.Add('Current','LocalComputer') 
} else { 
    $cmdArgs.Add('Identity',$DomainName) 
}

try {
    $Domain = Get-ADDomain @cmdArgs
} catch {
    Write-Error "Failed to get AD Domain: $_"
    exit 1
}

# Wenn kein OUPath angegeben wurde, verwende die Domain-Root
if ([string]::IsNullOrWhiteSpace($OUPath)) {
    $OUPath = $Domain.DistinguishedName
    Write-Verbose "No OUPath specified, searching in entire domain: $OUPath"
}

$cmdArgs = @{ 
    'ErrorAction' = 'Stop'
    'AuthType' = $AuthType
    'Filter' = {(SamAccountName -eq $sam) -or (DNSHostName -eq $Computername) -or (DistinguishedName -eq $Computername)}
    'Server' = $Domain.PDCEmulator
    'SearchBase' = $OUPath
    'SearchScope' = $SearchScope
    'Properties' = '*' 
}

if ($null -ne $DomainAccount) { 
    $cmdArgs.Add('Credential',$DomainAccount) 
}

try {
    $Cmp = Get-ADComputer @cmdArgs
} catch {
    Write-Error "Failed to get AD Computer: $_"
    exit 1
}

if ($null -ne $Cmp) {
    $resultMessage = [ordered]@{}
    if ($Properties -eq '*') {
        foreach ($itm in $Cmp.PropertyNames) {
            if ($null -ne $Cmp[$itm].Value) { 
                $resultMessage[$itm] = $Cmp[$itm].Value 
            }
        }
    } else {
        foreach ($itm in $Properties) { 
            $resultMessage[$itm] = $Cmp[$itm.Trim()].Value 
        }
    }
    $resultMessage | Format-Table -HideTableHeaders -AutoSize | Out-String | Write-Output
} else {
    Throw "Computer $Computername not found"
