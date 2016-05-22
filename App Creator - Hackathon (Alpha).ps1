<#
What will I need to get ahead of time?

1) Dp to distribute content to
    Verify: DP Exists
2) Share to 'monitor'
    Verify share exists
3) Hyper-V Server
    Verify server exists
4) Hyper-V VM Name
    Verify VM exists (this will also verify server is a Hyper-V server)
5) Test Computer Name (if not same as VM Name)
    Verify computer is on


Script flow:
1) Triggered by manual run (hackathon wanted full automation, but not practical)
2) Take initial snapshot of VM
3) Find new folder(s) in share
4) Create app
    -Content = folder path
    -Installer = script called install.ps1 or install.bat or install.cmd
    -Uninstaller = script called uninstall.whatev
    -Detection Method = script to make it always not detected
5) Distribute Content
6) Create collection
7) Put computer in collection
8) Deploy app as available
9) Get initial state of VM (log HKEY\Software & %ProgramFiles%)
9) Wait for content to distribute
10) Install app on VM
11) Get current state of VM and compare (find what changed in HKEY\Software and/or %ProgramFiles%)
12) Create detection method based off of what changed in 11
13) Revert VM
14) Wait for it to download new policy - Make sure app revision is > 1
15) Install and make sure successful!
16) Retroactively win hackathon!


#>

$Global:TestingScript = $true
Import-Module 'C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager\ConfigurationManager.psd1'
$DistributionPoint = 'Lab-CM.Home.Lab'
$ConfigMgrServer = 'Lab-CM'
$ConfigMgrSiteCode = 'PS1'
$Share = '\\Lab-CM\Sources'
$HyperVServer = 'Hyper-V'
$HyperVVMName = 'Lab-SQL'
$TestComputerName = 'Lab-SQL'
$Script:LogFile = "$PSScriptRoot\AutoAppCreator.log"
$ChangeDir = $ConfigMgrSiteCode + ":\"

Function Log {
    Param (
		[Parameter(Mandatory=$false)]
		$Message,
 
		[Parameter(Mandatory=$false)]
		$ErrorMessage,
 
		[Parameter(Mandatory=$false)]
		$Component,
 
		[Parameter(Mandatory=$false)]
		[int]$Type,
		
		[Parameter(Mandatory=$false)]
		$LogFile
	)
<#
Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
#>
	$Time = Get-Date -Format "HH:mm:ss.ffffff"
	$Date = Get-Date -Format "MM-dd-yyyy"
 
	if ($ErrorMessage -ne $null) {$Type = 3}
	if ($Component -eq $null) {$Component = " "}
	if ($Type -eq $null) {$Type = 1}
 
	$LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
	#$LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
    $Message = "$Message - $ErrorMessage"
    Write-Host $Message
}


#region Snapshot VM
    #Log -Message 'Creating snapshot...'
    #Invoke-Command -ComputerName $HyperVServer -ArgumentList $HyperVVMName -ScriptBlock {
    #    Checkpoint-VM -Name $args[0] -SnapshotName "CreateAppWithDetection-Original"
    #}
#endregion

$AppErrorCodes = 8,16,17,18,19,21,24,25, 4
$AppInProgressCodes = 0,3,5,6,7,10,11,12,15,20,22,23,26,27,28
$AppSuccessfulCodes = 1,2
$AppRestartCodes = 13,14,9

cd C:\

$AlreadyDoneList = Get-Content "$PSScriptRoot\Finished.txt" -ErrorAction SilentlyContinue

Get-ChildItem $Share | Where { $_.PSIsContainer } | ForEach-Object {
    $AlreadyDone = $false
    foreach($item in $AlreadyDoneList) {
        if($_.FullName -eq $item) {
            $AlreadyDone = $true
        }
    }
    if(!($AlreadyDone)) {
        $AppName = $_.Name
        $AppContent = $_.FullName
        Log -Message "Found app name: $AppName"
        $Installer = ''
        
        Get-ChildItem $AppContent | ForEach-Object { if($_.Name.ToLower().Contains('install.')) { $Installer = $_.Name } }
        Log -Message "Found install script: $Installer"
        cd $ChangeDir
        $TempAppObject = New-CMApplication -Name $AppName -Description "Created by the script!"
        Log -Message "Created application!"
        #$NewDeploymentTypeObject = Add-CMDeploymentType -InputObject $TempAppObject -ContentLocation $AppContent -DeploymentTypeName $AppName -InstallationBehaviorType InstallForSystem -ScriptInstaller -InstallationProgram $Installer -DetectDeploymentTypeByCustomScript -ScriptType PowerShell -ScriptContent 'return 0' -LogonRequirementType WhetherOrNotUserLoggedOn
        $NewDeploymentTypeObject = Add-CMScriptDeploymentType -DeploymentTypeName $AppName -ContentLocation $AppContent -ApplicationName $AppName -InstallCommand $Installer -LogonRequirementType WhetherOrNotUserLoggedOn -ScriptLanguage PowerShell -ScriptText '$null'
        Log -Message "Created deployment type!"
        Set-CMDeploymentType -ApplicationName $AppName -DeploymentTypeName $AppName -MsiOrScriptInstaller -InstallationBehaviorType InstallForSystem
        Log -Message "Changed deployment type to install for system!"
        $CollectionObject = New-CMCollection -CollectionType Device -LimitingCollectionName 'All Systems' -Name "Install - $AppName"
        Log -Message "Created collection!"
        Add-CMDeviceCollectionDirectMembershipRule -CollectionName "Install - $AppName" -Resource ( Get-CMDevice -Name $TestComputerName )
        Log -Message "Added test computer $TestComputerName to collection!"
        Start-CMContentDistribution -Application $TempAppObject -DistributionPointName $DistributionPoint
        Log -Message "Started distributing content to $DistributionPoint"
        Start-CMApplicationDeployment -Name $AppName -CollectionName "Install - $AppName" -DeployAction Install -DeployPurpose Available
        Log -Message "Started deployment of app to collection!"
        $InstallStartTime = Get-Date
        cd 'c:\'
        $breakLoop = $false
        Log -Message "Getting list of applications deployed to the computer"
        while ($breakLoop -ne $true) {
            
            $ApplicationObjects = Get-WmiObject -Query "select * from CCM_Application" -ComputerName $TestComputerName -Namespace root\ccm\clientsdk
            Foreach ($ApplicationObject in $ApplicationObjects) {
                if ($ApplicationObject.FullName -eq $AppName) {
                    Log -Message "Found application $AppName - Installing"
		            $WMIPath = "\\$TestComputerName\root\ccm\clientsdk:CCM_Application"
		            $WMIClass = [WMIClass] $WMIPath
                    $ApplicationID = ""
                    $ApplicationRevision = ""
                    $IsMachineTarget = ""
				    $ApplicationRevision = $ApplicationObject.Revision
				    $IsMachineTarget = $ApplicationObject.IsMachineTarget
				    $EnforcePreference = $ApplicationObject.EnforcePreference
				    $ApplicationID = $ApplicationObject.ID
		            $WMIClass.Install($ApplicationID, $ApplicationRevision, $IsMachineTarget, "", "1", $false) | Out-null
                    $BreakThisLoop = $false
                    Log "Waiting for application to install"
                    while ($BreakThisLoop -ne $true) {
                        $AppObjs = Get-WmiObject -Query "select * from CCM_Application" -ComputerName $TestComputerName -Namespace root\ccm\clientsdk
                        foreach ($AppObj in $AppObjs) {
                            if($AppObj.FullName -eq $AppName) { $EvaluationState = $AppObj.EvaluationState }
                        }
                        If ($AppErrorCodes -contains $EvaluationState) {
                            $BreakThisLoop = $true
                        }
                        elseif ($AppRestartCodes -contains $EvaluationState) {
                            $BreakThisLoop = $true
                        }
                        elseif ($AppSuccessfulCodes -contains $EvaluationState) {
                            $BreakThisLoop
                        }

                    }
                    Log "Checking for file changes in Program Files"
                    $ProgramFiles = Get-ChildItem "\\$TestComputerName\c$\Program Files"
                    $ModifiedFiles = @()
                    Foreach( $ProgramFile in $ProgramFiles) {
                        if($ProgramFile.LastWriteTime -gt $InstallStartTime) {
                            Log "Found modified folder! Setting detection method"
                            $Folder = $ProgramFile.FullName
                            $TestComputerName = $TestComputerName.ToLower()
                            $Folder = $Folder.ToLower().Replace("\\$TestComputerName\c$","c:")
                            cd $ChangeDir
                            Set-CMScriptDeploymentType -ApplicationName $AppName -DeploymentTypeName $AppName -ScriptText "If(Test-Path `"$Folder`") { return `"1`" }" -ScriptLanguage PowerShell 
                            Log "Detection method changed!"
                            cd 'c:\'
                        }
                    }
                    $breakLoop = $true
                }
            }
        }
        $_.FullName >> "$PSScriptRoot\Finished.txt"     
    }
}