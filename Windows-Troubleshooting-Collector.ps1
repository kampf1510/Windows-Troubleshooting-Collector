#This script will run common checks on a Windows PC and output logs to a centralized folder for easy troubleshooting and diagnostics, the script must be ran as an administrator. 

#Establishes main variables and functions to be used throughout the script, feel free to change at your own risk. 

#Sets execution policy on local computer. 
Set-ExecutionPolicy Unrestricted 

#Parent directory which stores all logs. 
$file = 'C:\Troubleshooting Script Logs'

#Location of output log for further analysis.
$Log = 'C:\Troubleshooting Script Logs\Troubleshooting.log'

#Location of SFC output for further analysis. 
$SFCLog = "C:\Troubleshooting Script Logs\sfc.log"

#Location of DISM  output for further analysis. 
$DISMLOG = "C:\Troubleshooting Script Logs\dism.log"

#Location of output for event viewer for further analysis.
$EventView = 'C:\Troubleshooting Script Logs\EventViewer.log'

#Calculates time of script excecution to be used later. 
$time = get-date -Format T

#Default locations of DISM & SFC logs. 
$DISMDIR = 'C:\windows\logs\DISM\dism.log'
$SFCDIR = 'C:\windows\logs\cbs\CBS.log'

#Function used to write to the log directory, record error types, brief error descriptions and prompt the user if they would like to continue the script execution. 
Function Write-Log{
    Param ($errortype, $description, $fault, $loglocation)
    $to_write= $errortype+" "+$description
    Write-Output $to_write | Add-Content -Path $loglocation
    if ($fault -eq 'y')
        {
        Write-host 'Errors have been encountered and logged to the logfile located at:'
        Write-host $loglocation
        write-host "General description of errors is as follows:"
        Write-host $errortype 
        Write-host $description
        $choice = Read-Host -Prompt 'Do you want to continue with the script? (y/n)'
            if ($choice -eq 'n')
            {
            write-host "Breaking out of script"
            exit
            }

        }
}

#Clears the host's screen prior to any code execution.  
Clear-Host 

#Tests if the Troubleshooting Script Logs directory already exists, if it doesn't it will be created. 
if(Test-Path $file) {
    Write-Host "Troubleshooting Script Logs directory already exists, skipping..."} 

else {mkdir $file -Force | Out-Null
    Write-host "Troubleshooting Script Logs directory could not be found and was successfully created... "-ForegroundColor Green }

#Tests if the main log file exists, if it doesn't it will be created. 
if(Test-Path $log) {
    Write-Host "Troubleshooting Log file already exists, skipping..."} 

else {new-item -force -path $Log -type file | Out-Null
    Write-Host "Troubleshooting Script Logs file could not be found and was successfully created..." -ForegroundColor Green}

#Adds the of the script running to the log file. 
Write-Output "Script Time: $time" | Out-File $Log 

#Gets generic computer info and appends it to the log file.
Write-Output "`n" | Out-File $Log -Append
write-log "Computer Info:" "Grabbing computer info..." 'n' $Log
Get-ComputerInfo | Select-Object OsArchitecture,WindowsProductName,WindowsCurrentVersion,OSDisplayVersion, BiosFirmwareType,BiosVersion,CsNumberOfLogicalProcessors,CsProcessors,OsTotalVisibleMemorySize,CsPowerSupplyState,CsThermalState | Format-Table -AutoSize | out-file $Log -Append 

#Tests connection to Google to validate the network / DNS. 
write-log "Network/DNS:" "Testing connection to Google to validate the Network/DNS..." 'n' $Log
Test-NetConnection 'Google.com'  -InformationLevel "Detailed" | Format-Table -AutoSize | out-file $Log -Append 

#Runs a DISM check then appends the result to the log file for further analysis. 
write-log "DISM:" "Starting DISM Scan..." 'n' $Log
Start-Process -FilePath dism.exe -ArgumentList '/Online', '/Cleanup-Image', '/ScanHealth' -Wait -ErrorAction Inquire
Start-Process -FilePath dism.exe -ArgumentList '/Online', '/Cleanup-Image', '/Restorehealth' -Wait -ErrorAction Inquire

#Grabs output of the DISM scan then pipes it to a newly created log file called dism.log. 
write-log "DISM:" "DISM Scan was successful, grabbing DISM Logs for further analysis..." 'n' $Log
get-content -path $DISMDIR | set-content $DISMLOG -ErrorAction SilentlyContinue

#Sifts through DISM results then writes results to the log.
$DISMResult = Select-String -Path $DISMLog -Pattern 'corrupt','failed' 

if($DISMResult -like "*") 
{ 
    write-log "DISM:" "DISM found errors, please reference the DISM.log" 'n' $Log
} 

else 
{
    write-log "DISM:" "DISM found no corrupted components." 'n' $Log
}

#Starts SFC then appends the results to the log file for further analysis. 
Write-Output "`n" | Out-File $Log -Append
write-log "SFC:" "Starting SFC Scan..." 'n' $Log
Start-Process -FilePath "C:\Windows\System32\sfc.exe" -ArgumentList '/scannow' -Wait -ErrorAction Inquire

#Grabs output of the SFC scan then pipes it to a newly created sfc file called SFC.log. 
write-log "SFC:" "SFC Scan was successful, grabbing SFC Logs for further analysis..." 'n' $Log
get-content -path $SFCDIR | Set-Content $SFCLog -ErrorAction SilentlyContinue

#Sifts through SFC results then writes results to the log. 
$SFCResult = Select-String -Path $SFCLOG -Pattern 'corrupted file','repairing corrupted file','repaired file','cannot repair member file'

if($SFCResult -like "*") 
{ 
    write-log "SFC:" "SFC found errors, please reference the SFC.log" 'n' $Log
} 

else 
{
    write-log "SFC:" "SFC found no corrupted components." 'n' $Log
}

#Sifts through Event Viewer for events that are critical and error type in the application & system logs in the last 7 days. 
Write-Output "`n" | Out-File $Log -Append
write-log "Event Viewer:" "Grabbing recent errors in Event Viewer..." 'n' $Log
Get-WinEvent -LogName 'Application','System' -FilterXPath "*[System[(Level=1  or Level=2 or Level=3) and TimeCreated[timediff(@SystemTime) &lt;= 86400000]]]" | Select-Object TimeCreated, ID, Logname, ProviderName, LevelDisplayName, Message | Ft | Out-File $EventView -Append

#Runs checkdsk on the C: drive and outputs the result to the log file for further analysis. 
Write-Output "`n" | Out-File $Log -Append
write-log "CHKDSK:" "Starting chkdsk / repair-volume on C:\ drive." 'n' $Log 
Write-Output "CHKDSK: Repair-Volume Results:" | Out-File $Log -NoNewline -Append
Repair-Volume -DriveLetter C -Scan -Verbose 4>&1 | Out-File $log -Append

#Runs the defrag utility on the C: drive to analyze if the drive is fragmented. 
Write-Output "`n" | Out-File $Log -Append
write-log "Defrag" "Starting drive optimization on C:\ drive." 'n' $Log 
Optimize-Volume C –Analyze -Verbose 

#Runs the disk cleanup utility. 
Write-Output "`n" | Out-File $Log -Append
write-log "Disk Cleanup:" "Starting Disk Cleanup.." 'n' $Log  
cleanmgr /sagerun:1 | out-Null    

#The script is finished, notepad is automatically opened to the location of the main log file. 
Write-Host "Script execution has concluded, opening troubleshooting log in 5 seconds. 

Feel free to reference the SFC, Event Viewer and DISM logs in the Troubleshooting Log directory..."
sleep 5 
.\notepad.exe $Log
