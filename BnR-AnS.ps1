#Requires -Version 6
# Why Version 6? 
# ConvertFrom-Json is used with -AsHashtable. This switch was introduced in PowerShell 6.0
# Also required: robocopy

[CmdletBinding()]
param (
    # Path to the Directory where the files should be backed up to. 
    # Directory will be generated if it doesn't exist.
    [Parameter(Mandatory = $true)]
    [string]
    $Destination="c:\Users\kristenm\Backup",
    # Path where the logfiles have to go. Two logfiles are being generated, 1 for the script and 1 for robocopy.
    # Must not end with a \
    [Parameter(Mandatory = $true)]
    [string]
    $LogFilePath="c:\Users\kristenm\Backup",
    # Path to the Configfile (in JSON format)
    [Parameter(Mandatory = $true)]
    [string]
    $ConfigFile=".\config.json",
    # Backup or Restore
    [Parameter(Mandatory=$false)]
    [ValidateSet("Backup", "Restore")]
    [string]
    $Direction="Backup"
)

<#
Example Usage:

Backup: 
    .\Backup-Restore-Client.ps1 -Destination D:\Backup -LogFilePath D:\Backup -ConfigFile .\Config.json -Direction "Backup"
Restore:
    .\Backup-Restore-Client.ps1 -Destination D:\Backup -LogFilePath D:\Backup -ConfigFile .\Config.json -Direction "Restore"
    Note: -Destination changes it's function to source. Maybe the name will be renamed in future to better match it's function in both directions.
#>

#region FUNCTIONS
function Test-IsaIsRegistryHive {
    #returns $true if key is a hive, false if not 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $KeyName
    )
    try {
        $regKey = Get-Item -Path $KeyName -ErrorAction SilentlyContinue
    }
    catch {
        # I hate to have empty catchblock but all I need ist $null in $regkey or not
    }
    $null -ne $regKey
}
function Get-IsaRegistryKeyValue {
    [CmdletBinding()]
    param (
        # Registry Key Name
        [Parameter(Mandatory = $true)]
        [string]
        $KeyName,
        # Registry Key Value
        [Parameter(Mandatory = $true)]
        [string]
        $ValueName
    )
    $regKey = Get-Item -Path $KeyName
    $obj = [PSCustomObject]@{
        Key       = $KeyName
        ValueName = $ValueName
        ValueContent = $regkey.GetValue($ValueName)
        ValueType = ($regkey.GetValueKind($ValueName)).tostring()
    }
    $obj
    Write-PSFMessage -Level 3 -Message "Value=$($obj.ValueName), Content=$($obj.ValueContent), Type=$($obj.ValueType)"
}
function Set-IsaRegistryKeyValue {
    [CmdletBinding()]
    param (
        # Registry Key Name
        [Parameter(Mandatory = $true)]
        [string]
        $KeyName,
        # Registry Key Value
        [Parameter(Mandatory = $true)]
        [string]
        $ValueName,
        # Registry Key Value Value
        [Parameter(Mandatory=$true)]
        [string]
        $ValueContent,
        # Key Value Type
        [ValidateSet('String','DWord')]
        [string]
        $ValueType = 'String'
    )
    Write-PSFMessage -Level 3 -Message "Value=$($RegKeyValuePair.ValueName), Content=$($RegKeyValuePair.ValueContent), Type=$($RegKeyValuePair.ValueType)"
    Set-ItemProperty -Path $KeyName -Name $ValueName -Value $ValueContent -Type $ValueType
}
function Export-IsaRegistryKeyStore {
    [CmdletBinding()]
    param (
        # Hashtable containing all the registry keys to be backed up
        # Name : HiveName, Value ist eine HashTable mit KeyNamen+Value+Type
        [Parameter(Mandatory)]
        [hashtable] $RegistryList,
        # Directory to store the file
        [Parameter(Mandatory)]
        [string]
        $FolderPath
    )
    $Filename = "$FolderPath\RegistryKeys.json"
    if ( $RegistryList.Count -gt 0 ) {
        Write-PSFMessage -Level 3 "Export $($RegistryList.Count) registry keys to $FileName"
        $RegistryList |
            ConvertTo-Json |
            Out-File $Filename
    }
}
function Import-IsaRegistryKeyStore {
    [CmdletBinding()]
    param (
        # returns Hashtable containing all the registry keys to be backuped
        # Name : HiveName, Value ist eine HashTable mit KeyNamen+Value+Type
        [Parameter(Mandatory)]
        [string]
        $FolderPath
    )
    $Filename = "$FolderPath\RegistryKeys.json"
    if ( Test-Path -Path $Filename  ) {
        [hashtable] $hashRegKeys = Get-Content $Filename -Raw |
            ConvertFrom-Json -AsHashtable
        $hashRegKeys 
        Write-PSFMessage -Level 3 "Imported $($hashRegKeys.Count) registry keys from $FileName"
    }
}
#endregion

#region CHECK PREs
#Check Destination Folder
If (-not(Test-Path -PathType Container -Path $Destination)) {
    Write-PSFMessage -Level 3 -Message "$Destination does not exits. I'll create it for you."
    New-Item -ItemType Directory -Force -Path $Destination
}
If (-not(Test-Path -PathType Leaf -Path $ConfigFile)) {
    Write-PSFMessage -Level Error -Message "$ConfigFile not found. Cannot continue without config."
    Exit
}
#endregion

#region CHECK MODs
#Install PS-Framework (neede for logging)
Install-Module -Name PSFramework -MinimumVersion 1.4.149

#Install Choco when in Restore Mode (we don't need choco in Backup Mode)
if($Direction -eq "Restore") {
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}
#endregion

#region LOG STUFF
#Prepare Logfiles
$Datum = get-date -Format "yyyy.MM.dd"
$LogFileRoboCopy = "$LogFilePath\$Datum-Backup-Robocopy.log"
$LogFile = "$LogFilePath\$Datum-Backup.log"

#Start Logging
Set-PSFLoggingProvider -Name logfile -Enabled $true -FilePath $LogFile
Write-PSFMessage -Level 3 -Message "Starting..."
Write-PSFMessage -Level 3 -Message "Direction: $Direction"
#endregion

#Load json config file
Write-PSFMessage -Level 3 -Message "Reading JSON File: $ConfigFile"
$AppSettings = Get-Content -Path $ConfigFile | ConvertFrom-Json -AsHashtable

# init store for registry key values
$RegistryKeyStore = @{}                     # Hashtable um alle keys eines Durchlaufs zu speichern
if ( $Direction -eq "Restore" ) {
    $RegistryKeyStore = Import-IsaRegistryKeyStore -FolderPath $Destination
}
#loop through all entries
ForEach ($AppSetting in $AppSettings.Keys) {
    Write-PSFMessage -Level 3 -Message "========================================================="
    Write-PSFMessage -Level 3 -Message "Working on: $($AppSetting.ToUpper())"
    $AppDestination = "$Destination\$AppSetting"
    $a = 0

    ForEach ($Setting in $AppSettings.$AppSetting) {
        Write-PSFMessage -Level 3 -Message "---------------------------------------------------------"
        #Expand Environmentvariables 
        $Setting = $ExecutionContext.InvokeCommand.ExpandString($Setting)
        switch -Regex ($Setting) {
            '(^[a-zA-Z]:\\)' {        # Starts with Driveletter
                #region FILE-SYS BACKUP 
                if ($Direction -eq "Backup") {
                    If ((Get-Item -Path $Setting) -is [System.IO.DirectoryInfo]) {
                        # TRUE IF DIRECTRORY, false if file
                        Write-PSFMessage -Level 3 -Message "Backing up (Dir) Src: $Setting"
                        Write-PSFMessage -Level 3 -Message "Backing up (Dir) Des: $AppDestination"
                        Robocopy.exe $Setting $AppDestination /E /LOG+:$LogFileRoboCopy | Out-Null
                    }
                    else {
                        # true if directrory, FALSE IF FILE
                        $ParentFolder = Split-Path -Path $Setting -Parent
                        $File = Split-Path $Setting -Leaf
                        Write-PSFMessage -Level 3 -Message "Backing up (Fil) Src: $Setting"
                        Write-PSFMessage -Level 3 -Message "Backing up (Fil) ParentFolder: $ParentFolder"
                        Write-PSFMessage -Level 3 -Message "Backing up (Fil) Des: $AppDestination"
                        Write-PSFMessage -Level 3 -Message "Backing up (Fil) File: $File"
                        Robocopy.exe $ParentFolder $AppDestination $File /LOG+:$LogFileRoboCopy | Out-Null
                    }
                }
                #endregion
                #region FILE-SYS RESTORE 
                elseif ($Direction -eq "Restore") {
                    $File = Split-Path $Setting -Leaf
                    If ((Get-Item -Path "$AppDestination") -is [System.IO.DirectoryInfo]) {
                        # TRUE IF DIRECTRORY, false if file
                        Write-PSFMessage -Level 3 -Message "Restoring (Dir) Src: $AppDestination"
                        Write-PSFMessage -Level 3 -Message "Restoring (Dir) Des: $Setting"
                        Robocopy.exe $AppDestination $Setting /E /LOG+:$LogFileRoboCopy | Out-Null
                    }
                    else {
                        # true if directrory, FALSE IF FILE
                        $ParentFolder = Split-Path -Path $Setting -Parent
                        $File = Split-Path $Setting -Leaf
                        Write-PSFMessage -Level 3 -Message "Restoring (Fil) Src: $AppDestination"
                        Write-PSFMessage -Level 3 -Message "Restoring (Fil) Des: $Setting"
                        Robocopy.exe $AppDestination $ParentFolder $File /LOG+:$LogFileRoboCopy | Out-Null
                    }
                }
                #endregion
            }
            '^HKEY' {
                #region REG-SYS BACKUP 
                if ($Direction -eq "Backup") {
                    $a++
                    Write-PSFMessage -Level 3 -Message "Backing up (Reg) New Folder to create: $AppDestination"
                    New-Item -Path $AppDestination -ItemType Directory -Force | Out-Null
                    Write-PSFMessage -Level 3 -Message "Backing up (Reg) Src: $Setting"
                    Write-PSFMessage -Level 3 -Message "Backing up (Reg) Des: $AppDestination\$a.reg"
                    reg.exe export $Setting "$AppDestination\$a.reg" /y | Out-Null
                }
                #endregion
                #region REG-SYS RESTORE 
                elseif ($Direction -eq "Restore") {
                    Get-ChildItem $AppDestination -Filter *.reg | 
                    Foreach-Object {
                        Write-PSFMessage -Level 3 -Message "Restore (Reg) Src: $($_.FullName)"
                        reg.exe import $_.FullName | Out-Null
                    }   
                }
                #endregion
            }
            '^choco' {
                #region INSTALL SOFTWARE
                if ($Direction -eq "Restore") {
                    Write-PSFMessage -Level 3 -Message "Installing: $($Setting.Replace('choco:',''))"
                    choco install $Setting.Replace("choco:", "") -y
                }
                #endregion
            }
            '^https:' {
                #region BROWSE TO SOFTWARE DOWNLOAD (in caes there's no choco package for it)
                if ($Direction -eq "Restore") {
                    Write-PSFMessage -Level 3 -Message "Browsing to: $($Setting)"
                    Start-Process -Path $Setting
                }
                #endregion
            }
            '^HKCU:' {
                #region HANDLE JUST ONE REGISTRY KEY
                Write-PSFMessage -Level 3 -Message "Handle single registry value: $($Setting)"
                if ( Test-IsaIsRegistryHive -KeyName $Setting ) {
                    # handling registry hive using reg.exe
                    $SettingRegExe = $Setting -replace 'HKCU:','HKCU'
                    if ($Direction -eq "Backup") {
                        $a++
                        Write-PSFMessage -Level 3 -Message "Backing up (Reg) New Folder to create: $AppDestination"
                        New-Item -Path $AppDestination -ItemType Directory -Force | Out-Null
                        Write-PSFMessage -Level 3 -Message "Backing up (Reg) Src: $SettingRegExe"
                        Write-PSFMessage -Level 3 -Message "Backing up (Reg) Des: $AppDestination\$a.reg"
                        reg.exe export $SettingRegExe "$AppDestination\$a.reg" /y | Out-Null
                    }
                    #endregion
                    #region REG-SYS RESTORE 
                    elseif ($Direction -eq "Restore") {
                        Get-ChildItem $AppDestination -Filter *.reg | 
                        Foreach-Object {
                            Write-PSFMessage -Level 3 -Message "Restore (Reg) Src: $($_.FullName)"
                            reg.exe import $_.FullName | Out-Null
                        }   
                    }
                } else {
                    # handling singe registry cey attributes
                    $RegHive = Split-Path -Path $Setting -Parent
                    $RegValue = Split-Path -Path $Setting -Leaf
                    if ( Test-Path -Path $RegHive ) {           # Backup Restore, nur wenn es den Hive schon gibt!
                        if ( $Direction -eq "Restore" ) {
                            $RegKeyValuePair = $RegistryKeyStore.$RegHive.$RegValue
                            Set-IsaRegistryKeyValue -KeyName $RegHive -ValueName $RegKeyValuePair.ValueName -ValueContent $RegKeyValuePair.ValueContent -ValueType $RegKeyValuePair.ValueType
                        } else {
                            $RegKeyValuePair = Get-IsaRegistryKeyValue -KeyName $RegHive -ValueName $RegValue
                            if (!$RegistryKeyStore.ContainsKey($RegHive)) { $RegistryKeyStore.Add($RegHive, @{}) }
                            $RegistryKeyStore.$RegHive.Add($RegKeyValuePair.ValueName, $RegKeyValuePair)
                        }
                    }
                }
                #endregion
            }
        }

        }
    }
# Ev. gespeicherte Einzel Keys jetzt rauschreiben
if ( $Direction -eq 'Backup' -and $RegistryKeyStore.Count -gt 0 ) {
    Export-IsaRegistryKeyStore -RegistryList $RegistryKeyStore -FolderPath $Destination
}
