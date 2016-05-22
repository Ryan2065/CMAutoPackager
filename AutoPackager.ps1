Function Write-EphingLog {
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
    if ($ErrorMessage -ne $null) {
        $Message = "$Message - $ErrorMessage"
    }
    Write-Host $Message
}

Function Handle-EphingError {
    Param (
        $ErrorObject,
        $Message
    )
    Write-EphingLog -Message $Message -ErrorMessage $ErrorObject.Exception.Message
}

Function Install-EphingApplication {
    Param(
        $ComputerName,
        $ApplicationName
    )
    try {
        $ApplicationObject = Get-EphingClientApplication -ComputerName $ComputerName -ApplicationName $ApplicationName
        if($ApplicationObject -ne $null) {
            $WMIPath = "\\$ComputerName\root\ccm\clientsdk:CCM_Application"
            $WMIClass = [WMIClass] $WMIPath
            $ApplicationRevision = $ApplicationObject.Revision
            $IsMachineTarget = $ApplicationObject.IsMachineTarget
            $EnforcePreference = $ApplicationObject.EnforcePreference
            $ApplicationID = $ApplicationObject.ID
            $null = $WMIClass.Install($ApplicationID, $ApplicationRevision, $IsMachineTarget, "", "1", $false)
            return 'Installed'
        }
        else {
            return 'NotFound'
        }
    }
    catch {
        Handle-EphingError -ErrorObject $_ -Message 'Error installing application'
        return 'ErrorInstalling'
    }
}

Function Get-EphingClientApplication {
    Param(
        $ComputerName,
        $ApplicationName
    )
    try {
        $ApplicationObjects = Get-WmiObject -Namespace 'root\ccm\clientsdk' -ComputerName $ComputerName -Class 'CCM_Application'
        Foreach ( $ApplicationObject in $ApplicationObjects ) {
            if ($ApplicationObject.FullName -eq $ApplicationName) { 
                return $ApplicationObject
            }
        }
    }
    catch {
        Handle-EphingError -ErrorObject $_ -Message 'Error retrieving application object'
    }
}

Function Get-EphingOptions {
    
}