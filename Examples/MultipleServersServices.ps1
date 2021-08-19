#Fixed 
# Define what type of server this is and set an object for each server you want to configure 
$Servers = "DC1", "DC2"

$ServicesOverall = @('BDESVC', 'EventLog', 'gpsvc', 'Schedule', 'Spooler', 'TermService', 'MpsSvc', 'FA_Scheduler'
    'vmicheartbeat', 'vmickvpexchange', 'vmicrdv', 'vmicshutdown', 'vmictimesync', 'vmicvss', 'VSS', 'W32Time', 'WinDefend',
    'WindowsAzureGuestAgent', 'WindowsAzureNetAgentSvc', 'WindowsAzureTelemetryService', 'AATPSensor', 'AATPSensorUpdater',
    'WpnService', 'wuauserv', 'BITS', 'Dhcp', 'EFS', 'LanmanServer', 'LanmanWorkstation', 'RpcEptMapper', 'VaultSvc', 'RpcSs', 'netprofm', 'MSDTC', 'DPS', 'ClickToRunSvc')
#$ServicesIIS = @('W3SVC', 'IISADMIN', 'AppHostSvc', 'AppIDSvc', 'Appinfo', 'AppMgmt')
$ServicesSecurity = @('WinDefend','mpssvc')
#$ServicesHA = @('Dfs', 'DFSR', 'ClusSvc')
#$ServicesSQL = @('SQLWriter', 'MSSQL*', 'MsDtsServer*', 'MSSQLFDLauncher*', 'SQLAgent*', 'SQLBrowser', 'SQLIaaSExtension', 'SQLSERVERAGENT', 'SQLWriter', 'SSDPSRV', 'MSDTC')
#$ServicesSQLControl = @('SQLTELEMETRY*', 'SSISTELEMETRY')
$ServicesMonitorOverall = @('DNSCache', 'Winmgmt', 'WinRM', 'RemoteRegistry')
$ServicesAD = @('ADWS', 'Netlogon', 'DNS', 'NTDS')
$ServicesMonitoring = @('PC Monitor', 'RdAgent')
#$ServicesVeeam = @('VeeamDeploySvc', 'VeeamEndpointBackupSvc')
#$ServicesFileServer = @('srmsvc', 'SmbHash', 'SmbWitness', 'smphost')
#$ServicesRDS = @('TermServLicensing', 'TScPubRPC', 'Tssdis', 'CcmExec')
#$ServicesService = @('SMTPSVC', 'SolarWinds SFTP Server')
#$ServicesNPS = @('IAS')
#$ServicesADFS = @('adfssrv', 'appproxyctrl', 'appproxysvc')
#$ServicesADConnect = @('ADSync', 'AzureADConnectHealthSyncInsights', 'AzureADConnectHealthSyncMonitor', 'WindowsAzureGuestAgent', 'WindowsAzureNetAgentSvc')
#ServicesTEIIS = @('Isonet*')
#$ServicesSCCM = @('SMS_EXECUTIVE', 'SMS_NOTIFICATION_SERVER', 'SMS_SITE_COMPONENT_MANAGER', 'SMS_SITE_SQL_BACKUP', 'SMS_SITE_VSS_WRITER')
#$ServicesRRAS = @('RaMgmtSvc', 'RasMan')
#$ServicesBackup = @('VeeamBackupSvc', 'VeeamBrokerSvc', 'VeeamCatalogSvc', 'VeeamCloudSvc', 'VeeamDeploySvc', 'VeeamDistributionSvc', 'VeeamMountSvc', 'VeeamNFSSvc', 'VeeamTransportSvc')
#$ServicesCA = @('CertSvc')
#$ServicesPrintServer = @('Spooler')
#$ServicesHyperV = @('vmickvpexchange', 'vmicguestinterface', 'vmicshutdown', 'vmicheartbeat', 'vmcompute', 'vmicvmsession', 'vmicrdv', 'vmictimesync', 'vmms', 'vmicvss')


### prepare services for monitoring, and control

$ServiceMonitor = $ServicesIIS + $ServicesHA + $ServicesSQL + $ServicesMonitorOverall + $ServicesAD + $ServicesFortinet + $ServicesVeeam + $ServicesFileServer + $ServicesRDS + $ServicesService + `
    $ServicesNPS + $ServicesADFS + $ServicesADConnect + $ServicesTEIIS + $ServicesSCCM + $ServicesRRAS + `
    $ServicesBackup + $ServicesATA + $ServicesCA + $ServicesPrintServer + $ServicesHyperV + $ServicesSecurity | Sort-Object -Unique

Enum NotificationStatus {
    Enabled = 1;
    Disabled = 0;
}
Enum NotificationType {
    <#
        Accessing
        [NotificationType] $Day = [NotificationType]::Critical
        1 -As [NotificationType]
    #>
    Critical = 3;
    Elevated = 2;
    Normal = 1;
    Low = 0;
}
Enum Status {
    No = 0; Yes = 1;
}
Enum PulsewayStatus {
    NotAvailable = 0;
    NotRunning = 1;
    Running = 2;
}
Enum DiskStatus {
    Enabled = 1;
    Disabled = 0;
}

function Get-ComputerSplit {
    [CmdletBinding()]
    param(
        [string[]] $ComputerName
    )
    if ($null -eq $ComputerName) {
        $ComputerName = $Env:COMPUTERNAME
    }
    try {
        $LocalComputerDNSName = [System.Net.Dns]::GetHostByName($Env:COMPUTERNAME).HostName
    } catch {
        $LocalComputerDNSName = $Env:COMPUTERNAME
    }
    $ComputersLocal = $null
    [Array] $Computers = foreach ($Computer in $ComputerName) {
        if ($Computer -eq '' -or $null -eq $Computer) {
            $Computer = $Env:COMPUTERNAME
        }
        if ($Computer -ne $Env:COMPUTERNAME -and $Computer -ne $LocalComputerDNSName) {
            $Computer
        } else {
            $ComputersLocal = $Computer
        }
    }
    , @($ComputersLocal, $Computers)
}

function Get-CimData {
    <#
    .SYNOPSIS
    Helper function for retreiving CIM data from local and remote computers

    .DESCRIPTION
    Helper function for retreiving CIM data from local and remote computers

    .PARAMETER ComputerName
    Specifies computer on which you want to run the CIM operation. You can specify a fully qualified domain name (FQDN), a NetBIOS name, or an IP address. If you do not specify this parameter, the cmdlet performs the operation on the local computer using Component Object Model (COM).

    .PARAMETER Protocol
    Specifies the protocol to use. The acceptable values for this parameter are: DCOM, Default, or Wsman.

    .PARAMETER Class
    Specifies the name of the CIM class for which to retrieve the CIM instances. You can use tab completion to browse the list of classes, because PowerShell gets a list of classes from the local WMI server to provide a list of class names.

    .PARAMETER Properties
    Specifies a set of instance properties to retrieve. Use this parameter when you need to reduce the size of the object returned, either in memory or over the network. The object returned also contains the key properties even if you have not listed them using the Property parameter. Other properties of the class are present but they are not populated.

    .EXAMPLE
    Get-CimData -Class 'win32_bios' -ComputerName AD1,EVOWIN

    Get-CimData -Class 'win32_bios'

    # Get-CimClass to get all classes

    .NOTES
    General notes
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory)][string] $Class,
        [string] $NameSpace = 'root\cimv2',
        [string[]] $ComputerName = $Env:COMPUTERNAME,
        [ValidateSet('Default', 'Dcom', 'Wsman')][string] $Protocol = 'Default',
        [string[]] $Properties = '*'
    )
    $ExcludeProperties = 'CimClass', 'CimInstanceProperties', 'CimSystemProperties', 'SystemCreationClassName', 'CreationClassName'

    # Querying CIM locally usually doesn't work. This means if you're querying same computer you neeed to skip CimSession/ComputerName if it's local query
    [Array] $ComputersSplit = Get-ComputerSplit -ComputerName $ComputerName

    $CimObject = @(
        # requires removal of this property for query
        [string[]] $PropertiesOnly = $Properties | Where-Object { $_ -ne 'PSComputerName' }
        # Process all remote computers
        $Computers = $ComputersSplit[1]
        if ($Computers.Count -gt 0) {
            if ($Protocol = 'Default') {
                Get-CimInstance -ClassName $Class -ComputerName $Computers -ErrorAction SilentlyContinue -Property $PropertiesOnly -Namespace $NameSpace -Verbose:$false -ErrorVariable ErrorsToProcess | Select-Object -Property $Properties -ExcludeProperty $ExcludeProperties
            } else {
                $Option = New-CimSessionOption -Protocol $Protocol
                $Session = New-CimSession -ComputerName $Computers -SessionOption $Option -ErrorAction SilentlyContinue
                $Info = Get-CimInstance -ClassName $Class -CimSession $Session -ErrorAction SilentlyContinue -Property $PropertiesOnly -Namespace $NameSpace -Verbose:$false -ErrorVariable ErrorsToProcess | Select-Object -Property $Properties -ExcludeProperty $ExcludeProperties
                $null = Remove-CimSession -CimSession $Session -ErrorAction SilentlyContinue
                $Info
            }
        }
        foreach ($E in $ErrorsToProcess) {
            Write-Warning -Message "Get-CimData - No data for computer $($E.OriginInfo.PSComputerName). Failed with errror: $($E.Exception.Message)"
        }
        # Process local computer
        $Computers = $ComputersSplit[0]
        if ($Computers.Count -gt 0) {
            $Info = Get-CimInstance -ClassName $Class -ErrorAction SilentlyContinue -Property $PropertiesOnly -Namespace $NameSpace -Verbose:$false -ErrorVariable ErrorsLocal | Select-Object -Property $Properties -ExcludeProperty $ExcludeProperties
            $Info | Add-Member -Name 'PSComputerName' -Value $Computers -MemberType NoteProperty -Force
            $Info
        }
        foreach ($E in $ErrorsLocal) {
            Write-Warning -Message "Get-CimData - No data for computer $($Env:COMPUTERNAME). Failed with errror: $($E.Exception.Message)"
        }
    )
    $CimObject
}


function Get-PSService {
    <#
    .SYNOPSIS
    Alternative way to Get-Service

    .DESCRIPTION
    Alternative way to Get-Service which works using CIM queries

    .PARAMETER ComputerName
    ComputerName(s) to query for services

    .PARAMETER Protocol
    Protocol to use to gather services

    .PARAMETER Service
    Limit output to just few services

    .PARAMETER All
    Return all data without filtering

    .PARAMETER Extended
    Return more data

    .EXAMPLE
    Get-PSService -ComputerName AD1, AD2, AD3, AD4 -Service 'Dnscache', 'DNS', 'PeerDistSvc', 'WebClient', 'Netlogon'

    .EXAMPLE
    Get-PSService -ComputerName AD1, AD2 -Extended

    .EXAMPLE
    Get-PSService

    .EXAMPLE
    Get-PSService -Extended

    .NOTES
    General notes
    #>
    [cmdletBinding()]
    param(
        [alias('Computer', 'Computers')][string[]] $ComputerName = $Env:COMPUTERNAME,
        [ValidateSet('Default', 'Dcom', 'Wsman')][string] $Protocol = 'Default',
        [alias('Services')][string[]] $Service,
        [switch] $All,
        [switch] $Extended
    )
    [string] $Class = 'win32_service'
    [string] $Properties = '*'
    <# Disabled as per https://github.com/EvotecIT/PSSharedGoods/issues/14
    if ($All) {
        [string] $Properties = '*'
    } else {
        [string[]] $Properties = @(
            'Name'
            'Status'
            'ExitCode'
            'DesktopInteract'
            'ErrorControl'
            'PathName'
            'ServiceType'
            'StartMode'
            'Caption'
            'Description'
            #'InstallDate'
            'Started'
            'SystemName'
            'AcceptPause'
            'AcceptStop'
            'DisplayName'
            'ServiceSpecificExitCode'
            'StartName'
            'State'
            'TagId'
            'CheckPoint'
            'DelayedAutoStart'
            'ProcessId'
            'WaitHint'
            'PSComputerName'
        )
    }
    #>
    # instead of looping multiple times we create cache for services
    if ($Service) {
        $CachedServices = @{}
        foreach ($S in $Service) {
            $CachedServices[$S] = $true
        }
    }
    $Information = Get-CimData -ComputerName $ComputerName -Protocol $Protocol -Class $Class -Properties $Properties
    if ($All) {
        if ($Service) {
            foreach ($Entry in $Information) {
                if ($CachedServices[$Entry.Name]) {
                    $Entry
                }
            }
        } else {
            $Information
        }
    } else {
        foreach ($Data in $Information) {
            # # Remember to expand if changing properties above
            if ($Service) {
                if (-not $CachedServices[$Data.Name]) {
                    continue
                }
            }
            $OutputService = [ordered] @{
                ComputerName = if ($Data.PSComputerName) { $Data.PSComputerName } else { $Env:COMPUTERNAME }
                Status       = $Data.State
                Name         = $Data.Name
                ServiceType  = $Data.ServiceType
                StartType    = $Data.StartMode
                DisplayName  = $Data.DisplayName
            }
            if ($Extended) {
                $OutputServiceExtended = [ordered] @{
                    StatusOther             = $Data.Status
                    ExitCode                = $Data.ExitCode
                    DesktopInteract         = $Data.DesktopInteract
                    ErrorControl            = $Data.ErrorControl
                    PathName                = $Data.PathName
                    Caption                 = $Data.Caption
                    Description             = $Data.Description
                    #InstallDate             = $Data.InstallDate
                    Started                 = $Data.Started
                    SystemName              = $Data.SystemName
                    AcceptPause             = $Data.AcceptPause
                    AcceptStop              = $Data.AcceptStop
                    ServiceSpecificExitCode = $Data.ServiceSpecificExitCode
                    StartName               = $Data.StartName
                    #State                   = $Data.State
                    TagId                   = $Data.TagId
                    CheckPoint              = $Data.CheckPoint
                    DelayedAutoStart        = $Data.DelayedAutoStart
                    ProcessId               = $Data.ProcessId
                    WaitHint                = $Data.WaitHint
                }
                [PSCustomObject] ($OutputService + $OutputServiceExtended)
            } else {
                [PSCustomObject] $OutputService
            }
        }

    }
}
function Set-RegistryRemote {
    [cmdletbinding()]
    param(
        [string[]]$Computer,
        [string] $RegistryPath,
        [string[]]$RegistryKey,
        [string[]]$Value,
        [parameter(Mandatory = $False)][Switch]$PassThru
    )

    $ScriptBlock = {
        #[cmdletbinding()]
        param(
            [string] $RegistryPath,
            [string[]] $RegistryKey,
            [string[]] $Value,
            [bool]$PassThru
        )
        $VerbosePreference = $Using:VerbosePreference
        $List = New-Object System.Collections.ArrayList

        for ($i = 0; $i -lt $RegistryKey.Count; $i++) {
            Write-Verbose "REG WRITE: $RegistryPath REGKEY: $($RegistryKey[$i]) REGVALUE: $($Value[$i])" # PassThru: $PassThru"
            $Setting = Set-ItemProperty -Path $RegistryPath -Name $RegistryKey[$i] -Value $Value[$i] -PassThru:$PassThru
            if ($PassThru -eq $true) { $List.Add($Setting) > $null }
        }
        return $List
    }

    $ListComputers = New-Object System.Collections.ArrayList
    foreach ($Comp in $Computer) {
        $Return = Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock -ArgumentList $RegistryPath, $RegistryKey, $Value, $PassThru
        if ($PassThru -eq $true) { $ListComputers.Add($Return) > $null }
    }
    return $ListComputers
}

function Get-RegistryRemoteList {
    param(
        [string[]]$Computer = $Env:COMPUTERNAME,
        [string]$RegistryPath
    )
    $ScriptBlock = {
        [cmdletbinding()]
        param(
            [string]$RegistryPath
        )
        $VerbosePreference = $Using:VerbosePreference
        $Setting = Get-ItemProperty -Path $RegistryPath
        return $Setting
    }

    $ListComputers = New-Object System.Collections.ArrayList
    foreach ($Comp in $Computer) {
        $Return = Invoke-Command -ComputerName $Comp -ScriptBlock $ScriptBlock -ArgumentList $RegistryPath
        $ListComputers.Add($Return)  > $null
    }
    return $ListComputers
}

function Get-RegistryRemote {
    [cmdletbinding()]
    param(
        [string[]]$Computer = $Env:COMPUTERNAME,
        [string]$RegistryPath,
        [string[]]$RegistryKey
    )


    $ScriptBlock = {
        [cmdletbinding()]
        param(
            [string]$RegistryPath,
            [string[]]$RegistryKey
        )
        $VerbosePreference = $Using:VerbosePreference
        $List = New-Object System.Collections.ArrayList

        #Write-Verbose "REG READ: $RegistryPath REGKEY: $($RegistryKey)"

        for ($i = 0; $i -lt $RegistryKey.Count; $i++) {
            $RegKey = $RegistryKey[$i]
            $Setting = Get-ItemProperty -Path $RegistryPath -Name $RegKey
            Write-Verbose "REG READ: $RegistryPath REGKEY: $RegKey REG VALUE: $($Setting.$RegKey)"
            $List.Add($Setting.$RegKey)  > $null
        }
        return $List
    }
    $ListComputers = New-Object System.Collections.ArrayList
    foreach ($Comp in $Computer) {
        $Return = Invoke-Command -ComputerName $Comp -ScriptBlock $ScriptBlock -ArgumentList $RegistryPath, $RegistryKey
        $ListComputers.Add($Return)  > $null
    }
    return $ListComputers
}

function Get-ObjectCount($Object) {
    return $($Object | Measure-Object).Count
}

function New-Runspace {
    param (
        [int] $minRunspaces = 1,
        [int] $maxRunspaces = [int]$env:NUMBER_OF_PROCESSORS + 1
    )
    $RunspacePool = [RunspaceFactory]::CreateRunspacePool($minRunspaces, $maxRunspaces)
    $RunspacePool.ApartmentState = "MTA"
    $RunspacePool.Open()
    return $RunspacePool
}
function Start-Runspace {
    param (
        $ScriptBlock,
        [hashtable] $Parameters,
        [System.Management.Automation.Runspaces.RunspacePool] $RunspacePool
    )
    $runspace = [PowerShell]::Create()
    $null = $runspace.AddScript($ScriptBlock)
    $null = $runspace.AddParameters($Parameters)
    $runspace.RunspacePool = $RunspacePool
    return [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke() }
}

function Stop-Runspace {
    param(
        $Runspaces,
        [string] $FunctionName,
        [System.Management.Automation.Runspaces.RunspacePool] $RunspacePool
    )
    $List = @()
    while ($Runspaces.Status -ne $null) {
        $completed = $runspaces | Where-Object { $_.Status.IsCompleted -eq $true }
        foreach ($runspace in $completed) {
            foreach ($e in $($runspace.Pipe.Streams.Error)) {
                Write-Verbose "$FunctionName - Error from runspace: $e"
            }
            foreach ($v in $($runspace.Pipe.Streams.Verbose)) {
                Write-Verbose "$FunctionName - Verbose from runspace: $v"
            }
            $List += $runspace.Pipe.EndInvoke($runspace.Status)
            $runspace.Status = $null
        }
    }
    $RunspacePool.Close()
    $RunspacePool.Dispose()
    return $List
}
function Get-PulsewayMonitoredServices {
    [cmdletbinding()]
    param(
        [string] $Computer = $Env:COMPUTERNAME
    )
    $RegistryPath = 'HKLM:\SOFTWARE\MMSOFT Design\PC Monitor'
    $RegistryKey1 = 'SendNotificationOnServiceStop'
    $RegistryKey2 = 'PrioritySendNotificationOnServiceStop'
    
    $RegistryPathSub1 = 'HKLM:\SOFTWARE\MMSOFT Design\PC Monitor\Services'
    $RegistryKeySub1 = 'Count'
    
    $RegistryPathSub2 = 'HKLM:\SOFTWARE\MMSOFT Design\PC Monitor\ServicesExcludedFromNotifications'
    $RegistryKeySub2 = 'Count'
    
    $ReadRegistry = Get-RegistryRemote -Computer $Computer -RegistryPath $RegistryPath -RegistryKey $RegistryKey1, $RegistryKey2
    $NotificationEnabled = $ReadRegistry[0]
    $NotificationType = $ReadRegistry[1]
    
    $ReadRegistrySub1 = Get-RegistryRemote -Computer $Computer -RegistryPath $RegistryPathSub1 -RegistryKey $RegistryKeySub1
    $ServicesCount = $ReadRegistrySub1
    
    $ReadRegistrySub2 = Get-RegistryRemote -Computer $Computer -RegistryPath $RegistryPathSub2 -RegistryKey $RegistryKeySub2
    $ServicesExcludedCount = $ReadRegistrySub2
    
    $ListControlled = New-Object System.Collections.ArrayList
    
    $Services = Get-RegistryRemoteList -Computer $Computer -RegistryPath $RegistryPathSub1
    for ($i = 0; $i -lt $Services.Count; $i++) {
        $Service = "Service$i"
        $ListControlled.Add($Services.$Service)  > $null
    }
    
    $ListExcluded = New-Object System.Collections.ArrayList
    $Services = Get-RegistryRemoteList -Computer $Computer -RegistryPath $RegistryPathSub2
    for ($i = 0; $i -lt $Services.Count; $i++) {
        $Service = "Service$i"
        $ListExcluded.Add($Services.$Service)  > $null
    }
    
    $ListMonitored = Compare-Object -ReferenceObject $ListControlled -DifferenceObject $ListExcluded -PassThru
    
    $Return = [ordered] @{
        Name                    = 'Services'
        ComputerName            = $Computer
        CountServicesControlled = $ServicesCount
        CountServicesExcluded   = $ServicesExcludedCount
        CountServicesMonitored  = $ListMonitored.Count
        NotificationType        = $NotificationType -As [NotificationType]
        NotificationEnabled     = $NotificationEnabled -As [NotificationStatus]
        ServicesControled       = $ListControlled
        ServicesExcluded        = $ListExcluded
        ServicesMonitored       = $ListMonitored
    }
    return $Return
}
    
function Set-PulsewayMonitoredServices {
    [cmdletbinding()]
    param(
        [string] $Computer = $Env:COMPUTERNAME,
        [array] $Services,
        [array] $ServicesToMonitor,
        [NotificationStatus] $SendNotificationOnServiceStop,
        [NotificationType] $PrioritySendNotificationOnServiceStop,
        [parameter(Mandatory = $False)][Switch]$PassThru
    )
    Write-Verbose 'Set-PulsewayMonitoredServices - GetType: '
    
    $RegistryPath = 'HKLM:\SOFTWARE\MMSOFT Design\PC Monitor'
    $RegistryKey1 = 'SendNotificationOnServiceStop'
    $RegistryKey2 = 'PrioritySendNotificationOnServiceStop'
    
    $RegistryPathSub1 = 'HKLM:\SOFTWARE\MMSOFT Design\PC Monitor\Services'
    $RegistryKeySub1 = 'Count'
    
    $RegistryPathSub2 = 'HKLM:\SOFTWARE\MMSOFT Design\PC Monitor\ServicesExcludedFromNotifications'
    $RegistryKeySub2 = 'Count'
    
    $Count = Get-ObjectCount $Services
    
    $ServicesExcluded = Compare-Object -ReferenceObject $Services -DifferenceObject $ServicesToMonitor -PassThru
    $CountExcluded = Get-ObjectCount $ServicesExcluded
    
    # Enable/disable notification
    Set-RegistryRemote -Computer $Computer -RegistryPath $RegistryPath `
        -RegistryKey $RegistryKey1, $RegistryKey2 `
        -Value ($SendNotificationOnServiceStop -As [int]), ($PrioritySendNotificationOnServiceStop -As [Int]) `
        -PassThru:$PassThru
    
    # Count number of services
    Set-RegistryRemote -Computer $Computer -RegistryPath $RegistryPathSub1 `
        -RegistryKey $RegistryKeySub1 `
        -Value $Count -PassThru:$PassThru
    # Count number of services excluded
    Set-RegistryRemote -Computer $Computer -RegistryPath $RegistryPathSub2 `
        -RegistryKey $RegistryKeySub2 `
        -Value $CountExcluded -PassThru:$PassThru
    
    $ListServicesNameA = @()
    for ($i = 0; $i -le $Services.Count; $i++) {
        $ListServicesNameA += "Service$i"
    }
    $ListServicesNameB = @()
    for ($i = 0; $i -le $ServicesExcluded.Count; $i++) {
        $ListServicesNameB += "Service$i"
    }
    
    Set-RegistryRemote -Computer $Computer -RegistryPath $RegistryPathSub1 `
        -RegistryKey $ListServicesNameA `
        -Value $Services `
        -PassThru:$PassThru
    
    Set-RegistryRemote -Computer $Computer -RegistryPath $RegistryPathSub2 `
        -RegistryKey $ListServicesNameB `
        -Value $ServicesExcluded `
        -PassThru:$PassThru
    
}
function Write-Color {
    <#
	.SYNOPSIS
        Write-Color is a wrapper around Write-Host.

        It provides:
        - Easy manipulation of colors,
        - Logging output to file (log)
        - Nice formatting options out of the box.

	.DESCRIPTION
        Author: przemyslaw.klys at evotec.pl
        Project website: https://evotec.xyz/hub/scripts/write-color-ps1/
        Project support: https://github.com/EvotecIT/PSWriteColor

        Original idea: Josh (https://stackoverflow.com/users/81769/josh)

	.EXAMPLE
    Write-Color -Text "Red ", "Green ", "Yellow " -Color Red,Green,Yellow

    .EXAMPLE
	Write-Color -Text "This is text in Green ",
					"followed by red ",
					"and then we have Magenta... ",
					"isn't it fun? ",
					"Here goes DarkCyan" -Color Green,Red,Magenta,White,DarkCyan

    .EXAMPLE
	Write-Color -Text "This is text in Green ",
					"followed by red ",
					"and then we have Magenta... ",
					"isn't it fun? ",
                    "Here goes DarkCyan" -Color Green,Red,Magenta,White,DarkCyan -StartTab 3 -LinesBefore 1 -LinesAfter 1

    .EXAMPLE
	Write-Color "1. ", "Option 1" -Color Yellow, Green
	Write-Color "2. ", "Option 2" -Color Yellow, Green
	Write-Color "3. ", "Option 3" -Color Yellow, Green
	Write-Color "4. ", "Option 4" -Color Yellow, Green
	Write-Color "9. ", "Press 9 to exit" -Color Yellow, Gray -LinesBefore 1

    .EXAMPLE
	Write-Color -LinesBefore 2 -Text "This little ","message is ", "written to log ", "file as well." `
				-Color Yellow, White, Green, Red, Red -LogFile "C:\testing.txt" -TimeFormat "yyyy-MM-dd HH:mm:ss"
	Write-Color -Text "This can get ","handy if ", "want to display things, and log actions to file ", "at the same time." `
				-Color Yellow, White, Green, Red, Red -LogFile "C:\testing.txt"

    .EXAMPLE
    # Added in 0.5
    Write-Color -T "My text", " is ", "all colorful" -C Yellow, Red, Green -B Green, Green, Yellow
    wc -t "my text" -c yellow -b green
    wc -text "my text" -c red

    .NOTES
        Additional Notes:
        - TimeFormat https://msdn.microsoft.com/en-us/library/8kb3ddd4.aspx
    #>
    [alias('Write-Colour')]
    [CmdletBinding()]
    param (
        [alias ('T')] [String[]]$Text,
        [alias ('C', 'ForegroundColor', 'FGC')] [ConsoleColor[]]$Color = [ConsoleColor]::White,
        [alias ('B', 'BGC')] [ConsoleColor[]]$BackGroundColor = $null,
        [alias ('Indent')][int] $StartTab = 0,
        [int] $LinesBefore = 0,
        [int] $LinesAfter = 0,
        [int] $StartSpaces = 0,
        [alias ('L')] [string] $LogFile = '',
        [Alias('DateFormat', 'TimeFormat')][string] $DateTimeFormat = 'yyyy-MM-dd HH:mm:ss',
        [alias ('LogTimeStamp')][bool] $LogTime = $true,
        [int] $LogRetry = 2,
        [ValidateSet('unknown', 'string', 'unicode', 'bigendianunicode', 'utf8', 'utf7', 'utf32', 'ascii', 'default', 'oem')][string]$Encoding = 'Unicode',
        [switch] $ShowTime,
        [switch] $NoNewLine
    )
    $DefaultColor = $Color[0]
    if ($null -ne $BackGroundColor -and $BackGroundColor.Count -ne $Color.Count) {
        Write-Error "Colors, BackGroundColors parameters count doesn't match. Terminated."
        return
    }
    #if ($Text.Count -eq 0) { return }
    if ($LinesBefore -ne 0) { for ($i = 0; $i -lt $LinesBefore; $i++) { Write-Host -Object "`n" -NoNewline } } # Add empty line before
    if ($StartTab -ne 0) { for ($i = 0; $i -lt $StartTab; $i++) { Write-Host -Object "`t" -NoNewline } }  # Add TABS before text
    if ($StartSpaces -ne 0) { for ($i = 0; $i -lt $StartSpaces; $i++) { Write-Host -Object ' ' -NoNewline } }  # Add SPACES before text
    if ($ShowTime) { Write-Host -Object "[$([datetime]::Now.ToString($DateTimeFormat))] " -NoNewline } # Add Time before output
    if ($Text.Count -ne 0) {
        if ($Color.Count -ge $Text.Count) {
            # the real deal coloring
            if ($null -eq $BackGroundColor) {
                for ($i = 0; $i -lt $Text.Length; $i++) { Write-Host -Object $Text[$i] -ForegroundColor $Color[$i] -NoNewline }
            } else {
                for ($i = 0; $i -lt $Text.Length; $i++) { Write-Host -Object $Text[$i] -ForegroundColor $Color[$i] -BackgroundColor $BackGroundColor[$i] -NoNewline }
            }
        } else {
            if ($null -eq $BackGroundColor) {
                for ($i = 0; $i -lt $Color.Length ; $i++) { Write-Host -Object $Text[$i] -ForegroundColor $Color[$i] -NoNewline }
                for ($i = $Color.Length; $i -lt $Text.Length; $i++) { Write-Host -Object $Text[$i] -ForegroundColor $DefaultColor -NoNewline }
            } else {
                for ($i = 0; $i -lt $Color.Length ; $i++) { Write-Host -Object $Text[$i] -ForegroundColor $Color[$i] -BackgroundColor $BackGroundColor[$i] -NoNewline }
                for ($i = $Color.Length; $i -lt $Text.Length; $i++) { Write-Host -Object $Text[$i] -ForegroundColor $DefaultColor -BackgroundColor $BackGroundColor[0] -NoNewline }
            }
        }
    }
    if ($NoNewLine -eq $true) { Write-Host -NoNewline } else { Write-Host } # Support for no new line
    if ($LinesAfter -ne 0) { for ($i = 0; $i -lt $LinesAfter; $i++) { Write-Host -Object "`n" -NoNewline } }  # Add empty line after
    if ($Text.Count -and $LogFile) {
        # Save to file
        $TextToFile = ""
        for ($i = 0; $i -lt $Text.Length; $i++) {
            $TextToFile += $Text[$i]
        }
        $Saved = $false
        $Retry = 0
        Do {
            $Retry++
            try {
                if ($LogTime) {
                    "[$([datetime]::Now.ToString($DateTimeFormat))] $TextToFile" | Out-File -FilePath $LogFile -Encoding $Encoding -Append -ErrorAction Stop -WhatIf:$false
                } else {
                    "$TextToFile" | Out-File -FilePath $LogFile -Encoding $Encoding -Append -ErrorAction Stop -WhatIf:$false
                }
                $Saved = $true
            } catch {
                if ($Saved -eq $false -and $Retry -eq $LogRetry) {
                    $PSCmdlet.WriteError($_)
                } else {
                    Write-Warning "Write-Color - Couldn't write to log file $($_.Exception.Message). Retrying... ($Retry/$LogRetry)"
                }
            }
        } Until ($Saved -eq $true -or $Retry -ge $LogRetry)
    }
}
	
$ServiceControlOnly = $ServicesOverall + $ServicesSQLControl + $ServicesMonitoring + $ServiceMonitor | Sort-Object -Unique

$Services = $Servers | foreach { Get-PSService -Computers $_ -Services 'PC Monitor' }
$PulsewayUnavailable = $Services | Where { $_.Status -eq 'N/A' }
$PulsewayRunning = $Services | Where { $_.Status -eq 'Running' }

Write-Color 'Servers to process: ', $Servers.Count, ' servers running: ', $PulsewayRunning.Count, ' servers unavailable: ', $PulsewayUnavailable.Count  -Color White, Yellow, White, Yellow, White, Yellow
Write-Color 'Pulseway is running: ', ($PulsewayRunning.ComputerName).count -Color White, Green
#$PulsewayRunning | Format-Table -AutoSize
Write-Color 'Pulseway is unavailable: ', $PulsewayUnavailable.Count -Color White, Red
#$PulsewayUnavailable | Format-Table -AutoSize

$ServerServicesAll = Get-PSService -Computers $PulsewayRunning.ComputerName

foreach ($server in $PulsewayRunning.ComputerName) {
    Write-Color '[start]', ' Processing server: ', $Server, ' for ', 'Services' -Color Green, White, Yellow, White, Yellow

    $ServicesToProcessAll = $ServerServicesAll 
    $ServicesToProcessRunning = $ServerServicesAll | Where { $_.Status -eq 'Running' -and $_.StartType -eq 'Auto' }
	
    $Green = foreach ($service in $ServicesToProcessAll.name) {
        foreach ($service2 in $ServiceControlOnly) {
            if ($service -like $service2) {
                Write-Output $service
            }
        }
    }

    $Yellow = foreach ($service in $ServicesToProcessRunning.name) {
        foreach ($service2 in $ServiceMonitor) {
            if ($service -like $service2) {
                Write-Output $service
            }
        }
    }

    Write-Color '[**]', ' Enabling those services for control ', ([string] $Green) -Color Yellow, White, Green
    Write-Color '[**]', ' Enabling those services for monitoring ', ([string] $Yellow) -Color Yellow, White, Yellow
    Set-PulsewayMonitoredServices -Computer $Server -Services $Green -ServicesToMonitor $Yellow -SendNotificationOnServiceStop Enabled -PrioritySendNotificationOnServiceStop Critical #-Verbose

}