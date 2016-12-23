#Zachary Niezelski
#Redirected Printer Handler
#$configure = 1
Param(
  [string]$configure,
  [string]$isolate
)

[string]$StartTime = Get-Date -Format "dd-MM-yyyy hh:mm:ss"

#Setup psprovider so we can access the registry
 New-PSDrive -Name HKU -PSProvider Registry -Root  Registry::HKEY_USERS -ErrorAction SilentlyContinue
 New-PSDrive -Name HKLM -PSProvider Registry -Root Registry::HKEY_Local_Machine -ErrorAction SilentlyContinue

  
#Mark redirected printer attributes so administrators cannot see all queues
if([string]$isolate ) 
{
	$Printers = Get-WmiObject -Class Win32_Printer | where {$_.parameters -ne $Null}
	foreach ($Printer in $Printers)
		{
			$path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Printers\" + $Printer.name
			 New-ItemProperty -Path $path -Name "attributes" -Value "35328" -PropertyType "dword" -Force

		}
	write-host "Isolation keys inserted"
	exit
}



if([string]$configure ) 
{

#Check to see that at lease powershell 3.0 is configured

if ($PSVersionTable.PSVersion.major -lt 3){
Add-Type -AssemblyName System.Windows.Forms
# show the MsgBox:
$version = $PSVersionTable.PSVersion.major 
$message = "Your system is running PowerShell $version and this script requires at least 3.0. Unexpected behavior will occur. Please update."
$result = [System.Windows.Forms.MessageBox]::Show($message, 'Warning', 'ok', 'Warning')
}



     
		#Load Items From Registry for user interface (also does this each round)
		$key = 'HKLM:\SOFTWARE\Printerceptor'
		$LoadRecreateFullList = Get-ItemProperty -Path $key -Name "RecreateFullList" | foreach { $_.RecreateFullList } 
		$LoadDoNotRenList = Get-ItemProperty -Path $key -Name "DoNotRenList" | foreach { $_.DoNotRenList }
		$LoadNameFormat = Get-ItemProperty -Path $key -Name "NamingFormat" | foreach { $_.NamingFormat } 
		$global:Scope = Get-ItemProperty -Path $key -Name "Scope" | foreach { $_.Scope } 
        $global:ScopeAll = Get-ItemProperty -Path $key -Name "ScopeAll" | foreach { $_.ScopeAll } 
        [array]$global:SecName = Get-ItemProperty -Path $key -Name "SecName" | select -ExpandProperty SecName
        [array]$global:sectype = Get-ItemProperty -Path $key -Name "sectype" | select -ExpandProperty sectype
        [array]$global:secsid = Get-ItemProperty -Path $key -Name "SecSID" | select -ExpandProperty SecSID 
        [array]$global:secpath = Get-ItemProperty -Path $key -Name "SecPath" | select -ExpandProperty SecPath
        #copy policy keys
remove-item -Path HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy -Force -Recurse
copy-item -Path HKLM:\SOFTWARE\Printerceptor\Active\AdvancedPolicy -Destination HKLM:\SOFTWARE\Printerceptor -Recurse 

#First Checks
#Check Language
      $firstrun = Get-ItemProperty -Path $key -Name "FirstRun" | foreach { $_.FirstRun }
	if ($firstrun -eq '1')
	{
		
		if ((get-culture).name -ne "en-US")
		{
			Add-Type -AssemblyName System.Windows.Forms
			$message = "The detected system language is not English. Please be sure to configure the proper regular expression."
			$result = [System.Windows.Forms.MessageBox]::Show($message, 'Warning', 'ok', 'Warning')	
			
		
		}
	#Set the proper expression
	if ((get-culture).name -eq "en-US"){set-ItemProperty -Path $key -Name "RedirectedExpression" -Value "( \(redirected (\d+)\))"  -Force}
	if ((get-culture).name -eq "nl-NL"){set-ItemProperty -Path $key -Name "RedirectedExpression" -Value "( \((\d+) omgeleid\))"  -Force}
	if ((get-culture).name -eq "es-US"){set-ItemProperty -Path $key -Name "RedirectedExpression" -Value "( \((\d+) redireccionado\))"  -Force}
    if ((get-culture).name -eq "de-CH"){set-ItemProperty -Path $key -Name "RedirectedExpression" -Value "( \(umgeleitet (\d+)\))" -Force}
    if ((get-culture).name -eq "pl-PL"){set-ItemProperty -Path $key -Name "RedirectedExpression" -Value "( \(przekierowana sesja: (\d+)\))" -Force}
	} 

	
	$LoadRedirectedExpression = Get-ItemProperty -Path $key -Name "RedirectedExpression" | foreach { $_.RedirectedExpression } 

		
		#Prompt message if not running as administrator
		If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
		    [Security.Principal.WindowsBuiltInRole] "Administrator"))
		{
		[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
		[System.Windows.Forms.MessageBox]::Show("Please run with administrative rights.") 
		   [environment]::exit(0)
		}



        #Confiure proper control sizes
        $sOS =Get-WmiObject -class Win32_OperatingSystem 
         $OS = $sOS | Select-Object caption
        if ($OS -match "2008"){
        $ListColumnSize = 324
        }else{$ListColumnSize = 341}

		Add-Type -AssemblyName System.Windows.Forms
		$Form = New-Object system.Windows.Forms.Form

		$Form.Width = 743
		$Form.Height = 510
		$Form.FormBorderStyle = "FixedDialog"
		$Form.MaximizeBox = $False
		$Form.Text = "Printerceptor (Version 4.0 Alpha)"


		$label = New-Object System.Windows.Forms.Label
		$label.location = New-Object System.Drawing.Point(5, 2)
		$label.Size = New-Object System.Drawing.Size(150, 15)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$label.Font = $FontBold
		$label.Text = "Printer Name Format:"





		$labelreg = New-Object System.Windows.Forms.Label
		$labelreg.location = New-Object System.Drawing.Point(375, 2)
		$labelreg.Size = New-Object System.Drawing.Size(150, 15)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$labelreg.Font = $FontBold
		$labelreg.Text = "Regular Expression:"
		$Form.Controls.Add($labelreg) 



		$LinkLabel = New-Object System.Windows.Forms.LinkLabel 
		$LinkLabel.Location = New-Object System.Drawing.Size(5,450) 
		$LinkLabel.Size = New-Object System.Drawing.Size(80,20) 
		$LinkLabel.LinkColor = "BLUE" 
		$LinkLabel.ActiveLinkColor = "RED" 
		$LinkLabel.Text = "Documentation" 
		$LinkLabel.add_Click({[system.Diagnostics.Process]::start("https://github.com/zniezelski/Printerceptor/releases")}) 
		$Form.Controls.Add($LinkLabel) 



		$ButtonPrintMGR = New-Object System.Windows.Forms.LinkLabel 
		$ButtonPrintMGR.Location = New-Object System.Drawing.Size(90,450) 
		$ButtonPrintMGR.Size = New-Object System.Drawing.Size(110,20) 
		$ButtonPrintMGR.LinkColor = "BLUE" 
		$ButtonPrintMGR.ActiveLinkColor = "RED" 
		$ButtonPrintMGR.Text = "Printer Management" 
		$Form.Controls.Add($ButtonPrintMGR) 

		$LogLabel = New-Object System.Windows.Forms.LinkLabel 
		$LogLabel.Location = New-Object System.Drawing.Size(200,450) 
		$LogLabel.Size = New-Object System.Drawing.Size(55,20) 
		$LogLabel.LinkColor = "BLUE" 
		$LogLabel.ActiveLinkColor = "RED" 
		$LogLabel.Text = "Event Log" 
		$LogLabel.add_Click({
		$LogViewer = Get-ItemProperty -Path $key -Name "LogViewer" | foreach { $_.LogViewer }
		cd "C:\Program Files\Printerceptor"
		Start-Process $LogViewer -ArgumentList "Log.csv"
		}) 
		$Form.Controls.Add($LogLabel) 




		$OptionsLabel = New-Object System.Windows.Forms.LinkLabel
		$OptionsLabel.Location = New-Object System.Drawing.Size(262,450) 
		$OptionsLabel.Size = New-Object System.Drawing.Size(80,20) 
		$OptionsLabel.LinkColor = "BLUE" 
		$OptionsLabel.ActiveLinkColor = "RED" 
		$OptionsLabel.Text = "Options" 



     
        $Form.Controls.Add($OptionsLabel)

		$comboBox1 = New-Object System.Windows.Forms.ComboBox
		$comboBox1.location = New-Object System.Drawing.Point(5, 20)
		$comboBox1.Size = New-Object System.Drawing.Size(299, 310)


		$ComboItems = (Get-ItemProperty -Path $key -Name NamingFormatList).NamingFormatList

		#add and select item or add
		foreach ($itema in $ComboItems) {
			if ($itema -eq $LoadNameFormat){
			$selected = $comboBox1.Items.add($itema)
			$comboBox1.set_SelectedIndex($selected)
			}
			else {
			$comboBox1.Items.add($itema)
			}
		}

		$Form.Controls.Add($comboBox1)  

		$comboBox2 = New-Object System.Windows.Forms.ComboBox
		$comboBox2.location = New-Object System.Drawing.Point(375, 20)
		$comboBox2.Size = New-Object System.Drawing.Size(249, 310)


		$ComboItems = (Get-ItemProperty -Path $key -Name RedirectedExpressionList).RedirectedExpressionList

		#add and select item or add
		foreach ($itema in $ComboItems) {
			if ($itema -eq $LoadRedirectedExpression){
			$selected = $comboBox2.Items.add($itema)
			$comboBox2.set_SelectedIndex($selected)
			}
			else {
			$comboBox2.Items.add($itema)
			}
		}

		$Form.Controls.Add($comboBox2)  
		  
		$ButtonAdd = New-Object System.Windows.Forms.Button
		$ButtonAdd.location = New-Object System.Drawing.Point(305,20)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonAdd.Font = $FontBold
		$ButtonAdd.Size = New-Object System.Drawing.Size(20, 20)
		$ButtonAdd.Text = "+"
		$Form.Controls.Add($ButtonAdd)

		$ButtonAddreg = New-Object System.Windows.Forms.Button
		$ButtonAddreg.location = New-Object System.Drawing.Point(625,20)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonAddreg.Font = $FontBold
		$ButtonAddreg.Size = New-Object System.Drawing.Size(20, 20)
		$ButtonAddreg.Text = "+"
		$Form.Controls.Add($ButtonAddreg)

		$ButtonSubreg = New-Object System.Windows.Forms.Button
		$ButtonSubreg.location = New-Object System.Drawing.Point(647,20)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonSubreg.font = $FontBold
		$ButtonSubreg.Size = New-Object System.Drawing.Size(20, 20)
		$ButtonSubreg.Text = "-"
		$Form.Controls.Add($ButtonSubreg)

		$ButtonTestreg = New-Object System.Windows.Forms.Button
		$ButtonTestreg.location = New-Object System.Drawing.Point(670,20)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonTestreg.Font = $FontBold
		$ButtonTestreg.Size = New-Object System.Drawing.Size(50, 20)
		$ButtonTestreg.Text = "Test"
		$Form.Controls.Add($ButtonTestReg)
		$ButtonTestreg.Add_Click({

		$match = $null
		$LoadRedirectedExpression = $Combobox2.text
		$Printers = Get-WmiObject -Class Win32_Printer
		foreach ($Printer in $Printers){
		if ($Printer.name -match $LoadRedirectedExpression){
		$match += $Printer.name | out-string
		}

		}
		if ($match -eq $null) { $match = "No printers match. Check expression and make sure printers are available under current logged in user that match for testing." }
			Add-Type -AssemblyName System.Windows.Forms
			$message = "The detected system language is not English. Please be sure to configure the proper regular expression."
			$result = [System.Windows.Forms.MessageBox]::Show($match, 'Expression Test', 'ok', 'information')	


		})

		$ButtonSub = New-Object System.Windows.Forms.Button
		$ButtonSub.location = New-Object System.Drawing.Point(327,20)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonSub.font = $FontBold
		$ButtonSub.Size = New-Object System.Drawing.Size(20, 20)
		$ButtonSub.Text = "-"
		$ButtonSub.add_Click({$label.Text = $comboBox1.SelectedItem.ToString()})
		$Form.Controls.Add($ButtonSub)



		$label2 = New-Object System.Windows.Forms.Label
		$label2.location = New-Object System.Drawing.Point(5, 50)
		$label2.Size = New-Object System.Drawing.Size(250, 15)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$label2.Font = $FontBold
		$label2.Text = "Printers excluded from rename:"
		$Form.Controls.Add($label2)


		$DoNotRenameList = New-Object System.Windows.Forms.ListView 
		$DoNotRenameList.location = New-Object System.Drawing.Size(5,70) 
		$DoNotRenameList.Size = New-Object System.Drawing.Size(345,370) 
		$DoNotRenameList.CheckBoxes = $true
		$DoNotRenameList.Columns.Add("Driver",$ListColumnSize)

		$DoNotRenameList.View = [System.Windows.Forms.View]::details
		$Form.Controls.Add($DoNotRenameList)


		$RecreateList = New-Object System.Windows.Forms.ListView 
		$RecreateList.location = New-Object System.Drawing.Size(375,70) 
		$RecreateList.Size = New-Object System.Drawing.Size(345,370) 
		$RecreateList.CheckBoxes = $true
		$RecreateList.Columns.Add("Driver",$ListColumnSize)
		$RecreateList.View = [System.Windows.Forms.View]::details
		$Form.Controls.Add($RecreateList)


		#Add Drivers to list
		$Drivers = Get-WmiObject Win32_PrinterDriver
			foreach ($Driver in $Drivers) 
			{ 
				$Drivername = $($Driver.Name).split(",")
				
				$isRecreatechecked = $false
				$isRenamedchecked = $false
				
					#See if driver is part of list of checked drivers in recreate list
				foreach ($listitem in $LoadRecreateFullList){if ($Drivername -eq $listitem) {$isRecreatechecked = $true; break } else { $iscRecreatehecked = $false}}
				#If the drive is in the list to be checked add it checked, else just add it	
				
				if ($isRecreatechecked -eq $true) {$RecreateList.Items.Add($Drivername).Checked = $true}else {
				if (($Drivername -eq "Remote Desktop Easy Print") -or ($Drivername -match "Microsoft") -or ($Drivername -match "Fax")) {}else{
				$RecreateList.Items.Add($Drivername)
				}
				}
						
						


				
				#$EasyDriverExist = $false
				$OnlyFullEnabled = $false
				foreach ($listitemrename in $LoadDoNotRenList)
					{
						#Determine if the easy print driver exists or not because we want it to still show in list even if it doesn't exist
						#if ($listitemrename -eq "Remote Desktop Easy Print") { $EasyDriverExist = $true}
						if ($listitemrename -eq "Non Full Access Enabled") { $OnlyFullEnabled = $true}
						#See if driver is part of list of checked drivers in do not rename list
						if ($Drivername -eq $listitemrename) {$isRenamedchecked = $true; break} else {$isRenamedchecked = $false}
					}
					#add checked else just add it
				if ($isRenamedchecked -eq $true) {$DoNotRenameList.Items.Add($Drivername).Checked = $true} else { 
				
				 if (($Drivername -eq "Remote Desktop Easy Print")-or ($Drivername -match "Microsoft") -or ($Drivername -match "Fax")) {} else{
				$DoNotRenameList.Items.Add($Drivername)
				}
				}
						

			}

		#add easy print to list if the driver doesn't exist
		#if ($EasyDriverExist -eq $false){$DoNotRenameList.Items.Add("Remote Desktop Easy Print").Checked = $true}
		if ($listitemrename -eq "Non Full Access Enabled"){$DoNotRenameList.Items.Add("Non Full Access Enabled").checked = $true; $OnlyFullEnabled = $true;}
		if ($OnlyFullEnabled -eq $false){$DoNotRenameList.Items.Add("Non Full Access Enabled")}
		#if ($OnlyFullEnabled -eq $false){$DoNotRenameList.Items.Add("Only Drivers Full Access Enabled")}
		$label0 = New-Object System.Windows.Forms.Label
		$label0.location = New-Object System.Drawing.Point(4, 2)
		$label0.Size = New-Object System.Drawing.Size(320, 18)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$label0.Font = $FontBold
		$label0.Text = "Printer Name Format:"
		$Form.Controls.Add($label0)


		$label3 = New-Object System.Windows.Forms.Label
		$label3.location = New-Object System.Drawing.Point(375, 50)
		$label3.Size = New-Object System.Drawing.Size(320, 18)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$label3.Font = $FontBold
		$label3.Text = "Give full access to printer(s):"
		$Form.Controls.Add($label3)


		$ButtonSave = New-Object System.Windows.Forms.Button
		$ButtonSave.location = New-Object System.Drawing.Point(640,445)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonSave.Font = $FontBold
		$ButtonSave.Size = New-Object System.Drawing.Size(80, 20)
		$ButtonSave.Text = "Save"
		$Form.Controls.Add($ButtonSave)

		$ButtonAdvancedPolicy = New-Object System.Windows.Forms.Button
		$ButtonAdvancedPolicy.location = New-Object System.Drawing.Point(510,445)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonDefault.Font = $FontBold
		$ButtonAdvancedPolicy.Size = New-Object System.Drawing.Size(120, 20)
		$ButtonAdvancedPolicy.Text = "Advanced Policy"
		$Form.Controls.Add($ButtonAdvancedPolicy)

        $CheckAdvancedPolicyExistance = {

 
        $policies = Get-ChildItem -Path "HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy" 
        $policiesexistance = ($policies | Foreach-Object {Get-ItemProperty $_.PsPath } | where {$_.enabled -eq "1"} | Sort-Object priority  | foreach { $_.pschildname}).count
        if ($policiesexistance -ge 1) {$ButtonAdvancedPolicy.font = $FontBold} else {$ButtonAdvancedPolicy.font = $null}
        }
        & $CheckAdvancedPolicyExistance

   
        
		$ButtonRestrictions = New-Object System.Windows.Forms.Button
		$ButtonRestrictions.location = New-Object System.Drawing.Point(375,445)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonRestrictions.Font = $FontBold
		$ButtonRestrictions.Size = New-Object System.Drawing.Size(125, 20)
		$ButtonRestrictions.Text = "Restrictions"
        $CheckRestrictionExistance = {
        if ($global:ScopeAll -eq "No"){$ButtonRestrictions.font = $FontBold} else {$ButtonRestrictions.font = $null}
        }
        & $CheckRestrictionExistance
		$Form.Controls.Add($ButtonRestrictions)
        



		$ButtonAdd.add_Click({


		$duplicate = 0
		foreach ($item in $comboBox1.Items){

		if ($item -eq $comboBox1.Text) {$duplicate++}}
		if($duplicate -lt 1) {$comboBox1.Items.Add($comboBox1.Text)}
		})










   $OptionsLabel.add_click({
        $frmoptions = new-object system.windows.forms.form
		$frmoptions.width = 350
		$frmoptions.height = 345
		$frmoptions.MaximizeBox = $false
		$frmoptions.formborderstyle="FixedDialog"
		$frmoptions.text = "Printerceptor Options"


		$lbleventlogviewer = New-Object System.Windows.Forms.Label
		$lbleventlogviewer.location = New-Object System.Drawing.Point(8,2)
		$lbleventlogviewer.Size = New-Object System.Drawing.Size(250, 15)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$lbleventlogviewer.Font = $FontBold
		$lbleventlogviewer.Text = "Open event log with following application:"

        $global:txtlogviewer = New-Object System.Windows.Forms.TextBox 
        $global:txtlogviewer.Location = New-Object System.Drawing.Point(10,20) 
        $global:txtlogviewer.Size = New-Object System.Drawing.Size(260,20) 
        $LogViewer = Get-ItemProperty -Path $key -Name "LogViewer" | foreach { $_.LogViewer }
        $global:txtlogviewer.Text = $LogViewer

        $ButtonLogBrowse = New-Object System.Windows.Forms.Button
		$ButtonLogBrowse.location = New-Object System.Drawing.Point(275,20)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$ButtonLogBrowse.Size = New-Object System.Drawing.Size(50, 20)
		$ButtonLogBrowse.Text = "Browse"
     #-----------------------

        $lblpsexec = New-Object System.Windows.Forms.Label
		$lblpsexec.location = New-Object System.Drawing.Point(8,45)
		$lblpsexec.Size = New-Object System.Drawing.Size(250, 15)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$lblpsexec.Font = $FontBold
		$lblpsexec.Text = "PsExec Path:"

        $global:txtpsexec = New-Object System.Windows.Forms.TextBox 
        $global:txtpsexec.Location = New-Object System.Drawing.Point(10,63) 
        $global:txtpsexec.Size = New-Object System.Drawing.Size(260,20) 
        $psexecpath = Get-ItemProperty -Path $key -Name "psexecPath" | foreach { $_.psexecPath }
        $global:txtpsexec.Text = $psexecpath

        $ButtonPsexecBrowse = New-Object System.Windows.Forms.Button
		$ButtonPsexecBrowse.location = New-Object System.Drawing.Point(275,63)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$ButtonPsexecBrowse.Size = New-Object System.Drawing.Size(50, 20)
		$ButtonPsexecBrowse.Text = "Browse"
		#----------------------------------

        $lblrounds = New-Object System.Windows.Forms.Label
		$lblrounds.location = New-Object System.Drawing.Point(8,88)
		$lblrounds.Size = New-Object System.Drawing.Size(250, 15)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$lblrounds.Font = $FontBold
		$lblrounds.Text = "Amount of round passes:"

        $global:txtrounds = New-Object System.Windows.Forms.TextBox 
        $global:txtrounds.Location = New-Object System.Drawing.Point(10,106) 
        $global:txtrounds.Size = New-Object System.Drawing.Size(20,20) 
        $RegRounds = Get-ItemProperty -Path $key -Name "Rounds" | foreach { $_.Rounds }
        $global:txtrounds.Text = $RegRounds


        $lblquerytime = New-Object System.Windows.Forms.Label
		$lblquerytime.location = New-Object System.Drawing.Point(8,132)
		$lblquerytime.Size = New-Object System.Drawing.Size(260, 15)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$lblquerytime.Font = $FontBold
		$lblquerytime.Text = "Additional wait time in seconds between rounds:"

        $global:txtquerytime = New-Object System.Windows.Forms.TextBox 
        $global:txtquerytime.Location = New-Object System.Drawing.Point(10,148) 
        $global:txtquerytime.Size = New-Object System.Drawing.Size(20,20) 
        $RegAdditionalTime = Get-ItemProperty -Path $key -Name "AdditionalTime" | foreach { $_.AdditionalTime }
        $global:txtquerytime.Text = $RegAdditionalTime


        $lbltask = New-Object System.Windows.Forms.Label
		$lbltask.location = New-Object System.Drawing.Point(8,174)
		$lbltask.Size = New-Object System.Drawing.Size(260, 15)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$lbltask.Font = $FontBold
		$lbltask.Text = "Scheduled Task State and Control:"

$groupBox = New-Object System.Windows.Forms.GroupBox #create the group box
$groupBox.Location = New-Object System.Drawing.Size(8,174) #location of the group box (px) in relation to the primary window's edges (length, height)
$groupBox.size = New-Object System.Drawing.Size(318,90) #the size in px of the group box (length, height)
$groupBox.text = "Scheduled Task State and Control:" #labeling the box













        $global:lbltaskstate = New-Object System.Windows.Forms.Label
		$global:lbltaskstate.location = New-Object System.Drawing.Point(95,22)
		$global:lbltaskstate.Size = New-Object System.Drawing.Size(100, 15)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
	    $global:lbltaskstate.Font = $FontBold
		$global:lbltaskstate.Text = "Current State:"


        $global:lbltaskstatesuffix = New-Object System.Windows.Forms.Label
		$global:lbltaskstatesuffix.location = New-Object System.Drawing.Point(175,23)
		$global:lbltaskstatesuffix.Size = New-Object System.Drawing.Size(100, 15)
		$Font2 = new-object System.Drawing.Font("Arial",8 )
	    $global:lbltaskstatesuffix.Font = $Font2
		$global:lbltaskstatesuffix.Text = "Loading.."





$timer1 = New-Object 'System.Windows.Forms.Timer'	
$timer1.Enabled = $True
	$timer1.Interval = 1000
	$timer1.add_Tick({






        #--------



        Function Get-Task
{
[CmdletBinding()]
    param (
    [parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true,Mandatory=$false)]
    [system.string[]] ${ComputerName} = $env:computername,
 
    [parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true,Mandatory=$false,
               HelpMessage="The task folder string must begin by '\'")]
    [ValidatePattern('^\\')]
    [system.string[]] ${Path} = "\",
 
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [system.string[]] ${Name} = $null
    )
    Begin {}
    Process
    {
        $resultsar = @()
        $ComputerName | ForEach-Object -Process {
            $Computer = $_
            $TaskService = New-Object -com schedule.service
            try
            {
                $TaskService.Connect($Computer) | Out-Null
            } catch {
                Write-Warning "Failed to connect to $Computer"
            }
            if ($TaskService.Connected)
            {
                Write-Verbose -Message "Connected to the scheduler service of computer $Computer"
                    Foreach ($Folder in $Path)
                    {
                        Write-Verbose -Message "Dealing with folder task $Folder"
                        $RootFolder = $null
                        try
                        {
                            $RootFolder = $TaskService.GetFolder($Folder)
                        } catch {
                            Write-Warning -Message "The folder task $Folder cannot be found"
                        }
                        if ($RootFolder)
                        {
                            Foreach ($Task in $Name)
                            {
                                $TaskObject = $null
                                try
                                {
                                    Write-Verbose -Message "Dealing with task name $Task"
                                    $TaskObject = $RootFolder.GetTask($Task)
                                } catch {
                                    Write-Warning -Message "The task $Task cannot be found under $Folder"
                                }
                                if ($TaskObject)
                                {
                                    switch ($TaskObject.NextRunTime) {
                                        (Get-Date -Year 1899 -Month 12 -Day 30 -Minute 00 -Hour 00 -Second 00) {$NextRunTime = "None"}
                                        default {$NextRunTime = $TaskObject.NextRunTime}
                                    }
                                     
                                    switch ($TaskObject.LastRunTime) {
                                        (Get-Date -Year 1899 -Month 12 -Day 30 -Minute 00 -Hour 00 -Second 00) {$LastRunTime = "Never"}
                                        default {$LastRunTime = $TaskObject.LastRunTime}
                                    } 
                                                                        
                                    # Author
                                    switch (([xml]$TaskObject.XML).Task.RegistrationInfo.Author)
                                    {
                                        '$(@%ProgramFiles%\Windows Media Player\wmpnscfg.exe,-1001)'   { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\acproxy.dll,-101)'                   { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\aepdu.dll,-701)'                     { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\aitagent.exe,-701)'                  { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\appidsvc.dll,-201)'                  { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\appidsvc.dll,-301)'                  { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\System32\AuxiliaryDisplayServices.dll,-1001)' { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\bfe.dll,-2001)'                      { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\BthUdTask.exe,-1002)'                { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\cscui.dll,-5001)'                    { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\System32\DFDTS.dll,-101)'                     { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\dimsjob.dll,-101)'                   { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\dps.dll,-600)'                       { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\drivers\tcpip.sys,-10000)'           { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\defragsvc.dll,-801)'                 { $Author = 'Microsoft Corporation'}
                                        '$(@%systemRoot%\system32\energy.dll,-103)'                    { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\HotStartUserAgent.dll,-502)'         { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\kernelceip.dll,-600)'                { $Author = 'Microsoft Corporation'}
                                        '$(@%systemRoot%\System32\lpremove.exe,-100)'                  { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\memdiag.dll,-230)'                   { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\mscms.dll,-201)'                     { $Author = 'Microsoft Corporation'}
                                        '$(@%systemRoot%\System32\msdrm.dll,-6001)'                    { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\msra.exe,-686)'                      { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\nettrace.dll,-6911)'                 { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\osppc.dll,-200)'                     { $Author = 'Microsoft Corporation'}
                                        '$(@%systemRoot%\System32\perftrack.dll,-2003)'                { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\PortableDeviceApi.dll,-102)'         { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\profsvc,-500)'                       { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\RacEngn.dll,-501)'                   { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\rasmbmgr.dll,-201)'                  { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\regidle.dll,-600)'                   { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\sdclt.exe,-2193)'                    { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\sdiagschd.dll,-101)'                 { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\sppc.dll,-200)'                      { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\srrstr.dll,-321)'                    { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\upnphost.dll,-215)'                  { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\usbceip.dll,-600)'                   { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\w32time.dll,-202)'                   { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\wdc.dll,-10041)'                     { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\wer.dll,-293)'                       { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\System32\wpcmig.dll,-301)'                    { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\System32\wpcumi.dll,-301)'                    { $Author = 'Microsoft Corporation'}
                                        '$(@%systemroot%\system32\winsatapi.dll,-112)'                 { $Author = 'Microsoft Corporation'}
                                        '$(@%SystemRoot%\system32\wat\WatUX.exe,-702)'                 { $Author = 'Microsoft Corporation'}
                                        default {$Author = $_ }                                   
                                    }
                                    # Created
                                    switch (([xml]$TaskObject.XML).Task.RegistrationInfo.Date)
                                    {
                                        ''      {$Created = 'Unknown'}
                                        default {$Created = Get-Date -Date ([xml]$TaskObject.XML).Task.RegistrationInfo.Date }
                                    }
                                     
                                    # Triggers
                                    # ([xml]$TaskObject.XML).Task.Triggers.Count
                                    # Inject here dev. about triggers
 
                                    # Status
                                    # http://msdn.microsoft.com/en-us/library/windows/desktop/aa383617%28v=vs.85%29.aspx
                                    switch ($TaskObject.State)
                                    {
                                        0 { $State = 'Unknown'}
                                        1 { $State = 'Disabled'}
                                        2 { $State = 'Queued'}
                                        3 { $State = 'Ready'}
                                        4 { $State = 'Running'}
                                        default {$State = $_ }
                                    }
 
                                    Switch (([xml]$TaskObject.XML).Task.Settings.Hidden)
                                    {
                                        false { $Hidden = $false}
                                        true  { $Hidden = $true }
                                        default { $Hidden = $false}
                                    }
                                    $resultsar += New-Object -TypeName PSObject -Property @{
                                        Created = $Created
                                        ComputerName = $Computer
                                        Author = $Author
                                        Name = $TaskObject.Name
                                        Path = $Folder
                                        State = $State
                                        Enabled = $TaskObject.Enabled
                                        LastRunTime = $LastRunTime
                                        LastTaskResult = $TaskObject.LastTaskResult
                                        # NumberOfMissedRuns = $TaskObject.NumberOfMissedRuns
                                        NextRunTime = $NextRunTime
                                        # Definition = $TaskObject.Definition
                                        Xml = $TaskObject.XML
                                        Hidden = $Hidden
                                    }
                                }
                            }
                        }
                    }
            }
        }
        return $resultsar
    } 
    End {}
}




        #-------


$taskstate = get-task -Name "Printerceptor"
$tasks = $taskstate.state | Out-String
$global:lbltaskstatesuffix.Text = $tasks 
})



		$ButtonRun = New-Object System.Windows.Forms.Button
		$ButtonRun.location = New-Object System.Drawing.Point(50,45)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonAdd.Font = $FontBold
		$ButtonRun.Size = New-Object System.Drawing.Size(40, 20)
		$ButtonRun.Text = "Run"


		$ButtonEnd = New-Object System.Windows.Forms.Button
		$ButtonEnd.location = New-Object System.Drawing.Point(95,45)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonAdd.Font = $FontBold
		$ButtonEnd.Size = New-Object System.Drawing.Size(40, 20)
		$ButtonEnd.Text = "End"


		$ButtonEnable = New-Object System.Windows.Forms.Button
		$ButtonEnable.location = New-Object System.Drawing.Point(140,45)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonAdd.Font = $FontBold
		$ButtonEnable.Size = New-Object System.Drawing.Size(60, 20)
		$ButtonEnable.Text = "Enable"

		$ButtonDisable = New-Object System.Windows.Forms.Button
		$ButtonDisable.location = New-Object System.Drawing.Point(205,45)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonAdd.Font = $FontBold
		$ButtonDisable.Size = New-Object System.Drawing.Size(60, 20)
		$ButtonDisable.Text = "Disable"
        

        $ButtonSaveOpt = New-Object System.Windows.Forms.Button
		$ButtonSaveOpt.location = New-Object System.Drawing.Point(245,280)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonSave.Font = $FontBold
		$ButtonSaveOpt.Size = New-Object System.Drawing.Size(80, 20)
		$ButtonSaveOpt.Text = "Save"
		$frmoptions.Controls.Add($ButtonSaveOpt)
        $ButtonSaveOpt.add_click({ 

        set-ItemProperty -Path $key -Name "psexecPath" -Value $global:txtpsexec.text -Force
        set-ItemProperty -Path $key -Name "LogViewer" -Value $global:txtlogviewer.Text -Force
        set-ItemProperty -Path $key -Name "Rounds" -Value $global:txtrounds.Text -Force
        set-ItemProperty -Path $key -Name "AdditionalTime" -Value $global:txtquerytime.text -Force

        
        
        $frmoptions.close()
        
        })

        $ButtonDiscardOpt = New-Object System.Windows.Forms.Button
		$ButtonDiscardOpt.location = New-Object System.Drawing.Point(160,280)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonSave.Font = $FontBold
		$ButtonDiscardOpt.Size = New-Object System.Drawing.Size(80, 20)
		$ButtonDiscardOpt.Text = "Discard"
		$frmoptions.Controls.Add($ButtonDiscardOpt)
        
        $ButtonDiscardOpt.add_click({ $frmoptions.close()})

       $ButtonDefault = New-Object System.Windows.Forms.Button
		$ButtonDefault.location = New-Object System.Drawing.Point(35,280)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonDefault.Font = $FontBold
		$ButtonDefault.Size = New-Object System.Drawing.Size(120, 20)
		$ButtonDefault.Text = "Restore Defaults"
		$frmoptions.Controls.Add($ButtonDefault)
		$ButtonDefault.add_Click({


		regedit /s ./defaultkeys.reg
		$task_path = ".\tasks\*.xml"
		$task_user = "system"
		

		$sch = New-Object -ComObject("Schedule.Service")
		$sch.connect("localhost")
		$folder = $sch.GetFolder("\")

		Get-Item $task_path | %{
		  $task_name = $_.Name.Replace('.xml', '')
		  $task_xml = Get-Content $_.FullName

		  $task = $sch.NewTask($null)
		  
		  $task.XmlText = $task_xml

		  $folder.RegisterTaskDefinition($task_name, $task, 6, $task_user,$null, 1, $null)
		  
		}





		[System.Windows.Forms.MessageBox]::Show("Default settings applied. Script will now close. Please re-open.") 
		[environment]::exit(0)

		})

		$groupBox.Controls.Add($ButtonRun)
		$groupBox.Controls.Add($ButtonEnd)
		$groupBox.Controls.Add($ButtonEnable)
		$groupBox.Controls.Add($ButtonDisable)
        $groupBox.Controls.Add($global:lbltaskstatesuffix)
        $groupBox.Controls.Add($global:lbltaskstate)
        $frmoptions.Controls.Add($groupbox)
        $frmoptions.Controls.Add($timer1) 
        $frmoptions.Controls.Add($global:txtlogviewer)
        $frmoptions.Controls.Add($ButtonLogBrowse)
        $frmoptions.Controls.Add($lbleventlogviewer)
        $frmoptions.Controls.Add($lblpsexec)
        $frmoptions.Controls.Add($global:txtpsexec)
        $frmoptions.Controls.Add($ButtonPsexecBrowse)
        $frmoptions.Controls.Add($lblrounds)
        $frmoptions.Controls.Add($txtrounds)
        $frmoptions.Controls.Add($lblquerytime)
        $frmoptions.Controls.Add($global:txtquerytime)
        $frmoptions.Controls.Add($lbltask)

        $ButtonEnd.add_click({schtasks /end /tn Printerceptor })
        $ButtonRun.add_click({schtasks /run /tn Printerceptor })



        $ButtonEnable.add_click({
        ($TaskScheduler = New-Object -ComObject Schedule.Service).Connect("localhost")
        $MyTask = $TaskScheduler.GetFolder('\').GetTask("Printerceptor")
        $MyTask.Enabled = $true
        })


        $ButtonDisable.add_click({
        ($TaskScheduler = New-Object -ComObject Schedule.Service).Connect("localhost")
        $MyTask = $TaskScheduler.GetFolder('\').GetTask("Printerceptor")
        $MyTask.Enabled = $false
        })



        $ButtonLogBrowse.add_click({
      
       
       
      
        
        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
        $eventdialog = New-Object System.Windows.Forms.OpenFileDialog
        $eventdialog = New-Object System.Windows.Forms.OpenFileDialog
        $eventdialog.DefaultExt = '.ps1'
        $eventdialog.Filter = 'Executables|*.exe|All Files|*.*'
        $eventdialog.FilterIndex = 0
        $eventdialog.InitialDirectory = $home
        $eventdialog.Multiselect = $false
        $eventdialog.RestoreDirectory = $true
        $eventdialog.Title = "Select an executable"
        $eventdialog.ValidateNames = $true
        $eventdialog.ShowDialog()
        $filepath = $eventdialog.FileName
        if ($filepath -ne ""){$global:txtlogviewer.Text = """$filepath"""}
        
        })


  

        $ButtonPsexecBrowse.add_click({
        
        
        
        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
        $eventdialog = New-Object System.Windows.Forms.OpenFileDialog
        $eventdialog = New-Object System.Windows.Forms.OpenFileDialog
        $eventdialog.DefaultExt = '.ps1'
        $eventdialog.Filter = 'Executables|*.exe|All Files|*.*'
        $eventdialog.FilterIndex = 0
        $eventdialog.InitialDirectory = $home
        $eventdialog.Multiselect = $false
        $eventdialog.RestoreDirectory = $true
        $eventdialog.Title = "Select an executable"
        $eventdialog.ValidateNames = $true
        $eventdialog.ShowDialog()
        $filepath = $eventdialog.FileName
        if ($filepath -ne ""){$global:txtpsexec.Text = """$filepath"""}
        
        })
      








$frmoptions.ShowDialog()


        })















		$ButtonRestrictions.add_Click({
		
		$frmrestrictions = new-object system.windows.forms.form
		$frmrestrictions.width = 400
		$frmrestrictions.height = 425
		$frmrestrictions.MaximizeBox = $false
		$frmrestrictions.formborderstyle="FixedDialog"
		$frmrestrictions.text = "Printerceptor Restrictions"


		$ButtonRadd = New-Object System.Windows.Forms.Button
		$ButtonRadd.location = New-Object System.Drawing.Point(10,300)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonRadd.Font = $FontBold
		$ButtonRadd.Size = New-Object System.Drawing.Size(80, 20)
		$ButtonRadd.Text = "Add..."
		$frmrestrictions.Controls.Add($ButtonRadd)
       $ButtonRadd.add_Click({
       
       
       
                   Add-Type -Path (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath 'bin\CubicOrange.Windows.Forms.ActiveDirectory.dll')

            $DialogPicker = New-Object CubicOrange.Windows.Forms.ActiveDirectory.DirectoryObjectPickerDialog

            $DialogPicker.AllowedLocations = [CubicOrange.Windows.Forms.ActiveDirectory.Locations]::All
            #$DialogPicker.AllowedObjectTypes = [CubicOrange.Windows.Forms.ActiveDirectory.ObjectTypes]::Groups,[CubicOrange.Windows.Forms.ActiveDirectory.ObjectTypes]::Users,[CubicOrange.Windows.Forms.ActiveDirectory.ObjectTypes]::Computers
            $DialogPicker.DefaultLocations = [CubicOrange.Windows.Forms.ActiveDirectory.Locations]::JoinedDomain
            $DialogPicker.DefaultObjectTypes = [CubicOrange.Windows.Forms.ActiveDirectory.ObjectTypes]::Users,[CubicOrange.Windows.Forms.ActiveDirectory.ObjectTypes]::Groups
            $DialogPicker.ShowAdvancedView = $false
            $DialogPicker.MultiSelect = $true
            $DialogPicker.SkipDomainControllerCheck = $true
            $DialogPicker.Providers = [CubicOrange.Windows.Forms.ActiveDirectory.ADsPathsProviders]::Default

            $DialogPicker.AttributesToFetch.Add('samAccountName')
            $DialogPicker.AttributesToFetch.Add('title')
            $DialogPicker.AttributesToFetch.Add('department')
            $DialogPicker.AttributesToFetch.Add('distinguishedName')


            $DialogPicker.ShowDialog()

if ($DialogPicker.Selectedobject.Name -ne $null){

#Get the object SID

$uSid = [ADSI]$DialogPicker.SelectedObject.path

$binarySID = $uSid.ObjectSid.Value
# convert to string SID
$stringSID = (New-Object System.Security.Principal.SecurityIdentifier($binarySID,0)).Value
$stringSID 




$ListViewItem = New-Object System.Windows.Forms.ListViewItem($DialogPicker.Selectedobject.Name)
$ListViewItem.Subitems.Add($DialogPicker.Selectedobject.SchemaClassName) | Out-Null
$ListViewItem.Subitems.Add($stringSID) | Out-Null
if ($DialogPicker.SelectedObject.Path -match 'LDAP://'){$path = "AD"} else {$path = "Local"}
$ListViewItem.Subitems.Add($path) | Out-Null
           $ObjectList.items.add($ListViewItem) | out-null

}
return $DialogPicker.Selectedobject.Name
       
       
       
       
       
       
       
       
       
       
       })


		$ButtonRremove = New-Object System.Windows.Forms.Button
		$ButtonRremove.location = New-Object System.Drawing.Point(100,300)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonRremove.Font = $FontBold
		$ButtonRremove.Size = New-Object System.Drawing.Size(80, 20)
		$ButtonRremove.Text = "Remove"
		$frmrestrictions.Controls.Add($ButtonRremove)
		$ButtonRremove.add_Click({

		$ObjectList.SelectedItems[0].Remove()





		})

		$labelheader = New-Object System.Windows.Forms.Label
		$labelheader.location = New-Object System.Drawing.Point(10, 5)
		$labelheader.Size = New-Object System.Drawing.Size(320, 18)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$labelheader.Font = $FontBold
		$labelheader.Text = "Select which users and groups printerceptor may target:"
		$frmrestrictions.Controls.Add($labelheader)


		$groupBox = New-Object System.Windows.Forms.panel
		$groupBox.Location = New-Object System.Drawing.Size(10,10) 
		$groupBox.size = New-Object System.Drawing.Size(400,65)  
		$frmrestrictions.Controls.Add($groupBox) 


		$RadioButton1 = New-Object System.Windows.Forms.RadioButton 
		$RadioButton1.Location = new-object System.Drawing.Point(15,15) 
		$RadioButton1.size = New-Object System.Drawing.Size(380,33) 
		$RadioButton1.Checked = $true 
		$RadioButton1.Text = "All except the list below" 
		$groupBox.Controls.Add($RadioButton1)

		$RadioButton2 = New-Object System.Windows.Forms.RadioButton
		$RadioButton2.Location = new-object System.Drawing.Point(15,35)
		$RadioButton2.size = New-Object System.Drawing.Size(380,40)
		$RadioButton2.Text = "Only the list below"
		$groupBox.Controls.Add($RadioButton2)


		$labelsec = New-Object System.Windows.Forms.Label
		$labelsec.location = New-Object System.Drawing.Point(10, 85)
		$labelsec.Size = New-Object System.Drawing.Size(320, 12)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$labelheader.Font = $FontBold
		$labelsec.Text = "Security Objects:"
		$frmrestrictions.Controls.Add($labelsec)




		$ObjectList = New-Object System.Windows.Forms.ListView 
		$ObjectList.view  = [System.Windows.Forms.View]::Details
		$ObjectList.location = New-Object System.Drawing.Size(10,100) 
		$ObjectList.Size = New-Object System.Drawing.Size(365,190) 
		#$ObjectList.CheckBoxes = $true
        	$ObjectList.Columns.Add("Name",310)
		$ObjectList.Columns.Add("Type",50)
        $ObjectList.Columns.Add("SID",0)
         $ObjectList.Columns.Add("Path",0)
		#$ObjectList.enabled = $false

## Set up the event handler


## Event handler
function SortListView
{
 param([parameter(Position=0)][UInt32]$Column)
 
$Numeric = $true # determine how to sort
 
# if the user clicked the same column that was clicked last time, reverse its sort order. otherwise, reset for normal ascending sort
if($Script:LastColumnClicked -eq $Column)
{
    $Script:LastColumnAscending = -not $Script:LastColumnAscending
}
else
{
    $Script:LastColumnAscending = $true
}
$Script:LastColumnClicked = $Column
$ListItems = @(@(@())) # three-dimensional array; column 1 indexes the other columns, column 2 is the value to be sorted on, and column 3 is the System.Windows.Forms.ListViewItem object
 
foreach($ListItem in $ObjectList.Items)
{
    # if all items are numeric, can use a numeric sort
    if($Numeric -ne $false) # nothing can set this back to true, so don't process unnecessarily
    {
        try
        {
            $Test = [Double]$ListItem.SubItems[[int]$Column].Text
        }
        catch
        {
            $Numeric = $false # a non-numeric item was found, so sort will occur as a string
        }
    }
    $ListItems += ,@($ListItem.SubItems[[int]$Column].Text,$ListItem)
}
 
# create the expression that will be evaluated for sorting
$EvalExpression = {
    if($Numeric)
    { return [Double]$_[0] }
    else
    { return [String]$_[0] }
}
 
# all information is gathered; perform the sort
$ListItems = $ListItems | Sort-Object -Property @{Expression=$EvalExpression; Ascending=$Script:LastColumnAscending}
 
## the list is sorted; display it in the listview
$ObjectList.BeginUpdate()
$ObjectList.Items.Clear()
foreach($ListItem in $ListItems)
{
    $ObjectList.Items.Add($ListItem[1])
}
$ObjectList.EndUpdate()
}
 
$ObjectList.add_ColumnClick({SortListView $_.Column})
#load Objects
$Counter = -1
foreach ($item in $global:secname) {
$Counter++



#lookup the object by SID to see if the name changed

Add-Type -AssemblyName System.DirectoryServices.AccountManagement
   
      
#SID in next line is the group SID
if ($global:secpath[$Counter] -eq "AD"){
                    $ct = [System.DirectoryServices.AccountManagement.ContextType]::Domain
                    } else { $ct = [System.DirectoryServices.AccountManagement.ContextType]::Machine}
$uSid=[System.DirectoryServices.AccountManagement.Principal]::FindByIdentity($ct,$global:secsid[$Counter])




if ($global:sectype[$counter] -eq "user"){if (($uSid.displayName -ne $item) -and ($uSid.displayname -ne $null)){$item = $uSid.displayName }}
if ($global:sectype[$counter] -eq "group"){if (($uSid.name -ne $item) -and ($uSid.name -ne $null)){$item = $uSid.name }}

$ListViewItem = New-Object System.Windows.Forms.ListViewItem($item)
$ListViewItem.Subitems.Add($global:sectype[$counter]) | Out-Null
$ListViewItem.Subitems.Add($global:secsid[$Counter]) | Out-Null
$ListViewItem.Subitems.Add($global:secpath[$counter]) | Out-Null
         $ObjectList.items.Add($ListViewItem) | Out-Null
           }

		$frmrestrictions.Controls.Add($ObjectList)



		


		$allcheckbox = New-Object System.Windows.Forms.checkbox
		$allcheckbox.Location = New-Object System.Drawing.Size(10,330)
		$allcheckbox.Size = New-Object System.Drawing.Size(300,17)
		$allcheckbox.Checked = $true
		$allcheckbox.Text = "Target all users regardless of the list above"
		$frmrestrictions.Controls.Add($allcheckbox )
        $allcheckbox.add_click({ 
        if ($allcheckbox.Checked -eq $false) {
        $ObjectList.Enabled = $true
        $RadioButton1.Enabled = $true
        $RadioButton2.Enabled = $true
        $ButtonRremove.Enabled = $true
        $ButtonRadd.Enabled = $true
        }

        if ($allcheckbox.Checked -eq $true) {
        $ObjectList.Enabled = $false
        $RadioButton1.Enabled = $false
        $RadioButton2.Enabled = $false
        $ButtonRremove.Enabled = $false
        $ButtonRadd.Enabled = $false
        }
        
        })





		#$labelsep = New-Object System.Windows.Forms.Label
		#$labelsep.location = New-Object System.Drawing.Point(10, 350)
		#$labelsep.Size = New-Object System.Drawing.Size(363, 1)
		#$labelsep.borderstyle = 1
		#$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$labelsep.Font = $FontBold
		#$frmrestrictions.Controls.Add($labelsep)

		$ButtonResOk = New-Object System.Windows.Forms.Button
		$ButtonResOk.location = New-Object System.Drawing.Point(200,360)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonResOk.Font = $FontBold
		$ButtonResOk.Size = New-Object System.Drawing.Size(80, 20)
		$ButtonResOk.Text = "OK"
		$frmrestrictions.Controls.Add($ButtonResOk)
		$ButtonResOk.add_Click({
        
        if ($allcheckbox.Checked -eq $true) {$global:ScopeAll = "Yes"}
         if ($allcheckbox.Checked -eq $false) {$global:ScopeAll = "No"}
        if ($RadioButton1.Checked -eq $true) {$global:Scope =  "AllBut" }
        if ($RadioButton2.Checked -eq $true) {$global:Scope = "Only"}
        $global:secname = @()
        $global:sectype = @()
        $global:secsid = $null
       $global:secpath = $null
        foreach($item in $ObjectList.items) {$global:secname+= @($item.subitems[0].text); $global:sectype+= @($item.subitems[1].text); $global:secsid+= @($item.subitems[2].text); $global:secpath+= @($item.subitems[3].text); }


 & $CheckRestrictionExistance
         $frmrestrictions.close() 



		})


		$ButtonResCancel = New-Object System.Windows.Forms.Button
		$ButtonResCancel.location = New-Object System.Drawing.Point(292,360)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonResOk.Font = $FontBold
		$ButtonResCancel.Size = New-Object System.Drawing.Size(80, 20)
		$ButtonResCancel.Text = "Cancel"
		$frmrestrictions.Controls.Add($ButtonResCancel)
        $ButtonResCancel.add_Click({ $frmrestrictions.close() })



  


        if($global:Scope -eq "AllBut"){
        $RadioButton1.Checked = $true
        $RadioButton2.Enabled = $true
        $RadioButton1.Enabled = $true
        $ObjectList.Enabled =$true
        $ButtonRremove.Enabled = $true
        $ButtonRadd.Enabled = $true
        $allcheckbox.Checked = $false
        }


        if($global:Scope -eq "Only"){
        $RadioButton2.Checked = $true
        $RadioButton2.Enabled = $true
        $RadioButton1.Enabled = $true
        $ButtonRremove.Enabled = $true
        $ButtonRadd.Enabled = $true
        $ObjectList.Enabled =$true
        $allcheckbox.Checked = $false
        }


        if ($global:ScopeAll -eq "Yes"){
        $ObjectList.Enabled = $false
        $RadioButton2.Enabled = $false
        $RadioButton1.Enabled = $false
        $allcheckbox.Checked = $true
        $ButtonRremove.Enabled = $false
        $ButtonRadd.Enabled = $false
        }
		$frmrestrictions.showDialog()




		})

		$ButtonAddreg.add_Click({


		$duplicate = 0
		foreach ($item in $comboBox2.Items){

		if ($item -eq $comboBox2.Text) {$duplicate++}}
		if($duplicate -lt 1) {$comboBox2.Items.Add($comboBox2.Text)}
		})


		$ButtonSub.Add_Click({

		$comboBox1.Items.Remove($comboBox1.Text)

		if ($comboBox1.Items.Count -ne 0){
		$comboBox1.set_SelectedIndex(0)
		} else {
		$comboBox1.text = ""
		}
		})
		$ButtonSubreg.Add_Click({

		$comboBox2.Items.Remove($comboBox2.Text)

		if ($comboBox2.Items.Count -ne 0){
		$comboBox2.set_SelectedIndex(0)
		} else {
		$comboBox2.text = ""
		}

		})


		
		$ButtonPrintMGR.add_Click({
		cd "C:\Program Files\Printerceptor"
        $PSEXEC = Get-ItemProperty -Path $key -Name "psexecPath" | foreach { $_.psexecPath }
         try {
 		        Start-Process  $PSEXEC  -ArgumentList "-s -i -d mmc C:\windows\system32\printmanagement.msc" 
         }
         catch
         {
		        [System.Windows.Forms.MessageBox]::Show("psexec.exe must exist to launch as system account, please download and specify path in 'options'. You can get it here: https://technet.microsoft.com/en-us/sysinternals/bb897553.aspx . Print Management will now start as logged in user, which is pretty useless.")
		        Start-Process printmanagement.msc
		        }

		
		
		})
		$ButtonSave.add_Click({
			if ($firstrun -eq '1'){
        set-ItemProperty -Path $key -Name "FirstRun" -Value "0"  -Force
       
        ($TaskScheduler = New-Object -ComObject Schedule.Service).Connect("localhost")
$MyTask = $TaskScheduler.GetFolder('\').GetTask("Printerceptor")
$MyTask.Enabled = $true
        
        
        
        
        
        
        }



		write-host $DoNotRenameList.CheckedItems
		$DoNotListRenameListOutput = $null
		$RecreateListOutput = $null
		$PrinterFormatListOutput = $null
		#Save Do Not Renamelist
		foreach($itema in $DoNotRenameList.CheckedItems) {$DoNotListRenameListOutput+= @($itema.text)}
		set-ItemProperty -Path $key -Name "DoNotRenList" -Value $DoNotListRenameListOutput  -Force
		#save Recreates full list 
		foreach($itemb in $RecreateList.CheckedItems) {$RecreateListOutput+= @($itemb.text)}
		set-ItemProperty -Path $key -Name "RecreateFullList" -Value $RecreateListOutput -Force

	

		#see if name format isn't currently part of list

		$exists = $false
		foreach($item in $comboBox1.Items){
		if ($comboBox1.text -eq $item) { $exists = $true; break}
		}


		#save printerformat
		foreach($item in $comboBox1.Items) {$PrinterFormatListOutput+= @($item)}
		if ($exists -eq $false){
		$PrinterFormatListOutput+= @($comboBox1.text)
		}
		set-ItemProperty -Path $key -Name "NamingFormatList" -Value $PrinterFormatListOutput -Force
		

        #Save Advanced Policy
        remove-item -Path HKLM:\SOFTWARE\Printerceptor\Active\AdvancedPolicy -Recurse
        Copy-Item -Path HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy -Destination HKLM:\SOFTWARE\Printerceptor\Active -Recurse

        #Save restriction Information
        set-ItemProperty -Path $key -Name "ScopeAll" -Value $global:ScopeAll  -Force
        set-ItemProperty -Path $key -Name "Scope" -Value $global:Scope  -Force
        set-ItemProperty -Path $key -Name "SecName" -Value $global:secname  -Force
        set-ItemProperty -Path $key -Name "sectype" -Value $global:sectype  -Force
        set-ItemProperty -Path $key -Name "SecSID" -Value $global:secsid  -Force
       set-ItemProperty -Path $key -Name "SecPath" -Value $global:secpath  -Force

		#save RedirectedExpressionList
		$exists= $false
		foreach($item in $comboBox2.Items){
		if ($comboBox2.text -eq $item) { $exists = $true; break}
		}

		foreach($item in $comboBox2.Items) {$RedirectedExpressionListOutput+= @($item)}
		if ($exists -eq $false){
		$RedirectedExpressionListOutput+= @($comboBox2.text)
		}
		set-ItemProperty -Path $key -Name "RedirectedExpressionList" -Value $RedirectedExpressionListOutput -Force


		#Save Printer Name Format
		set-ItemProperty -Path $key -Name "NamingFormat" -Value $comboBox1.Text -Force

		#Save RedirectedExpression
		set-ItemProperty -Path $key -Name "RedirectedExpression" -Value $comboBox2.Text -Force

		[environment]::exit(0)

		})






		 $Form.add_Closed({ [environment]::exit(0) })





#Advanced Policy Start
$ButtonAdvancedPolicy.add_Click({
       $frmAdvancedPolicy = new-object system.windows.forms.form
		$frmAdvancedPolicy.width = 642
		$frmAdvancedPolicy.height = 445
		$frmAdvancedPolicy.MaximizeBox = $false
		$frmAdvancedPolicy.formborderstyle="FixedDialog"
		$frmAdvancedPolicy.text = "Printerceptor Advanced Policy"

		$AdvancedPolicyList = New-Object System.Windows.Forms.listview
		$AdvancedPolicyList.location = New-Object System.Drawing.Size(5,5) 
		$AdvancedPolicyList.Size = New-Object System.Drawing.Size(545,370) 
		#$AdvancedPolicyList.CheckBoxes = $true
		$AdvancedPolicyList.Columns.Add("Name",385)
        $AdvancedPolicyList.Columns.Add("Priority",55)
        $AdvancedPolicyList.Columns.Add("Enabled",100)
		$AdvancedPolicyList.View = [System.Windows.Forms.View]::details

#$AdvancedPolicyList.Items.Add("Non Full Access Enabled")
#$AdvancedPolicyList.Subitems.Add("Non Full Access Enabled")

$loadpolicy = {
$AdvancedPolicyList.items.Clear()
$policies = Get-ChildItem -Path "HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy" 
$policies = $policies | Foreach-Object {Get-ItemProperty $_.PsPath } | Sort-Object priority | foreach { $_.pschildname}
    foreach ($policy in $policies){
    $policypath = "HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy\" + $policy
    $enabledstate = Get-ItemProperty -Path $policypath -Name "Enabled" | select -ExpandProperty Enabled
    if ($enabledstate -eq 1) {$policyenabledvalue = "Yes"} else {$policyenabledvalue = "No"}
   
    #get the priority
    $priority = (get-ItemProperty -Path $policypath).priority
    $policydescription = (get-ItemProperty -Path $policypath).description
    $ListViewItem = New-Object System.Windows.Forms.ListViewItem($policy)
    $ListViewItem.Subitems.Add($priority) | Out-Null
    $ListViewItem.Subitems.Add($policyenabledvalue) | Out-Null
   
  
   if ($enabledstate -eq "1"){
    $AdvancedPolicyList.items.Add($ListViewItem)
   }else {
   $AdvancedPolicyList.items.Add($ListViewItem)

   }
     & $resetpriority
     
    }

}

& $loadpolicy
$resetpriority = 
{
            #reset the priority
            foreach ($item in $AdvancedPolicyList.Items)
            {

           # if ($Orderdirection -eq "up") {$newindex = $item.Index + 1}
            #if ($Orderdirection -eq "down") {$newindex = $item.Index - 1}
            $newindex = $item.Index + 1
                $item.SubItems[1].Text = $newindex
            #write the new priority to registry
            $key = "HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy\" + $item.text
            set-ItemProperty -Path $key -Name "priority" -Value $newindex  -Force

           
            }
}



$AdvancedPolicyUp= New-Object System.Windows.Forms.Button
$AdvancedPolicyUp.location = New-Object System.Drawing.Point(555,110)
$FontBold = new-object System.Drawing.Font("Arial",14 )
$AdvancedPolicyUp.Font = $FontBold
$AdvancedPolicyUp.Size = New-Object System.Drawing.Size(65, 65)
$AdvancedPolicyUp.Text = "UP"

$AdvancedPolicyDown= New-Object System.Windows.Forms.Button
$AdvancedPolicyDown.location = New-Object System.Drawing.Point(555,190)
$FontBold = new-object System.Drawing.Font("Arial",14 )
$AdvancedPolicyDown.Font = $FontBold
$AdvancedPolicyDown.Size = New-Object System.Drawing.Size(65, 65)
$AdvancedPolicyDown.font.Size = 54
$AdvancedPolicyDown.Text = "Down"


$AdvancedPolicyDelete = New-Object System.Windows.Forms.Button
$AdvancedPolicyDelete.location = New-Object System.Drawing.Point(440,380)
$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
#$ButtonResOk.Font = $FontBold
$AdvancedPolicyDelete.Size = New-Object System.Drawing.Size(50, 20)
$AdvancedPolicyDelete.Text = "Delete"
$AdvancedPolicyDelete.add_Click({
#delete the policy
$message = "Are you sure you want to delete policy: '" + $AdvancedPolicyList.Selecteditems[0].Text + "'?"
$OUTPUT= [System.Windows.Forms.MessageBox]::Show($message , "Delete Policy" , 4) 
if ($OUTPUT -eq "YES" ) 
{
     $selecteditem = $AdvancedPolicyList.Selecteditems[0].Text
            $selected = $AdvancedPolicyList.Selecteditems[0]
foreach ($item in $AdvancedPolicyList.Items)
                {
    
                    if ($item.text -eq $selecteditem){
                    
                        $AdvancedPolicyList.items.removeat($item.Index)
                        #delete the key
                        $path = "HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy\" + $selecteditem
                        Remove-Item -Path $path -Force
                         & $resetpriority
                    }
} 
}
else 
{ 

} 


#& $AdvancedPolicyOrdering
})

 #[System.Windows.Forms.MessageBox]::Show($AdvancedPolicyList.Items.Count, 'Name Required', 'Ok', 'Warning')

$AdvancedPolicyOrdering = 
{ 
 $AdvancedPolicyLowestIndex = ($AdvancedPolicyList.Items.Count) -1
$halted = $false
               if ($Orderdirection -eq "up") {
             if($AdvancedPolicyList.Selecteditems[0].Index -eq 0){ $halted = $true; }
             $value = -1
             }
             if ($Orderdirection -eq "down") {
             if($AdvancedPolicyList.Selecteditems[0].Index -eq $AdvancedPolicyLowestIndex){ $halted = $true}
             $value = 1
             }
             #determine what is selected
            $selecteditem = $AdvancedPolicyList.Selecteditems[0].Text
            $selected = $AdvancedPolicyList.Selecteditems[0]

            #move up if it isn't already at the top or total bottom

           

            if($halted -eq $false)
            {
                foreach ($item in $AdvancedPolicyList.Items)
                {
    
                    if ($item.text -eq $selecteditem){
                        $newindex = $AdvancedPolicyList.SelectedItems[0].Index + $value
                        $AdvancedPolicyList.items.removeat($item.Index)
                        $AdvancedPolicyList.items.Insert($newindex, $item)
                    }
                }

            }


            & $resetpriority
            #retain focused selection highlighting
           $AdvancedPolicyList.Focus()


}


$AdvancedPolicyUp.add_Click({
$Orderdirection = "up"
& $AdvancedPolicyOrdering
})
$AdvancedPolicyDown.add_Click({
$Orderdirection = "down"
& $AdvancedPolicyOrdering
})

$AdvancedPolicyAdd = New-Object System.Windows.Forms.Button
$AdvancedPolicyAdd.location = New-Object System.Drawing.Point(320,380)
$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
#$ButtonResOk.Font = $FontBold
$AdvancedPolicyAdd.Size = New-Object System.Drawing.Size(50, 20)
$AdvancedPolicyAdd.Text = "Add"

$AdvancedPolicyOk = New-Object System.Windows.Forms.Button
$AdvancedPolicyOk.location = New-Object System.Drawing.Point(498,380)
$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
#$ButtonResOk.Font = $FontBold
$AdvancedPolicyOk.Size = New-Object System.Drawing.Size(50, 20)
$AdvancedPolicyOk.Text = "Ok"
$AdvancedPolicyOk.add_Click({



#Enable/Disable policy

#foreach ($item in $AdvancedPolicyList.CheckedItems)
#{
#$PolicyPath = "HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy\" + $item.text
#New-Itemproperty -Path $PolicyPath -Name "Enabled" -Value "1" -PropertyType "DWord" -Force
#}



$unchecked=$AdvancedPolicyList.Items | ?{$AdvancedPolicyList.CheckedItems -notcontains $_}

#foreach ($item in $unchecked)
#{
#$PolicyPath = "HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy\" + $item.text
#New-Itemproperty -Path $PolicyPath -Name "Enabled" -Value "0" -PropertyType "DWord" -Force
#}


& $CheckAdvancedPolicyExistance
$frmAdvancedPolicy.Close()
})

$AdvancedPolicyEdit = New-Object System.Windows.Forms.Button
$AdvancedPolicyEdit.location = New-Object System.Drawing.Point(380,380)
$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
#$ButtonResOk.Font = $FontBold
$AdvancedPolicyEdit.Size = New-Object System.Drawing.Size(50, 20)
$AdvancedPolicyEdit.Text = "Edit"

$frmAdvancedPolicy.Controls.Add($AdvancedPolicyEdit)
$frmAdvancedPolicy.Controls.Add($AdvancedPolicyUp)
$frmAdvancedPolicy.Controls.Add($AdvancedPolicyDown)
$frmAdvancedPolicy.Controls.Add($AdvancedPolicyAdd)
$frmAdvancedPolicy.Controls.Add($AdvancedPolicyDelete)
$frmAdvancedPolicy.Controls.Add($AdvancedPolicyOk)
#$frmAdvancedPolicy.Controls.Add($AdvancedPolicyDown)
$AdvancedPolicyAdd.add_Click({
$policyaction = "add"
& $scriptblock

})



   $advancedpolicylist.add_click({
 

   

foreach ($items in $AdvancedPolicyList.CheckedItems){
$global:doubleselect = $false
    if ($items.text -eq ($AdvancedPolicyList.Selecteditems[0]).Text) { 
 $global:doubleselect = $true; break;}
}
   })

   
$AdvancedPolicyEdit.add_Click({
if ($AdvancedPolicyList.Selecteditems[0].Text -ne $null){

$policyaction = "Edit"
& $scriptblock
}


})


$AdvancedPolicyList.add_doubleclick({
#($AdvancedPolicyList.Selecteditems[0]).Checked = $true
if ($AdvancedPolicyList.Selecteditems[0].Text -ne $null){
        if ($global:doubleselect -eq $true){ ($AdvancedPolicyList.Selecteditems[0]).Checked = $true } 
        if ($global:doubleselect -eq $false) {($AdvancedPolicyList.Selecteditems[0]).Checked = $false}
        
$policyaction = "Edit"
& $scriptblock
}
})





$objectlist_MouseDoubleClick=[System.Windows.Forms.MouseEventHandler]{
#Event Argument: $_ = [System.Windows.Forms.MouseEventArgs]
	#TODO: Place custom script here
	$hit = $objectlist.HitTest($_.Location)
	if($hit.Item)
	{
		$hit.Item #item clicked
		$hit.SubItem #sub item clicked

if ($AdvancedPolicyList.Selecteditems[0].Text -ne $null){
$policyaction = "Edit"
& $scriptblock
}
	}
	
}


$frmAdvancedPolicy.controls.add($AdvancedPolicyList)
$frmAdvancedPolicy.ShowDialog()



})

#Advanced Policy Stop


#Policy Management Start

$scriptblock = 
{ 

        #load values from regsitry if editing
        if ($policyaction -eq "edit"){
        $key =  "HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy\" + $AdvancedPolicyList.Selecteditems[0].Text
        $txtpolicydescription = Get-ItemProperty -Path $key -Name "Description" | select -ExpandProperty Description
        $CondPrinterName = Get-ItemProperty -Path $key -Name "CondPrinterName" | select -ExpandProperty CondPrinterName
        $CondPrinterDriver = Get-ItemProperty -Path $key -Name "CondPrinterDriver" | select -ExpandProperty CondPrinterDriver
        $CondPrinterIsDefault = Get-ItemProperty -Path $key -Name "CondPrinterIsDefault" | select -ExpandProperty CondPrinterIsDefault
        $CondPrinterUser = Get-ItemProperty -Path $key -Name "CondPrinterUser" | select -ExpandProperty CondPrinterUser
        $ActSetDefault = Get-ItemProperty -Path $key -Name "ActSetDefault" | select -ExpandProperty ActSetDefault
        $ActDeletePrinter = Get-ItemProperty -Path $key -Name "ActDeletePrinter" | select -ExpandProperty ActDeletePrinter
        $CondPrinterNameSelection = Get-ItemProperty -Path $key -Name "CondPrinterNameSelection" | select -ExpandProperty CondPrinterNameSelection
        $CondPrinterDriverSelection = Get-ItemProperty -Path $key -Name "CondPrinterDriverSelection" | select -ExpandProperty CondPrinterDriverSelection
        $ActDefaultPrinterSelection =  Get-ItemProperty -Path $key -Name "ActDefaultPrinterSelection" | select -ExpandProperty ActDefaultPrinterSelection
        $ActDeletePrinterSelection = Get-ItemProperty -Path $key -Name "ActDeletePrinterSelection" | select -ExpandProperty ActDeletePrinterSelection
       
         $CondPrinterClientSelection = Get-ItemProperty -Path $key -Name "CondPrinterClientSelection" | select -ExpandProperty CondPrinterClientSelection
        $CondPrinterClient = Get-ItemProperty -Path $key -Name "CondPrinterClient" | select -ExpandProperty CondPrinterClient
          $ActRename =  Get-ItemProperty -Path $key -Name "ActRename" | select -ExpandProperty ActRename
        $ActRecreate = Get-ItemProperty -Path $key -Name "ActRecreate" | select -ExpandProperty ActRecreate
        $Policyname = $AdvancedPolicyList.Selecteditems[0].Text
        $Policydescription = Get-ItemProperty -Path $key -Name "Description" | select -ExpandProperty Description
        $NextPrirority = Get-ItemProperty -Path $key -Name "priority" | select -ExpandProperty priority
        $policyenabled = Get-ItemProperty -Path $key -Name "enabled" | select -ExpandProperty enabled
        $PolicyEnable = $policyenabled


        [array]$global:AdvSecName = Get-ItemProperty -Path $key -Name "SecName" | select -ExpandProperty SecName
        [array]$global:Advsectype = Get-ItemProperty -Path $key -Name "sectype" | select -ExpandProperty sectype
        [array]$global:Advsecsid = Get-ItemProperty -Path $key -Name "SecSID" | select -ExpandProperty SecSID 
        [array]$global:Advsecpath = Get-ItemProperty -Path $key -Name "SecPath" | select -ExpandProperty SecPath
        

        }
        $frmPolicyManagement = new-object system.windows.forms.form
		$frmPolicyManagement.width = 650
		$frmPolicyManagement.height = 625
		$frmPolicyManagement.MaximizeBox = $false
		$frmPolicyManagement.formborderstyle="FixedDialog"
		$frmPolicyManagement.text = "Printerceptor Policy - " + $policyaction


		$labelPolicyName = New-Object System.Windows.Forms.Label
		$labelPolicyName.location = New-Object System.Drawing.Point(5, 10)
		$labelPolicyName.Size = New-Object System.Drawing.Size(80, 15)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$labelPolicyName.Font = $FontBold
		$labelPolicyName.Text = "Policy Name:"


        $txtpolicyname = New-Object System.Windows.Forms.TextBox 
        $txtpolicyname.Location = New-Object System.Drawing.Point(90,8) 
        $txtpolicyname.Size = New-Object System.Drawing.Size(390,20) 
        $txtpolicyname.Text = $Policyname


		$labelPolicyDescription = New-Object System.Windows.Forms.Label
		$labelPolicyDescription.location = New-Object System.Drawing.Point(28, 40)
		$labelPolicyDescription.Size = New-Object System.Drawing.Size(60, 15)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$labelPolicyDescription.Font = $FontBold
		$labelPolicyDescription.Text = "Enabled:"

		$labelConditions = New-Object System.Windows.Forms.Label
		$labelConditions.location = New-Object System.Drawing.Point(5, 90)
		$labelConditions.Size = New-Object System.Drawing.Size(70, 15)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$labelConditions.Font = $FontBold
		$labelConditions.Text = "Conditions:"


        #$txtpolicydescription = New-Object System.Windows.Forms.TextBox 
        #$txtpolicydescription.Location = New-Object System.Drawing.Point(90,39) 
        #$txtpolicydescription.Size = New-Object System.Drawing.Size(300,15)
        #$txtpolicydescription.Text = $Policydescription


        $PolicyEnableState = New-Object System.Windows.Forms.checkbox
		$PolicyEnableState.Location =  New-Object System.Drawing.Point(90,39) 
		$PolicyEnableState.Size = New-Object System.Drawing.Size(300,17)
        if ($PolicyEnable -eq 1) {  $PolicyEnableState.Checked = $true} else { $PolicyEnableState.Checked = $false}
		$PolicyEnableState.Text = ""
        #$PolicyEnableState.Add_CheckStateChanged({if ($PolicyEnable.Checked -eq $true){$txtdefaultprinter.Enabled = $true} else {$txtdefaultprinter.Enabled = $false}}) 
  

  		$ConditionPrinterName = New-Object System.Windows.Forms.checkbox
		$ConditionPrinterName.Location = New-Object System.Drawing.Size(5,120)
		$ConditionPrinterName.Size = New-Object System.Drawing.Size(300,17)
		if ($CondPrinterName -eq 1) {  $ConditionPrinterName.Checked = $true} else { $ConditionPrinterName.Checked = $false}
		$ConditionPrinterName.Text = "Printer name matches one of following expressions:"
        $ConditionPrinterName.Add_CheckStateChanged({if ($ConditionPrinterName.Checked -eq $true){$txtPrinterNames.Enabled = $true} else {$txtPrinterNames.Enabled = $false}})

        $txtPrinterNames = New-Object System.Windows.Forms.TextBox 
        $txtPrinterNames.Location = New-Object System.Drawing.Point(5,140) 
        $txtPrinterNames.Size = New-Object System.Drawing.Size(300,100)
        $txtPrinterNames.Multiline = $true
        $txtPrinterNames.Text = $CondPrinterNameSelection
      
        if ($CondPrinterName -eq 1) { $txtprinterNames.enabled = $true} else {$txtprinterNames.enabled = $false}

  		$ConditionPrinterDriver = New-Object System.Windows.Forms.checkbox
		$ConditionPrinterDriver.Location = New-Object System.Drawing.Size(5,260)
		$ConditionPrinterDriver.Size = New-Object System.Drawing.Size(300,17)
		if ($CondPrinterDriver -eq 1) {  $ConditionPrinterDriver.Checked = $true} else { $ConditionPrinterDriver.Checked = $false}
		$ConditionPrinterDriver.Text = "Printer driver is one of the following:"
        $ConditionPrinterDriver.Add_CheckStateChanged({if ($ConditionPrinterDriver.Checked -eq $true){$txtprinterdrivers.enabled = $true} else {$txtprinterdrivers.enabled = $false}})        


        $txtprinterdrivers = New-Object System.Windows.Forms.listview 
        $txtprinterdrivers.Location = New-Object System.Drawing.Point(5,280) 
        $txtprinterdrivers.Size = New-Object System.Drawing.Size(300,100)
        $txtprinterdrivers.Multiline = $true
        $txtprinterdrivers.Text = $CondPrinterDriverSelection
        $txtprinterdrivers.CheckBoxes = $true

        foreach ($Driver in $Drivers) 
			{ 
                $checked = $false
                $Drivername = $($Driver.Name).split(",")
                 foreach ($item in $CondPrinterDriverSelection) { if ($drivername -eq $item) { $checked = $true; break;}}
				
                if ($checked -eq $true) { $txtprinterdrivers.Items.Add($Drivername).Checked = $true} else {$txtprinterdrivers.Items.Add($Drivername)}
            }

		$txtprinterdrivers.Columns.Add("Driver",279)

        $txtprinterdrivers.View = [System.Windows.Forms.View]::details
        if ($CondPrinterDriver -eq 1) { $txtprinterdrivers.enabled = $true} else { $txtprinterdrivers.enabled = $false;}



        $ConditionPrinterClient = New-Object System.Windows.Forms.checkbox
		$ConditionPrinterClient.Location = New-Object System.Drawing.Size(329,120)
		$ConditionPrinterClient.Size = New-Object System.Drawing.Size(300,17)
		if ($CondPrinterClient -eq 1) {  $ConditionPrinterClient.Checked = $true} else { $ConditionPrinterClient.Checked = $false}
		$ConditionPrinterClient.Text = "Client name is one of the following:"
        $ConditionPrinterClient.Add_CheckStateChanged({if ($ConditionPrinterClient.Checked -eq $true){$txtprinterclient.Enabled = $true} else {$txtprinterclient.Enabled = $false}})


        #printer is a default

        $ConditionPrinterIsDefault = New-Object System.Windows.Forms.checkbox
		$ConditionPrinterIsDefault.Location = New-Object System.Drawing.Size(5,398)
		$ConditionPrinterIsDefault.Size = New-Object System.Drawing.Size(300,17)
		$ConditionPrinterIsDefault.Text = "Printer is set as default"
        if ($CondPrinterIsDefault -eq 1) {  $ConditionPrinterIsDefault.Checked = $true} else { $ConditionPrinterIsDefault.Checked = $false}
       
        ###
        $txtprinterclient = New-Object System.Windows.Forms.listview 
        $txtprinterclient.Location = New-Object System.Drawing.Point(329,140) 
        $txtprinterclient.Size = New-Object System.Drawing.Size(300,100)
        $txtprinterclient.Multiline = $true
        $txtprinterclient.Text = $CondPrinterDriverSelection
        $txtprinterclient.CheckBoxes = $true
        $txtprinterclient.Columns.Add("Client Name",278)
        $txtprinterclient.View = [System.Windows.Forms.View]::details
        if ($CondPrinterClient -eq 1) { $txtprinterclient.enabled = $true} else { $txtprinterclient.enabled = $false;}
               
               
          #client client name list

         $clientnames = import-csv "C:\Program Files\Printerceptor\Log.csv"  | % {$_."Client Name"} | group-object | sort-object name |  foreach { $_.Name }
         foreach ($client in $clientnames){


         if ($client -ne ""){
                  $checked = $false
                        $Drivername = $($Driver.Name).split(",")
                         foreach ($item in $CondPrinterClientSelection) { if ($client -eq $item) { $checked = $true; break;}}
				
                        if ($checked -eq $true) { $txtprinterclient.Items.Add($client).Checked = $true} else {$txtprinterclient.Items.Add($client)}


        

                 }
         }

         #user scope
        $ConditionPrinterUser = New-Object System.Windows.Forms.checkbox
		$ConditionPrinterUser.Location = New-Object System.Drawing.Size(329,260)
		$ConditionPrinterUser.Size = New-Object System.Drawing.Size(300,17)
	
		$ConditionPrinterUser.Text = "User or group is one of the following:"
      


		$AdvObjectList = New-Object System.Windows.Forms.ListView 
		$AdvObjectList.view  = [System.Windows.Forms.View]::Details
		$AdvObjectList.location = New-Object System.Drawing.Size(329,280) 
		$AdvObjectList.Size = New-Object System.Drawing.Size(300,100) 
		#$ObjectList.CheckBoxes = $true
        	$AdvObjectList.Columns.Add("Name",245)
		$AdvObjectList.Columns.Add("Type",50)
        $AdvObjectList.Columns.Add("SID",0)
         $AdvObjectList.Columns.Add("Path",0)
         	if ($CondPrinterUser  -eq 1) {  $ConditionPrinterUser.Checked = $true} else { $ConditionPrinterUser.Checked = $false}
           $ConditionPrinterUser.Add_CheckStateChanged({if ($ConditionPrinterUser.Checked -eq $true){$AdvObjectList.Enabled = $true} else {$AdvObjectList.Enabled = $false}})
                 if ($CondPrinterUser -eq 1) { $AdvObjectList.enabled = $true} else { $AdvObjectList.enabled = $false;}
         #



		$AdvButtonRadd = New-Object System.Windows.Forms.Button
		$AdvButtonRadd.location = New-Object System.Drawing.Point(448,385)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonRadd.Font = $FontBold
		$AdvButtonRadd.Size = New-Object System.Drawing.Size(80, 20)
		$AdvButtonRadd.Text = "Add..."
		$frmrestrictions.Controls.Add($AdvButtonRadd)
       $AdvButtonRadd.add_Click({
       
       
       
                   Add-Type -Path (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath 'bin\CubicOrange.Windows.Forms.ActiveDirectory.dll')

            $DialogPicker = New-Object CubicOrange.Windows.Forms.ActiveDirectory.DirectoryObjectPickerDialog

            $DialogPicker.AllowedLocations = [CubicOrange.Windows.Forms.ActiveDirectory.Locations]::All
            #$DialogPicker.AllowedObjectTypes = [CubicOrange.Windows.Forms.ActiveDirectory.ObjectTypes]::Groups,[CubicOrange.Windows.Forms.ActiveDirectory.ObjectTypes]::Users,[CubicOrange.Windows.Forms.ActiveDirectory.ObjectTypes]::Computers
            $DialogPicker.DefaultLocations = [CubicOrange.Windows.Forms.ActiveDirectory.Locations]::JoinedDomain
            $DialogPicker.DefaultObjectTypes = [CubicOrange.Windows.Forms.ActiveDirectory.ObjectTypes]::Users,[CubicOrange.Windows.Forms.ActiveDirectory.ObjectTypes]::Groups
            $DialogPicker.ShowAdvancedView = $false
            $DialogPicker.MultiSelect = $true
            $DialogPicker.SkipDomainControllerCheck = $true
            $DialogPicker.Providers = [CubicOrange.Windows.Forms.ActiveDirectory.ADsPathsProviders]::Default

            $DialogPicker.AttributesToFetch.Add('samAccountName')
            $DialogPicker.AttributesToFetch.Add('title')
            $DialogPicker.AttributesToFetch.Add('department')
            $DialogPicker.AttributesToFetch.Add('distinguishedName')


            $DialogPicker.ShowDialog()

if ($DialogPicker.Selectedobject.Name -ne $null){

#Get the object SID

$uSid = [ADSI]$DialogPicker.SelectedObject.path

$binarySID = $uSid.ObjectSid.Value
# convert to string SID
$stringSID = (New-Object System.Security.Principal.SecurityIdentifier($binarySID,0)).Value
$stringSID 




$AdvListViewItem = New-Object System.Windows.Forms.ListViewItem($DialogPicker.Selectedobject.Name)
$AdvListViewItem.Subitems.Add($DialogPicker.Selectedobject.SchemaClassName) | Out-Null
$AdvListViewItem.Subitems.Add($stringSID) | Out-Null
if ($DialogPicker.SelectedObject.Path -match 'LDAP://'){$path = "AD"} else {$path = "Local"}
$ListViewItem.Subitems.Add($path) | Out-Null
           $AdvObjectList.items.add($AdvListViewItem) 

}
return $DialogPicker.Selectedobject.Name
       
       
       
       
       
       
       
       
       
       
       })



       #adv security remove button


       
		$AdvButtonRremove = New-Object System.Windows.Forms.Button
		$AdvButtonRremove.location = New-Object System.Drawing.Point(538,385)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonRremove.Font = $FontBold
		$AdvButtonRremove.Size = New-Object System.Drawing.Size(90, 20)
		$AdvButtonRremove.Text = "Remove"
		$AdvButtonRremove.add_Click({

		$AdvObjectList.SelectedItems[0].Remove()





		})



$Counter = -1

if ($policyaction -eq "edit"){
foreach ($item in $global:Advsecname) {
$Counter++



#lookup the object by SID to see if the name changed

Add-Type -AssemblyName System.DirectoryServices.AccountManagement
   
      
#SID in next line is the group SID
if ($global:Advsecpath[$Counter] -eq "AD"){
                    $ct = [System.DirectoryServices.AccountManagement.ContextType]::Domain
                    } else { $ct = [System.DirectoryServices.AccountManagement.ContextType]::Machine}
$uSid=[System.DirectoryServices.AccountManagement.Principal]::FindByIdentity($ct,$global:Advsecsid[$Counter])




if ($global:Advsectype[$counter] -eq "user"){if (($uSid.displayName -ne $item) -and ($uSid.displayname -ne $null)){$item = $uSid.displayName }}
if ($global:Advsectype[$counter] -eq "group"){if (($uSid.name -ne $item) -and ($uSid.name -ne $null)){$item = $uSid.name }}

$AdvListViewItem = New-Object System.Windows.Forms.ListViewItem($item)
$AdvListViewItem.Subitems.Add($global:Advsectype[$counter]) | Out-Null
$AdvListViewItem.Subitems.Add($global:Advsecsid[$Counter]) | Out-Null
$AdvListViewItem.Subitems.Add($global:Advsecpath[$counter]) | Out-Null
         $AdvObjectList.items.Add($AdvListViewItem) | Out-Null
           }
}

###

































         #

        #Actions
		$labelActions = New-Object System.Windows.Forms.Label
		$labelActions.location = New-Object System.Drawing.Point(5, 420)
		$labelActions.Size = New-Object System.Drawing.Size(70, 15)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		$labelActions.Font = $FontBold
		$labelActions.Text = "Actions:"

  		$ActionRenamePrinter = New-Object System.Windows.Forms.checkbox
		$ActionRenamePrinter.Location = New-Object System.Drawing.Size(5,440)
		$ActionRenamePrinter.Size = New-Object System.Drawing.Size(300,17)
        if ($ActRename -eq 1) {  $ActionRenamePrinter.Checked = $true} else { $ActionRenamePrinter.Checked = $false}
        $ActionRenamePrinter.Text = "Rename"

  		$ActionRecreatePrinter = New-Object System.Windows.Forms.checkbox
		$ActionRecreatePrinter.Location = New-Object System.Drawing.Size(5,470)
		$ActionRecreatePrinter.Size = New-Object System.Drawing.Size(300,17)
        if ($ActRecreate -eq 1) {  $ActionRecreatePrinter.Checked = $true} else { $ActionRecreatePrinter.Checked = $false}
        $ActionRecreatePrinter.Text = "Recreate"

  		$ActionSetDefault = New-Object System.Windows.Forms.checkbox
		$ActionSetDefault.Location = New-Object System.Drawing.Size(5,500)
		$ActionSetDefault.Size = New-Object System.Drawing.Size(300,17)
        if ($ActSetDefault -eq 1) {  $ActionSetDefault.Checked = $true} else { $ActionSetDefault.Checked = $false}
		$ActionSetDefault.Text = "If default, shift default to:"
        $ActionSetDefault.Add_CheckStateChanged({if ($ActionSetDefault.Checked -eq $true){$txtdefaultprinter.Enabled = $true} else {$txtdefaultprinter.Enabled = $false}}) 
        
        $txtdefaultprinter = New-Object System.Windows.Forms.TextBox 
        $txtdefaultprinter.Location = New-Object System.Drawing.Point(5,520) 
        $txtdefaultprinter.Size = New-Object System.Drawing.Size(300,20)
        $txtdefaultprinter.Multiline = $true
       $txtdefaultprinter.Text = $ActDefaultPrinterSelection
         if ($ActSetDefault -eq 1) { $txtdefaultprinter.enabled = $true} else { $txtdefaultprinter.enabled = $false;}

  		$ActionDeletePrinter = New-Object System.Windows.Forms.checkbox
		$ActionDeletePrinter.Location = New-Object System.Drawing.Size(5,555)
		$ActionDeletePrinter.Size = New-Object System.Drawing.Size(300,17)
        $ActionDeletePrinter.Text = "Delete"
         if ($ActDeletePrinter -eq 1) {  $ActionDeletePrinter.Checked = $true} else { $ActionDeletePrinter.Checked = $false}

        #$txtdeleteprinter = New-Object System.Windows.Forms.TextBox 
        #$txtdeleteprinter.Location = New-Object System.Drawing.Point(325,195) 
        #$txtdeleteprinter.Size = New-Object System.Drawing.Size(300,20)
        #$txtdeleteprinter.Multiline = $true
        #$txtdeleteprinter.text = $ActDeletePrinterSelection
        #if ($ActDeletePrinter -eq 1) { $txtdeleteprinter.enabled = $true} else { $txtdeleteprinter.enabled = $false;}




        $PolicyCancel = New-Object System.Windows.Forms.Button
		$PolicyCancel.location = New-Object System.Drawing.Point(545,560)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonResOk.Font = $FontBold
		$PolicyCancel.Size = New-Object System.Drawing.Size(80, 20)
		$PolicyCancel.Text = "Cancel"

        $PolicyOk = New-Object System.Windows.Forms.Button
		$PolicyOk.location = New-Object System.Drawing.Point(455,560)
		$FontBold = new-object System.Drawing.Font("Arial",8,[Drawing.FontStyle]'Bold' )
		#$ButtonResOk.Font = $FontBold
		$PolicyOk.Size = New-Object System.Drawing.Size(80, 20)
		$PolicyOk.Text = "Ok"
        
        $frmPolicyManagement.Controls.Add($labelPolicyName)
        $frmpolicymanagement.Controls.Add($txtpolicyname)
        $frmPolicyManagement.Controls.Add($labelPolicyDescription)
        $frmPolicyManagement.Controls.Add($PolicyEnableState)
        $frmPolicyManagement.Controls.Add($labelConditions)
        $frmPolicyManagement.Controls.Add($ConditionPrinterName)
        $frmPolicyManagement.Controls.Add($txtPrinterNames)


$frmPolicyManagement.Controls.Add($ConditionPrinterDriver)
$frmPolicyManagement.Controls.Add($ConditionPrinterIsDefault)
        $frmPolicyManagement.Controls.Add($txtPrinterDrivers)
        $frmPolicyManagement.Controls.Add($ConditionPrinterClient)
        $frmPolicyManagement.Controls.Add($txtprinterclient)
        $frmPolicyManagement.Controls.Add($ConditionPrinterUser)
        $frmPolicyManagement.Controls.Add($advobjectlist)
         $frmPolicyManagement.Controls.Add($AdvButtonRadd)
         $frmPolicyManagement.Controls.Add($AdvButtonRremove)
        #actions
        $frmPolicyManagement.Controls.Add($labelactions)
        $frmPolicyManagement.Controls.Add($ActionrenamePrinter)
        $frmPolicyManagement.Controls.Add($ActionRecreatePrinter)
        $frmPolicyManagement.Controls.Add($actionsetdefault)
        $frmPolicyManagement.Controls.Add($txtdefaultprinter)
        $frmPolicyManagement.Controls.Add($ActionDeletePrinter)
        $frmPolicyManagement.Controls.Add($txtdeleteprinter)
$frmPolicyManagement.Controls.Add($PolicyOk)
$frmPolicyManagement.Controls.Add($PolicyCancel)		

$PolicyCancel.add_Click({
$frmPolicyManagement.close()

})
$PolicyOk.add_Click({ 

#Get priority number
if ($policyaction -ne "edit"){$NextPrirority = ((Get-ChildItem HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy | Measure-Object ).Count) + 1;}
#See if policy already exists
$PolicyPath = "HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy\" + $txtpolicyname.Text
$halt = $false
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
#see if the name is null
if ($txtpolicyname.Text -eq ""){
[System.Windows.Forms.MessageBox]::Show('Please enter a name for the policy.', 'Name Required', 'Ok', 'Warning')
$halt = $true
}
if ((Test-Path $PolicyPath) -and ($halt -ne $true) -and ($policyaction -ne "edit")){

[System.Windows.Forms.MessageBox]::Show('A policy with this name already exits. Please change name.', 'Name Exists', 'Ok', 'Warning')
$halt = $true
}

$renamepolicy = $false
if (($txtpolicyname.Text -ne $policyname) -and ($policyaction -eq "edit")){
$renamepolicy = $true
$EditPath = "HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy\" + $txtpolicyname.Text
if ((Test-Path $PolicyPath) -and ($halt -ne $true) -and ($policyaction -eq "edit")){

[System.Windows.Forms.MessageBox]::Show('A policy with this name already exits. Please change name.', 'Name Exists', 'Ok', 'Warning')
$halt = $true
}
}



#add the policy if not halted
if ($halt -eq $false){


if ($ConditionPrinterName.Checked -eq $true){ $CondPrinterName = 1} else {$CondPrinterName = 0}
if ($ConditionPrinterIsDefault.Checked -eq $true){ $CondPrinterIsDefault = 1} else {$CondPrinterIsDefault = 0}
if ($ConditionPrinterUser.Checked -eq $true){ $CondPrinterUser = 1} else {$CondPrinterUser = 0}
if ($ConditionPrinterDriver.Checked -eq $true){$CondPrinterDriver = 1} else {$CondPrinterDriver = 0}
if ($ConditionPrinterClient.Checked -eq $true){$CondPrinterClient = 1} else {$CondPrinterClient = 0}
if ($ActionSetDefault.Checked -eq $true){$ActSetDefault = 1} else {$ActSetDefault = 0}
if ($ActionDeletePrinter.Checked -eq $true){$ActDeletePrinter = 1} else {$ActDeletePrinter = 0}
if ($ActionRenamePrinter.Checked -eq $true){$ActRename = 1} else {$ActRename = 0}
if ($ActionRecreatePrinter.Checked -eq $true){$ActRecreate = 1} else {$ActRecreate = 0}
if ($PolicyEnableState.Checked -eq $true){$policyenabled = 1} else {$policyenabled = 0}
#ConditionPrinterUser
if ($renamepolicy -eq $true){
$oldpath = "HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy\" + $policyname 
Rename-Item -Path $oldpath -NewName $txtpolicyname.Text -force
} else {new-item -Path "HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy" -name $txtpolicyname.Text -force}
New-ItemProperty -Path $PolicyPath -Name "Priority" -Value $NextPrirority -PropertyType "DWord" -Force
New-ItemProperty -Path $PolicyPath -Name "Description" -Value $txtpolicydescription.text -PropertyType "string" -Force
New-ItemProperty -Path $PolicyPath -Name "CondPrinterName" -Value $CondPrinterName -PropertyType "dword" -Force
foreach($itema in $txtprinterdrivers.CheckedItems) {$CondPrinterDriverSelectionOutput+= @($itema.text)}
foreach($itema in $txtprinterclient.CheckedItems) {$CondPrinterClientSelectionOutput+= @($itema.text)}
New-ItemProperty -Path $PolicyPath -Name "CondPrinterDriver" -Value $CondPrinterDriver -PropertyType "dword" -Force
New-ItemProperty -Path $PolicyPath -Name "CondPrinterClient" -Value $CondPrinterClient -PropertyType "dword" -Force
New-ItemProperty -Path $PolicyPath -Name "CondPrinterUser" -Value $CondPrinterUser -PropertyType "dword" -Force
New-ItemProperty -Path $PolicyPath -Name "ActDefaultPrinterSelection" -Value $txtdefaultprinter.Text -PropertyType "string" -Force
New-ItemProperty -Path $PolicyPath -Name "ActDeletePrinterSelection" -Value $txtdeleteprinter.Text -PropertyType "string" -Force
New-ItemProperty -Path $PolicyPath -Name "ActSetDefault" -Value $ActSetDefault -PropertyType "dword" -Force
New-ItemProperty -Path $PolicyPath -Name "ActDeletePrinter" -Value $ActDeletePrinter -PropertyType "dword" -Force
New-ItemProperty -Path $PolicyPath -Name "CondPrinterIsDefault" -Value $CondPrinterIsDefault -PropertyType "dword" -Force
New-ItemProperty -Path $PolicyPath -Name "CondPrinterNameSelection" -Value $txtPrinterNames.Text -PropertyType "multistring" -Force
New-ItemProperty -Path $PolicyPath -Name "CondPrinterDriverSelection" -Value $CondPrinterDriverSelectionOutput -PropertyType "multistring" -Force
New-ItemProperty -Path $PolicyPath -Name "CondPrinterClientSelection" -Value $CondPrinterClientSelectionOutput -PropertyType "multistring" -Force
New-ItemProperty -Path $PolicyPath -Name "ActRename" -Value $ActRename -PropertyType "dword" -Force
New-ItemProperty -Path $PolicyPath -Name "ActRecreate" -Value $ActRecreate -PropertyType "dword" -Force
New-ItemProperty -Path $PolicyPath -Name "enabled" -Value $policyenabled -PropertyType "dword" -Force

        $global:Advsecname = @()
        $global:Advsectype = @()
        $global:Advsecsid = $null
       $global:Advsecpath = $null
        foreach($item in $AdvObjectList.items) {$global:Advsecname+= @($item.subitems[0].text); $global:Advsectype+= @($item.subitems[1].text); $global:Advsecsid+= @($item.subitems[2].text); $global:Advsecpath+= @($item.subitems[3].text); }



        #Save restriction Information
        New-ItemProperty -Path $PolicyPath -Name "ScopeAll" -Value $global:AdvScopeAll  -PropertyType "multistring" -Force
        New-ItemProperty -Path $PolicyPath -Name "Scope" -Value $global:AdvScope  -PropertyType "multistring"  -Force
        New-ItemProperty -Path $PolicyPath -Name "SecName" -Value $global:Advsecname  -PropertyType "multistring" -Force
        New-ItemProperty -Path $PolicyPath -Name "sectype" -Value $global:Advsectype  -PropertyType "multistring" -Force
        New-ItemProperty -Path $PolicyPath -Name "SecSID" -Value $global:Advsecsid  -PropertyType "multistring" -Force
       New-ItemProperty -Path $PolicyPath -Name "SecPath" -Value $global:Advsecpath  -PropertyType "multistring" -Force


& $loadpolicy
$frmPolicyManagement.close()
}




})
        
          $frmPolicyManagement.ShowDialog()



}

#Policy Management Stop

		  $Form.ShowDialog()





}

Import-Module PSTerminalServices

#Number of times to check for new printers. This is to give redirected time to become available
 $key = 'HKLM:\SOFTWARE\Printerceptor'
[int]$PassLimit =  Get-ItemProperty -Path $key -Name "Rounds" | foreach { $_.Rounds }
[int]$AdditionalTime = Get-ItemProperty -Path $key -Name "AdditionalTime" | foreach { $_.AdditionalTime }

#$PassLimit = 2
#$AdditionalTime = 5
	#Function to set security descriptor for printers
				function setsecurity($Users){
						$SD = ([WMIClass] "Win32_SecurityDescriptor").CreateInstance()
									# Specify the user or group
						foreach ($user in $Users)
						{ 
							$ace = ([WMIClass] "Win32_Ace").CreateInstance()
							$Trustee = ([WMIClass] "Win32_Trustee").CreateInstance()
							$SID = (new-object security.principal.ntaccount $user).translate([security.principal.securityidentifier])
							[byte[]] $SIDArray = ,0 * $SID.BinaryLength
							[byte[]] $SIDArray2 = ,0 * $SID2.BinaryLength
							$SID.GetBinaryForm($SIDArray,0)
							$Trustee.Name = $user
							$Trustee.SID = $SIDArray
							$ace.AccessMask = 983052
							$ace.AceType = 0
							$ace.AceFlags = 0  
							$ace.Trustee = $Trustee
							$SD.DACL += $ace
							$SD.ControlFlags = 0x0004
							
						}
						return $SD
				}
				
				
$PrinterCount = 0				
$Source = ""


$Seconds = $PassLimit

$AdditionalTime = [int]$AdditionalTime
$previoususers = (Get-TSSession  | where {$_.State -eq "Active"}).count
DO

{

##
$ActiveUsers = (Get-TSSession  | where {$_.State -eq "Active"}).count
if ($ActiveUsers -gt $previoususers) {exit}
$previoususers = $ActiveUsers

##
	$i++
	[string]$RoundStart = Get-Date  -Format "hh:mm:ss" 
	#Logging
	$Round = $i
	
	#Load Fresh From Registry
	$key = 'HKLM:\SOFTWARE\Printerceptor'
	$LoadRecreateFullList = Get-ItemProperty -Path $key -Name "RecreateFullList" | foreach { $_.RecreateFullList } 
	$LoadDoNotRenList = Get-ItemProperty -Path $key -Name "DoNotRenList" | foreach { $_.DoNotRenList }
	$LoadNameFormat = Get-ItemProperty -Path $key -Name "NamingFormat" | foreach { $_.NamingFormat } 
	$LoadRedirectedExpression = Get-ItemProperty -Path $key -Name "RedirectedExpression" | foreach { $_.RedirectedExpression } 
    $ActSetDefault = 0
    $ActDeletePrinter = $null
    $Avancedpolicy = $false





#Restriction Loading
        [array]$global:SecName = Get-ItemProperty -Path $key -Name "SecName" | select -ExpandProperty SecName
        [array]$global:sectype = Get-ItemProperty -Path $key -Name "sectype" | select -ExpandProperty sectype
        [array]$global:secsid = Get-ItemProperty -Path $key -Name "SecSID" | select -ExpandProperty SecSID 
        [array]$global:secpath = Get-ItemProperty -Path $key -Name "SecPath" | select -ExpandProperty SecPath

     $global:Scope = Get-ItemProperty -Path $key -Name "Scope" | foreach { $_.Scope } 
        $global:ScopeAll = Get-ItemProperty -Path $key -Name "ScopeAll" | foreach { $_.ScopeAll } 

        $Counter = -1
        [array]$ScopeSIDS = $null
        foreach ($item in $global:sectype){
        $Counter++
            if ($global:sectype[$Counter] -eq "user"){ $ScopeSIDS+=$global:secsid[$Counter]}

            if ($global:sectype[$counter] -eq "group") {
                #Get group members
                $Recurse = $true

                    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
                    if ($global:secpath[$Counter] -eq "AD"){
                    $ct = [System.DirectoryServices.AccountManagement.ContextType]::Domain
                    } else { $ct = [System.DirectoryServices.AccountManagement.ContextType]::Machine}
                    #SID in next line is the group SID
                    $group=[System.DirectoryServices.AccountManagement.Principal]::FindByIdentity($ct,$global:secsid[$Counter])
                    #Output Member SIDs
                    $group.GetMembers($Recurse)
                    foreach ($item in $group.GetMembers($Recurse)) {$ScopeSIDS+= $item.sid}



            }

        }
       




	

	
	
	#Get the printers 
	$WMIstart = Get-Date
	$Printers = Get-WmiObject -Class Win32_Printer  -ErrorAction Stop
	$WMIFinish = Get-Date
	$Elapsed = New-TimeSpan -Start $WMIstart -End $WMIFinish | foreach {$_.TotalSeconds}
	start-sleep -Seconds ($AdditionalTime / 2)
	
Write-Host "WMI Time" $Elapsed

$PrinterLoopStart = Get-Date
	$PrinterCount = 0
	foreach ($Printer in $Printers)
	{
 #See if only drivers set for recreation should be renamed
	foreach ($item in $LoadDoNotRenList){if ($item -eq "Non Full Access Enabled") { $NoRename = $true; break;}}
	if(($Printer.name -match $LoadRedirectedExpression) -and ($Printer.DriverName -notmatch "Fax") -and ($Printer.DriverName -notmatch "Microsoft")  -and ($Printer.DriverName -ne "Remote Desktop Easy Print"))  {
	
	#Logging
	$Source = $Printer.name
	
		#NewName without suffix
		$CleanName = $Printer.Name -replace ( $LoadRedirectedExpression,"")

		
		#Get the user of the redirected printer
	    $sd = $Printer.GetSecurityDescriptor()            
	    $ssd = $sd.Descriptor.DACL




	    foreach ($obj3 in $ssd){if (($obj3.Trustee.Name -ne "system") -and ($obj3.Trustee.Name -ne "Print Operators")  -and ($obj3.Trustee.Name -ne "Creator Owner")  -and ($obj3.Trustee.Name -ne "Account Unknown") ){ $User = $obj3.Trustee.Name; $SID = $obj3.Trustee.SIDString;} }
	    
    write-host $SID
        
        ##Check Restriction Policy
        $Skip = $false
        if ($global:Scope -eq "AllBut"){ 
            foreach ($item in $ScopeSIDS){
            if ($item -eq $SID) {$Skip = $true; break;}
            }
            
        }
        if ($global:Scope -eq "Only"){ 
            $Skip = $true
            foreach ($item in $ScopeSIDS){
            if ($item -eq $SID) {$Skip = $false; break;}
            }
            
        }



        if ($global:ScopeAll -eq "Yes") {$Skip = $False}
        #Skip if restricted
        if ($Skip -eq $true){break;}
		#Logging
		$SourceUser = $user
		
		#Select the client name of the user
		$ClientName = get-TSSession | where {$_.username -eq $User} |  foreach { $_.ClientName }
		if ($ClientName -eq "") {$ClientName = hostname}
		
		#Logging
		$SourceClient = $ClientName
		
		#Identify the registry key for default printer session settings
		#See if this printer is the default printer of the user's session
	 	$regpath = "HKU:\" + $SID + "\Software\Microsoft\Windows NT\CurrentVersion\Windows\SessionDefaultDevices"
		$Key  = Get-ChildItem $regpath | foreach { $_.PSChildName } 
		$regpath = $regpath + "\" + $Key
		
		   
		  
		  
		 #Add suffixs
		 $NewName = $LoadNameFormat
		 $NewName = $NewName -replace "%printername%", $CleanName
		 $NewName = $NewName -replace "%username%", $user
		 $NewName = $NewName -replace "%clientname%", $ClientName
		 
		 #Logging
		 $TargetName = $NewName
		 #Identity is static new name used to identify when name scheme changes occur 
		 $identity = $CleanName + "-" + $User

		  
		  
			
			 #Determine if the printer should be renamed or not according to basic policy
			$Rename = $True
			foreach($item in $LoadDoNotRenList){if ($item -eq $Printer.DriverName){$Rename = $False; break;}}
			
			#Determine if the printer is to have full access or not
			$Recreate = $False
			foreach($item in $LoadRecreateFullList){if ($item -eq $Printer.DriverName){$Recreate = $True; break;}}
			


        ###advanced policy######



        
        $policies = Get-ChildItem -Path "HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy" 
        $policies = $policies | Foreach-Object {Get-ItemProperty $_.PsPath } | where {$_.enabled -eq "1"} | Sort-Object priority  | foreach { $_.pschildname}

        foreach ($policy in $policies)
        {
            $path = "HKLM:\SOFTWARE\Printerceptor\AdvancedPolicy\" + $policy
            $CondPrinterName = Get-ItemProperty -Path $path -Name "CondPrinterName" | foreach { $_.CondPrinterName }  
            $CondPrinterClient = Get-ItemProperty -Path $path -Name "CondPrinterClient" | foreach { $_.CondPrinterClient }  
             $CondPrinterUser = Get-ItemProperty -Path $path -Name "CondPrinterUser" | foreach { $_.CondPrinterUser }  
            $CondPrinterDriver = Get-ItemProperty -Path $path -Name "CondPrinterDriver" | foreach { $_.CondPrinterDriver }  
            $CondPrinterIsDefault = Get-ItemProperty -Path $path -Name "CondPrinterIsDefault" | foreach { $_.CondPrinterIsDefault }  
            $CondPrinterNameSelection = Get-ItemProperty -Path $path -Name "CondPrinterNameSelection" | foreach { $_.CondPrinterNameSelection }
             $CondPrinterClientSelection = Get-ItemProperty -Path $path -Name "CondPrinterClientSelection" | foreach { $_.CondPrinterClientSelection }
            $CondPrinterDriverSelection = Get-ItemProperty -Path $path -Name "CondPrinterDriverSelection" | foreach { $_.CondPrinterDriverSelection }  
            $ActDeletePrinter = Get-ItemProperty -Path $path -Name "ActDeletePrinter" | foreach { $_.ActDeletePrinter }  
            $ActSetDefault = Get-ItemProperty -Path $path -Name "ActSetDefault" | foreach { $_.ActSetDefault }  
            $ActRename = Get-ItemProperty -Path $path -Name "ActRename" | foreach { $_.ActRename }  
            $ActRecreate = Get-ItemProperty -Path $path -Name "ActRecreate" | foreach { $_.ActRecreate }  
            $ActDefaultPrinterSelection = Get-ItemProperty -Path $path -Name "ActDefaultPrinterSelection" | foreach { $_.ActDefaultPrinterSelection }
            $ActDeletePrinterSelection = Get-ItemProperty -Path $path -Name "ActDeletePrinterSelection" | foreach { $_.ActDeletePrinterSelection }
             [array]$global:ADVsecsid = Get-ItemProperty -Path $path -Name "SecSID" | select -ExpandProperty SecSID 
             [array]$global:ADVsectype = Get-ItemProperty -Path $path -Name "SecType" | select -ExpandProperty SecType
              [array]$global:ADVsecsid = Get-ItemProperty -Path $path -Name "Secsid" | select -ExpandProperty Secsid
                [array]$global:ADVsecpath = Get-ItemProperty -Path $path -Name "secpath" | select -ExpandProperty Secpath
            $conditionsrequired = 0
            $conditionsmet = 0
           $renameoverride = $false



           if ($CondPrinterClient -eq 1)
           {
            $conditionsrequired++

                foreach ($PrinterClient in $CondPrinterClientSelection){
                    if ($ClientName -eq $PrinterClient){
                    $conditionsmet++
                    break
                    }


                }

            }

            if ($CondPrinterIsDefault -eq 1)
            {
     
                $conditionsrequired++
                       	$UnchangedValue = $Printer.name + "," + "winspool" + "," + $Printer.PortName
				   $SessionDefault = Get-ItemProperty -Path $regpath -Name "Device" | foreach { $_.Device }
				 #See if printers original name was the user's default printer
				  	 if ($UnchangedValue -eq $SessionDefault) { $conditionsmet++} 
            }

            if ($CondPrinterName -eq 1)
            {
                $conditionsrequired++
                
                    foreach ($PrinterName in $CondPrinterNameSelection)
                    {
            
                        if($Printer.name -match $PrinterName)
                        {
                            $conditionsmet++
                            Write-Host $printeritem.name
                            break
                        }
                    }

            }




            if ($CondPrinterDriver -eq 1)
            {
                $conditionsrequired++
                 
                    foreach($drivername in $CondPrinterDriverSelection)
                    {
                        if ($printer.drivername -eq $drivername)
                        {
                        $conditionsmet++
                        write-host $printer.name

                        break
                        }
                    }
            }

            if ($CondPrinterUser -eq 1)
            {
                            $conditionsrequired++
                        write-host "sid" $SID
                                    $Counter = -1
                    [array]$ADVScopeSIDS = $null
                    foreach ($item in $global:ADVsectype){
                    $Counter++
                        if ($global:ADVsectype[$Counter] -eq "user"){ $ADVScopeSIDS+=$global:ADVsecsid[$Counter]}

                        if ($global:ADVsectype[$counter] -eq "group") {
                            #Get group members
                            $ADVRecurse = $true

                                Add-Type -AssemblyName System.DirectoryServices.AccountManagement
                                if ($global:ADVsecpath[$Counter] -eq "AD"){
                                $ct = [System.DirectoryServices.AccountManagement.ContextType]::Domain
                                } else { $ct = [System.DirectoryServices.AccountManagement.ContextType]::Machine}
                                #SID in next line is the group SID
                                $ADVgroup=[System.DirectoryServices.AccountManagement.Principal]::FindByIdentity($ct,$global:ADVsecsid[$Counter])
                                #Output Member SIDs
                                $ADVgroup.GetMembers($ADVRecurse)
                                foreach ($item in $ADVgroup.GetMembers($ADVRecurse)) {$ADVScopeSIDS+= $item.sid}
                                write-host $ADVScopeSIDS
                            

                        }
                          
                    }
                          foreach ($item in $ADVScopeSIDS){
                            if ($item -eq $SID) { $conditionsmet++; $Skip = $false; write-host "policy"; break;}
                            }



            }
    
        #If the policy applies
        if (($conditionsmet -eq $conditionsrequired) -and ($conditionsrequired -ne 0)) 
        { 

        $rename = $false
        $recreate = $False
          #determine the actions to take
         if ($ActSetDefault -eq 1){$shiftdelete = $true; $Makethisprinterdefat = $ActDefaultPrinterSelection; add-content C:\test.txt "apples";}
         add-content C:\test.txt "apples fuck"
          if ($ActDeletePrinter -eq 1){ $DeletePrinterAction = $true}

          
      


          $renameoverride = $false
           if ($ActRename -eq 1){ $renameoverride = $true; $Recreate = $False; $Rename = $true; $NoRename = $False }
        if ($ActRecreate -eq 1){ $Recreate = $true}

          #Default Printer Options
          #if ($ActSetDefault -eq 1){foreach ($targetprinter in $Printers){if ($targetprinter.name -eq $ActDefaultPrinterSelection) {$targetdefaultprinter = $targetprinter.name; Write-Host Targeted default $targetprinter.name; $advDefaultPrinter = $targetprinter.name + "," + "winspool" + "," + $targetprinter.PortName }}}
          #write-host $policy appActDeletePrinterlies; break;
          break;
        }


        } 

       
    
      if ($conditionsrequired -eq $null) {$conditionsrequired = 45444}


       
		#Renames the printer if that is all it should do
		  if (($Rename -eq $True) -and ($Recreate -eq $False) -and (($NoRename -ne $true) -or ($renameoverride -eq  $true)))
		  {
          add-content C:\test.txt "fuck you harder";
			# Delete Printer if the new name already exists. May occur if the redirected printers havn't unloaded from previous session
			#foreach ($printitem in $Printers){if (($printitem.Name -eq $NewName) -or ($printitem.Parameters -eq $identity -or ($printitem.Parameters -eq $identity + "Renamed"))) {$printitem.delete()}}
			#Rename the printer and add identity tag to paramenters
			
			#remove duplicate
			
			foreach ($printitem in $Printers)
			{
				if (($printitem.Name -eq $NewName) -or ($printitem.Parameters -eq $identity) -or ($printitem.Parameters -eq $identity + "rename")) {
         
				$printitem.delete()
				}
				}
			$printer.parameters = $identity + "rename"
            
			$Printer.put()
		  	invoke-WMIMethod -path $printer.Path -name RenamePrinter -argumentList $NewName
			
			$TargetType = "Self - " + $Printer.name
			$Operation = "Rename Only"
			$TargetPort = $Printer.portname
			$PrinterCount++

#if ($renameoverride -eq $true) {Add-Content C:\text.txt "shit"; $break; }


		  }
		   $recreateabort = $false
		  
		  if (($conditionsmet -eq $conditionsrequired) -and ($ActRecreate -ne $true)){ $recreateabort = $true}
		  ##see if printer already exists indicating that it has been created already and doesn't need created. If it doesn't then it sets the queue settings
		$AlreadyExists = $false
 if (($conditionsrequired -eq $conditionsmet) -and ($ActRecreate -ne $true) -and ($recreateabort -ne $true)) { add-content C:\test.txt "fucked"; $Recreate = $false}
		if ($Recreate -eq $true)
         
		{
           
			foreach ($printitem in $Printers)
			{
				if ($printitem.Parameters -eq $identity + "rename"){ $AlreadyExists = $false; $printitem.delete(); break;}
				if (($printitem.Name -eq $NewName) -or ($printitem.Parameters -eq $identity)) 
				{
                    
                    
                Start-Sleep -Seconds 5                 
                                        
					
					$TargetType = "Existing - " + $printitem.name
					
					if ($printitem.comment -ne "#"){
					$printitem.PortName = $Printer.PortName
                    $printitem.comment = ""
					}
					$TargetPort = $Printer.PortName
					$Operation = "Full Access"
					$printitem.WorkOffline = $false
					$printitem.put()
                    $Printer.delete()
						$Users = @($user,'system')
								
		
							$Security = setsecurity($Users)
							$printitem.SetSecurityDescriptor($Security)
					#$DonorPrinter = $printitem
					$AlreadyExists = $true
					
					invoke-WMIMethod -path $printitem.Path -name RenamePrinter -argumentList $NewName
					$PrinterCount++
					break
				}
			}
		 }
		  
			

		#if the printer doesn't already exist, make a new queue

		if (($Recreate -eq $True) -and ($recreateabort -ne $true)) 
		{
       
            $Rename = $true
			#Remove dedirectd printer
			$Printer.delete()
			
			#determine printer needs created
			if ($AlreadyExists -eq $false)
			{
            start-sleep -Seconds 5 
				#Create the printer
				$Operation = "Full Access"
				$TargetType = "New"
				$PortFormat = "'" + $Printer.PortName + "'"
				$printerclass = [wmiclass]'Win32_Printer'
				$DonorPrinter = $printerclass.CreateInstance()
				$DonorPrinter.Name = $DonorPrinter.DeviceID = $NewName
				$DonorPrinter.Comment = $null
				$DonorPrinter.PortName = $Printer.PortName
				$TargetPort = $Printer.PortName
				$DonorPrinter.Default = $false
				$DonorPrinter.Parameters = $identity
				$DonorPrinter.DriverName = $Printer.DriverName
				$DonorPrinter.Put()
					#set the security
					$Users = @($user,'system')
						
		
							$Security = setsecurity($Users)
							$DonorPrinter.SetSecurityDescriptor($Security)
							$PrinterCount++
			 }


							
						
	        if ($printitem.comment -ne "#"){
			#Protect printer from deletion by the spooler/system reboot because its "redirected"
			$path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Printers\" + $NewName
			New-ItemProperty -Path $path -Name "Port" -Value "COM1:" -PropertyType "string" -Force
            }

									
										
		  
		  
			} #End of printer creation
			
			

		  	#Setup default printer format for registry
					  if ($Recreate -eq $True) { $Value = $NewName + "," + "winspool" + "," + "COM1:"}
		  
			#Set the default Printer for the printers end-user 
				$UnchangedValue = $Printer.name + "," + "winspool" + "," + $Printer.PortName
				   $SessionDefault = Get-ItemProperty -Path $regpath -Name "Device" | foreach { $_.Device }
				      $Value = $NewName + "," + "winspool" + "," + $Printer.PortName
					
					 #See if printers original name was the user's default printer
				  	 if ($UnchangedValue -eq $SessionDefault) 
					{ 
				   	
					   #Don't  set the default if printer isn't to be renamed or set to be recreated
					   if (($Rename -eq $false) -or ($NoRename -eq $true) -and (($recreate -eq $false) -and ($renameoverride -ne $true)))  { } else 
					   {
					   		$TargetDefault = "Yes"
					   		$Key  = Get-ChildItem $regpath | foreach { $_.PSChildName } 
							$thedefault = $Value
						 	 New-ItemProperty -Path $regpath -Name "Device" -Value $Value -PropertyType "string" -Force
					   }
				   
				   } else {$TargetDefault = "No"}
			  



            #advanced policy action	   
            #set default according to advanced policy
             if ($shiftdelete -eq $true) 
             { 
             $ActDefaultPrinterSelection = $Makethisprinterdefat
            foreach ($targetprinter in $Printers){if ($targetprinter.name -eq $ActDefaultPrinterSelection) {$targetdefaultprinter = $targetprinter.name; Write-Host Targeted default $targetprinter.name; $advDefaultPrinter = $targetprinter.name + "," + "winspool" + "," + $targetprinter.PortName; break; }}
            Add-Content c:\test.txt "fuck this shiat"
            Add-Content c:\test.txt $ActDefaultPrinterSelection
                $value = $advDefaultPrinter
                $Key  = Get-ChildItem $regpath | foreach { $_.PSChildName } 
							$thedefault = $Value
						 	 New-ItemProperty -Path $regpath -Name "Device" -Value $Value -PropertyType "string" -Force
                    
                    Add-Content c:\test.txt $Value
                    $ActSetDefault = $false
                   $shiftdelete = $false
                    #break;
             }

         #########################
    			  if ($DeletePrinterAction -eq $true){
             $printer.delete()
             $DeletePrinterAction = $false
             }

		}#End of if statement for when printer is redirected
		
		[string]$RoundEnd = Get-Date  -Format "hh:mm:ss" 
	 $RoundOutput = $Round | Out-String
[string]$LogEntry = [string]$StartTime + "," +  [string]$Round + "," + [string]$RoundStart + "," + [string]$RoundEnd + "," + $Source + "," + $SourceUser + "," + $Operation + "," + $TargetName + "," + $TargetType + "," + $TargetDefault + "," + $TargetPort + "," + $ClientName


   if (($TargetType -ne "") -and  ($TargetType -ne $Null)) { 
					   
 Add-Content "C:\Program Files\Printerceptor\Log.csv"  $LogEntry
 
}
 [string]$LogEntry = ""
 #[string]$Round = ""
 $Source = ""
 $SourceUser = ""
 $TargetName = ""
 $TargetType = ""
 $TargetPort = ""
 
  



	} #end of foreach printer
	 $PrinterLoopEnd = Get-Date
	 
	 #Figure out how much longer to keep going
	if ($PrinterCount -eq 0) {$Seconds = $Seconds -1; Write-Host $Seconds " Round"}
	if ($PrinterCount -gt 0) {$Seconds = $PassLimit}
	
	
$Elapsed = New-TimeSpan -Start $PrinterLoopStart -End $PrinterLoopEnd | foreach {$_.TotalSeconds}
 #write-host "Printer Process, time " $elapsed
 #Write-Host "Printers touched "  $PrinterCount

 
 start-sleep -Seconds ($AdditionalTime / 2)

} until ($Seconds -eq 0)




#Hide inactive printers####
$Printers = Get-WmiObject -Class Win32_Printer | where {(($_.paramenters -ne "") -and ($_.Comment -eq $null)) }
$RegistryRoot = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceClasses\{28d78fad-5a12-11d1-ae5b-0000f803a8c2}\##?#ROOT#RDPBUS#0000#{28d78fad-5a12-11d1-ae5b-0000f803a8c2}\"
foreach ($Printer in $Printers){
$Date = Get-Date
if ($Printer.portname -eq "COM1:") {$Security = setsecurity('system'); $printer.SetSecurityDescriptor($Security); $printer.comment = "Inactive since " + $Date; $printer.put(); }else{
$path = $RegistryRoot + "#" + $Printer.portname + "\Device Parameters" 
	if ((Get-ItemProperty -Path $path -Name "Port Description"  | foreach { $_."Port Description"  }) -eq "Inactive TS Port") {$Security = setsecurity('system'); $printer.SetSecurityDescriptor($Security); $printer.comment = "Inactive since " + $Date; $printer.put();  }
}



#Remove Large Log File
$LogSize = (Get-Item "C:\Program Files\Printerceptor\Log.csv").length / 200MB
if ($LogSize -gt 1){ Copy-Item "C:\Program Files\Printerceptor\LogBlank.csv" "C:\Program Files\Printerceptor\Log.csv" -Force  }


}



$EndTime = Get-Date  -Format "hh:mm:ss"

######
