#Shodan-Trigger.ps1
#PowerShell script to adust triggers in Shodan.
#Created for PowerShell v5.1

#Created by Joshua Robinson

<#
.SYNOPSIS
This script is used to add or remove triggers (alert types) from Shodan assets. As well as display and backup current settings. 

.DESCRIPTION
The script is used to add or remove triggers (alert type) from various Shodan assets. This can be done as all or by naming specfic assets. Once the add or remove selection is made the script will launch a menu to prompt was what trigger the user is trying to address. 

Displaying the current information of each asset and backing up the data is also possible in this script. The user will provide their Shodan credentails and the script, utilizing selenium, will naviagte to the page and extract the API key needed to preform the functions. This was done to avoid saving API keys to the script. 

This script will create a shodan-data folder in the user's download directory to save data. 

.PARAMETER Action
   - Specifies the action to perform (mandatory).
   - Valid values: "add", "remove", "backup", "info".
   - add: used to add trigger alert to asset(s)
   - remove: used to remove trigger alert from asset(s)
   - info: display current assets and trigger settings to screen.
   - backup: backup assets and trigger settings to csv. 

.PARAMETER d
   - Use it to enable debug mode (optional).

.PARAMETER v
   - Use it write to screen the changes being completed. (optional).

.PARAMETER l
   - Use it to log changes of waht is added/removed from each asset to txt file. (optional).

.PARAMETER n
   - Use it to specify the name of the asset (optional).

.EXAMPLE
PS> .\Shodan-Trigger.ps1 dd
Add trigger to all assets

.EXAMPLE
PS> .\Shodan-Trigger.ps1 remove
Remove trigger from all assets

.EXAMPLE
PS> .\Shodan-Trigger.ps1 add -n or .\Shodan-Trigger.ps1 remove -n
Add/remove trigger to/from user supplied list.
User will be prompted for list later in the script.

.EXAMPLE
PS> .\Shodan-Trigger.ps1 info
Display to screen all assets and trigger settings

.EXAMPLE
PS> .\Shodan-Trigger.ps1 backup 
Backup all assets and trigger settign to csv. 

.EXAMPLE
PS> .\Shodan-Trigger.ps1 remove -v or .\Shodan-Trigger.ps1 add -v
Print to screen what asset and trigger is being changed

.EXAMPLE
PS> .\Shodan-Trigger.ps1 remove -l or .\Shodan-Trigger.ps1 add -l
Log the changes to each asset and the trigger to txt file. 

.EXAMPLE
PS> .\Shodan-Trigger.ps1 remove -l -v
PS> .\Shodan-Trigger.ps1 remove -l -v -n


.NOTES
Author: Joshua Robinson
Date: 2024-02-05
#>

#Creates the arguments that are passed with the script. 
#switches are needed to add functionality. 
param (
	[Parameter(Mandatory=$true, HelpMessage='Required Field, must supply add to add a trigger, remove to remove a trigger, backup to backup settings, or info to display current settings')]
	[ValidateSet("add", "remove", "backup", "info")]
	[string]$Action,

	[switch]$d,
	[switch]$v,
	[switch]$l,
	[switch]$n
)

#Debug mode option. When -d passed, Script Errors will write to console. 
#Otherwise the script will continue with no errors on console. 
if ($d) {
	$ErrorActionPreference = 'Continue'
}
else {
	$ErrorActionPreference = 'SilentlyContinue'
}

#Check is Selenium is installed. 
$SeleniumModule = Get-Module Selenium -ListAvailable
if($SeleniumModule -eq $null){
	Write-host "Important: Selenum module is unavailable. It is mandatory to have this module installed in the system to run the script successfully. `nRun PowerShell as Administrator and use Install-Module Selenium -Scope AllUsers`nDownload the latest version of the Chromedriver and place in same directory as the Selenium Module`nPossible directory: C:\Program Files\WindowsPowerShell\Modules\Selenium\3.0.1\assemblies" -ForegroundColor Red
	exit
}
#Get current data and set to script level variable.
$script:date = Get-date -format yyyy-MM-ddTHHmm

#Create script level arrays.
$script:trigger_choice = New-Object System.Collections.Generic.List[System.Object]
$script:trigger_description = New-Object System.Collections.Generic.List[System.Object]
$script:trigger_ID = New-Object System.Collections.Generic.List[System.Object]
$script:ID_Name_Verbose = New-Object System.Collections.Generic.List[System.Object]
$script:ID_Name_LOG = New-Object System.Collections.Generic.List[System.Object]

#Function to create folder in user's download folder to store data.
function CreateFolder {
	$script:folderPath = "$env:USERPROFILE\Downloads\Shodan-Data"

	#logic to determine if folder exists.
	if (-not (Test-Path -Path $folderPath)) {
		New-Item -Path $folderPath -ItemType Directory
		Write-Host "Folder created at $folderPath to store data."
	} else {
		Write-Host "Using folder $folderPath to store data."
	}
}

#Function to reterive the API key needed to execute the script. 
function ShodanAPIGet {
	#Import the Selenium Module
	Import-Module Selenium
	
	#Message to User that the Chrome window will launch. 
	Write-Host "Chrome window will auto launch. `nNo action is required from you while the Chrome window is open. `nPress Enter to continue. " -ForegroundColor Yellow
	Read-Host
	
	#Get Credentials for Shodan
	$Cred = Get-Credential -Message "Please enter your credentials for accessing Shodan"

	#Sets the Driver as the Chrome Driver
	$Driver = Start-SeChrome
	
	#Navigates to the Shodan login page
	Enter-SeUrl "https://account.shodan.io/login" -Driver $Driver

	# Find the username and password input fields (inspect the page source or use developer tools)
	$UsernameField = Find-SeElement -Driver $Driver -Id 'username'
	$PasswordField = Find-SeElement -Driver $Driver -Id 'password'

	# Enter your login credentials (replace with actual values)
	$UsernameField.SendKeys($($cred.UserName))
	$PasswordField.SendKeys($($cred.GetNetworkCredential().password))
	
	# Locate and click the login button (replace with actual button details)
	$LoginButton = $Driver.FindElement([OpenQA.Selenium.By]::ClassName("button-primary"))
	$LoginButton.Click()
	
	#Sleep time to allow page to load
	Start-Sleep -Seconds 2
	
	#Locates the button for account
	$AccountButton = $Driver.FindElement([OpenQA.Selenium.By]::ClassName("right-menu"))
	# Check if the element exists
	if ($AccountButton -ne $null)
	{
		# Element exists, proceed with clicking
		$AccountButton.Click()
	}
	else
	{
		# Element does not exist
		$Driver.Quit()
		Write-Host "Incorrect username and password." -ForegroundColor Red
		Read-Host
		ShodanAPIGet
	}
	
	#Sleep time to allow page to load
	Start-Sleep -Seconds 2
	
	#Get the driver to find the show button on page and click it
	$APIKeyShow = $Driver.FindElementById("showKey")
	$APIKeyShow.Click()
	
	#Sleep time to allow page to load
	Start-Sleep -Seconds 2
	
	#Find the API key on the page and set it to a global variable
	$APIKeyElement = $Driver.FindElement([OpenQA.Selenium.By]::ClassName("api-key"))
	$script:APIKey = $APIKeyElement.Text 

	#Validates if there is a API key saved. 
	if ($script:APIKey -eq $null){
		$Driver.Quit()
		Write-Host "API KEY NOT FOUND `nCheck your internet connection `nand ensure you have the correct username and password." -ForegroundColor Red
		Read-Host
		ShodanAPIGet
	}
	else{
		Write-Host "API KEY FOUND" -ForegroundColor Green
		$LogOutShodan = $Driver.FindElement([OpenQA.Selenium.By]::ClassName("u-pull-right"))
		$LogOutShodan.Click()
		
		#Sleep time to allow page to load
		Start-Sleep -Seconds 2
		
		#Closes the Chrome window.
		$Driver.Quit()
	}	
}

#Function used with INFO parameter. 
#Pulls assets names and what triggers are selected.
function Get_AssetName {
    
	# URL that will be used to gather data on the assets and their settings
	$url = "https://api.shodan.io/shodan/alert/info?key=$script:APIKey"

    # Execution of the query to pull the results
    $response = (Invoke-WebRequest $url).Content

	#Convert to allow use of data
	$alerts = ConvertFrom-Json $response
	
	#Loop to go through each asset and write asset name and triggers to screen. 
	foreach ($alert in $alerts) {
		$name = $alert.name
		$triggers = $alert.triggers.PSObject.Properties.Name -join '; '
		Write-Host "$name - $triggers"
	}
	
	#exit
	exit
}

#Function Used with BACKUP parameter
#Back up current settings for each asset
function Backup_Current_trigger_Settings {
	
	#execute function to create folder for saving backup. 
	CreateFolder
	
	# URL that will be used to gather data on the assets and their settings
	$url = "https://api.shodan.io/shodan/alert/info?key=$script:APIKey"
	
	# Execution of the query to pull the results
    $response = (Invoke-WebRequest $url).Content

	#Convert to allow use of data
	$alerts = ConvertFrom-Json $response
	
	#Loop to create a line for each asset and trigger setting. 
	$exportTriggers = foreach ($alert in $alerts) {
		[PSCustomObject]@{
		name = $alert.name
		triggers = $alert.triggers.PSObject.Properties.Name -join '; '
		}
	}
	
	#Export Results to a csv file
	$exportTriggers | Export-Csv -Path $script:folderPath\Triggers-$script:date.csv -NoTypeInformation -Append
	Write-Host "Export saved in $script:folderPath"
	
	#exit
	exit
}

#Function used to pull list of triggers in Shodan
function select_trigger {

	# URL that will be used to gather data on the assets and their settings
	$url = "https://api.shodan.io/shodan/alert/triggers?key=$script:APIKey"
	
	# Execution of the query to pull the results
	$response = (Invoke-WebRequest $url).Content
	
	#Convert to allow use of data
	$triggers = ConvertFrom-Json $response
	
	#Loop to get the name of each triggers and its description
	#Adds data to created arrays.
	foreach ($trigger in $triggers) {
		$name = $trigger.Name
		$description = $trigger.description
		$script:trigger_choice.Add($name)
		$script:trigger_description.Add($description)	
	}
	
	#Calls the next step in the script and passes the created array
	Selection_Process	
}

#Function to create a selection menu
Function Selection_Process{
	
	Write-Host "Select Trigger: "
	
	#Loop to write to screen each trigger and description. 
	for ($i = 0; $i -lt $script:trigger_choice.Count; $i++) {
		Write-Host "[$i] $($script:trigger_choice[$i]) - $($script:trigger_description[$i])"
	}
	
	Write-Host "To quit, press $i"
	Write-Host ""
	
	#Create variable s and set it to users input
	$s = Read-Host -Prompt "Select"
	Write-Host ""
	
	# Explicitly cast $s to an integer
    $s = [int]$s
	
	#logic to set the trigger to the user selected trigger 
    if ($s -ge 0 -and $s -lt $script:trigger_choice.Count) {
        $script:trigger_selection = $script:trigger_choice[$s]
	}
	
	#Allows for exit of script for user.
	elseif ($s -eq $i) {
		exit
	}
	
	#Allows for prompt when invalid selection occurs.
	else {
		Write-Host "INVALID SELECTION"
		Selection_Process $script:trigger_choice $script:trigger_description
		return
	}
	
	#Lets user know what trigger they selected. 
	if ($script:trigger_selection) {
        Write-Host "You have selected $script:trigger_selection"
    }
	
	#Logic to determine what function to run based on parameters passed at start. 
	if ($n) { 
		set_trigger_id 
	}
	
	if ($action -eq 'remove') {
		remove_trigger_all 	
	}
	
	if ($action -eq 'add') {
		add_trigger_all 
	}
}

#Used when -n switch is uesd
#Verifies the name is valid and gathers the asset ID.
function set_trigger_id{
    
	#Create arrays to be used. 	
    $input_name = New-Object System.Collections.Generic.List[System.Object]
    $shodan_name = New-Object System.Collections.Generic.List[System.Object]
	
	#Prompts user for asset name and format for use later in script
	$input_name_prompt = Read-Host "Enter the name of the asset(s). Separate each asset with a comma and space"
	$input_name = $input_name_prompt -split ', '

	# URL that will be used to gather data on the assets and their settings
	$url = "https://api.shodan.io/shodan/alert/info?key=$script:APIKey"
    
	# Execution of the query to pull the result
	$response = (Invoke-WebRequest $url).Content
	
	#Convert to allow use of data
	$alerts = ConvertFrom-Json $response

	#for loop to go through provided list of names.
	foreach ($alert in $alerts) {
		$name = $alert.name
		$shodan_name.Add($name)
		
		#If the name exists in shodan add it to array for trigger IDs
		if ($name -in $input_name) {
			$script:trigger_ID.Add($alert.id)
			
				#When -l or -v switch used add data to the need arrays
				if ($v) { 
					$script:ID_Name_Verbose.Add($alert.name)
				}
				if ($l) { 
					$script:ID_Name_LOG.Add($alert.name)
				}
		}
	}
	
	#For loop used to let user know what names are valid and what are invalid
	foreach ($iName in $input_name) {
		if ($iName -in $shodan_name) {	
			Write-Host "$iName is valid" -ForegroundColor Green
		}
		else {
			Write-Host "$iName is not valid" -ForegroundColor Red
		}
	}
	
	#Creates variable of total IDs to be used with progress bar.
	$total = $script:trigger_ID.count
	
	#exit script if no valid names found.
	if ($script:trigger_ID -eq $null) {
		Write-Host "No valid names found, exiting" -ForegroundColor Red
		exit
	}
	
	#Determine what function to call based on parameter passed at start of script. 
	if ($action -eq 'remove') {
		remove_trigger_execute 	
	}
	if ($action -eq 'add') {
		add_trigger_execute 
	}
}

#function to gather all IDs that have the selected trigger to be removed.
function remove_trigger_all{

	# URL that will be used to gather data on the assets and their settings
	$url = "https://api.shodan.io/shodan/alert/info?key=$script:APIKey"

    # Execution of the query to pull the results
    $response = (Invoke-WebRequest $url).Content
	
	#Convert to allow use of data
    $Alert_records = ConvertFrom-Json $response
	
	#for loop to go through each record.
	foreach ($Alert_record in $Alert_records){
		
		#For each record, get trigger names.
		$Trigger_Data = $Alert_record.triggers.PSObject.Properties.Name
		
		#Go through trigger names. If trigger exists, add the ID of the asset to trigger_ID array.
		foreach ($trigger in $Trigger_Data) {
            if ($trigger -eq $script:trigger_selection) {
				$script:trigger_ID.Add($Alert_record.id)
				
				#When -l or -v switch used add data to the need array
				if ($v) { 
					$script:ID_Name_Verbose.Add($Alert_record.name)
				}
				if ($l) { 
					$script:ID_Name_LOG.Add($Alert_record.name)
				}
            }
				
		}
	}
	
	#Creates variable of total IDs to be used with progress bar
	$total = $script:trigger_ID.count
	
	#Execute to next function in the script.
	remove_trigger_execute
}

#Function to remove the trigger from provided IDs
function remove_trigger_execute{
	
	#Creates variable to be used to query values in arrays.
	$ID_Count = 0
	
	#Loop to go through each ID provided to function.
	foreach ($id in $script:trigger_ID) {
		
		#Progress Bar
		$progress = ($ID_Count / $total) * 100
		Write-Progress -Activity "Processing Assets.." -Status "$ID_Count of $total" -PercentComplete $progress
		
		# URL that will be used to delete the trigger.
		$url2="https://api.shodan.io/shodan/alert/"+$id+"/trigger/"+$script:trigger_selection+"?key=$script:APIKey"
		
		# Execution of the query
		$response = Invoke-WebRequest -URI $url2 -Method Delete

		#When -l or -v switch used add data to the need array
		#Provides output of what is being done. 
		if ($v) { 
			$removed_name = $script:ID_Name_Verbose[$ID_Count]
			Write-Host "Removed Trigger $script:trigger_selection from $removed_name"
		}
		#Creates txt file of changes. Saves to script directory. 
		if ($l) { 
			#Execute function to create directoy.
			CreateFolder
			$removed_log_name = $script:ID_Name_LOG[$ID_Count]
			Add-Content -Path $script:folderPath\Remove_$script:trigger_selection-$script:date.txt -Value "Removed $script:trigger_selection from $removed_log_name" -Append
		}
		
		#Increase counter
		$ID_Count = $ID_Count + 1
	}
	
	#Send back to main menu when completed. 
	select_trigger
}

#Function to pull asset IDs for assets missing selected trigger.
function add_trigger_all{

	# URL that will be used to gather data on the assets and their settings
	$url = "https://api.shodan.io/shodan/alert/info?key=$script:APIKey"

    # Execution of the query to pull the results
    $response = (Invoke-WebRequest $url).Content
	
	#Convert to allow use of data
    $Alert_records = ConvertFrom-Json $response
	
	#for loop to go through each record.
	foreach ($Alert_record in $Alert_records){
		
		#For each record, get trigger names.
		$Trigger_Data = $Alert_record.triggers.PSObject.Properties.Name
				
			#Go through trigger names. If trigger does not exist, add ID of asset to Trigger_ID array. 
            if ($Trigger_Data -notcontains $script:trigger_selection) {
				$script:trigger_ID.Add($Alert_record.id)
				
				#When -l or -v switch used add data to the need array
				if ($v) { 
					$script:ID_Name_Verbose.Add($Alert_record.name)
				}
				if ($l) { 
					$script:ID_Name_LOG.Add($Alert_record.name)
				}				
		}
	}
	
	#Creates variable of total IDs to be used with progress ba
	$total = $script:trigger_ID.count
	
	#Execute to next function in the script.
	add_trigger_execute
}

#Function to add the trigger to provided IDs
function add_trigger_execute{
	
	#Creates variable to be used to query values in arrays.
	$ID_Count = 0

	#Loop to go through each ID provided to function.
	foreach ($id in $script:trigger_ID) {
		
		#Progress Bar
		$progress = ($ID_Count / $total) * 100
		Write-Progress -Activity "Processing Assets.." -Status "$ID_Count of $total" -PercentComplete $progress		
		
		# URL that will be used to add the trigger.
		$url2="https://api.shodan.io/shodan/alert/"+$id+"/trigger/"+$script:trigger_selection+"?key=$script:APIKey"
	
		# Execution of the query
		$response = Invoke-WebRequest -URI $url2 -Method Put

		#When -l or -v switch used add data to the need array
		#Provides output of what is being done.	
		if ($v) { 
			$add_name = $script:ID_Name_Verbose[$ID_Count]
			Write-Host "Added Trigger $script:trigger_selection from $add_name"
		}
		#Creates txt file of changes. Saves to script directory.
		if ($l) { 
			#Execute function to create directoy.
			CreateFolder			
			$add_log_name = $script:ID_Name_LOG[$ID_Count]
			Add-Content -Path $script:folderPath\Add_$script:trigger_selection-$script:date.txt -Value "Added $script:trigger_selection from $add_log_name" -Append
		}
		
		#Increase counter
		$ID_Count = $ID_Count + 1	
	}
	
	#Send back to main menu when completed.
	select_trigger
}

#~~~~~~Script Process~~~~~#
#Call the ShodanAPIGet function
ShodanAPIGet

#Execute releated function if info parameter used.
if ($action -eq 'info') {
	Get_AssetName
}

#Execute releated function if backup parameter used. 
if ($action -eq 'backup') {
	Backup_Current_trigger_Settings
}

#Execute the select_trigger function
select_trigger