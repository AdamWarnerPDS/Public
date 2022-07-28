<#
Name: 
Created by: Raymond Hestres PDS Senior Architect
Date: 6/5/15
Description: The script can be used to create a report on file and/or folders in a determined path.
                It is also used to apply permissions
Usage:
    ./FMTx.ps1
    
Example: ./FMTx.ps1
#>

function IsFileLocked([string]$filePath)
{
	Rename-Item $filePath $filePath -ErrorVariable errs -ErrorAction SilentlyContinue
	return ($errs.Count -ne 0)
}

function BrowseFolders($objTextBox)
{
	$outputfolder = ($browser.BrowseForFolder(0, "Select Output Folder", 0, "C")).self.path
	$objTextBox.text = $outputfolder
}

Function Get-ChildItemToDepth
{
	Param (
		[String]$Path,
		[String]$Filter = "*",
		[Byte]$ToDepth,
		[Byte]$CurrentDepth = 0
	)
	
	$CurrentDepth++
	
	Get-ChildItem $Path -force | %{
		$_ | ?{ $_.Name -Like $Filter }
		
		If ($_.PsIsContainer)
		{
			If ($CurrentDepth -le $ToDepth)
			{
				
				# Callback to this function
				Get-ChildItemToDepth -Path $_.FullName -Filter $Filter `
									 -ToDepth $ToDepth -CurrentDepth $CurrentDepth
				
			}
		}
	}
}

function Folder_Checks ($folder)
{
	#if destination does not exist, then create
	if (!(Test-Path $folder)) { new-item -type directory -path $folder | Out-Null }
}

###create checkboxes and items in the list
$listBox_DrawItem = {
	param (
		[System.Object] $sender,
		[System.Windows.Forms.DrawListViewItemEventArgs] $e
	)
	$e.DrawFocusRectangle();
	if ($e.Item.Checked)
	{
		[System.Windows.Forms.ControlPaint]::DrawCheckBox($e.Graphics, $e.Bounds.X, $e.Bounds.Top + 1, 15, 15, [System.Windows.Forms.ButtonState]::Checked)
	}
	else
	{
		[System.Windows.Forms.ControlPaint]::DrawCheckBox($e.Graphics, $e.Bounds.X, $e.Bounds.Top + 1, 15, 15, [System.Windows.Forms.ButtonState]::Flat)
	}
	$sf = new-object System.Drawing.StringFormat
	$sf.Alignment = [System.Drawing.StringAlignment]::Near
	
	$rect = New-Object System.Drawing.RectangleF
	$rect.x = $e.Bounds.X + 16
	$rect.y = $e.Bounds.Top + 1
	$rect.width = $e.bounds.right
	$rect.height = $e.bounds.bottom
	$e.Graphics.DrawString($e.item.Text,
	$headerFont,
	[System.Drawing.Brushes]::Black,
	$rect,
	$sf)
}


$listBox_DrawHeader = {
	param (
		[System.Object] $sender,
		[System.Windows.Forms.DrawListViewColumnHeaderEventArgs] $e
	)
	
	[System.Drawing.font] $headerFont = new-object System.Drawing.font("Helvetica",
	10, [System.Drawing.FontStyle]::Bold)
	$e.DrawBackground();
	$sf = new-object System.Drawing.StringFormat
	$sf.Alignment = [System.Drawing.StringAlignment]::Center
	
	$rect = New-Object System.Drawing.RectangleF
	$rect.x = $e.Bounds.X + 16
	$rect.y = $e.Bounds.Top + 1
	$rect.width = -1  #$e.bounds.right
	$rect.height = $e.bounds.bottom
	$e.Graphics.DrawString($e.Column.text, $e.Item.Font, [System.Drawing.Brushes]::Black, $rect)
	$e.Graphics.DrawString($e.Header.Text,
	$headerFont,
	[System.Drawing.Brushes]::Black,
	$rect,
	$sf)
}

function Duplicates_Form ($destfound)
{
	$form1 = New-Object System.Windows.Forms.Form
	$listbox = New-Object System.Windows.Forms.Listview
	$form1.Text = "Duplicate Folders"
	$form1.Size = New-Object Drawing.Size(557, 550)
	$form1.StartPosition = "CenterScreen"
	$form1.AutoScaleMode = 3
	$form1.AutoScroll = $True
	
	
	$listbox.size = new-object System.Drawing.Size(530, 407)
	$listbox.DataBindings.DefaultDataSourceUpdateMode = 0
	$listbox.Name = "listview"
	$listBox.view = [System.Windows.Forms.View]::Details
	$listbox.CheckBoxes = $true
	$listbox.fullrowselect = $true
	$listBox.OwnerDraw = $true
	$listBox.Add_DrawItem($listBox_DrawItem)
	$listBox.add_DrawColumnHeader($listBox_DrawHeader)
	$listbox.Location = New-Object System.Drawing.Size(22, 21)
	$listbox.add_Click($action_si_click_sur_VMKO)
	$listBox.Columns.Add("Folder Path", 300, [System.Windows.Forms.HorizontalAlignment]::Center) | out-null
	
	$CloseButton = New-Object System.Windows.Forms.Button
	$CloseButton.Location = New-Object System.Drawing.Size(50, 450)
	$CloseButton.Size = New-Object System.Drawing.Size(75, 23)
	$CloseButton.Text = "Close"
	$CloseButton.Add_Click({ $output = $null; $winform.Close() })
	
	foreach ($s in $destfound)
	{
		$i = $listbox.Items.Add($s)
		<#$listbox.BeginUpdate()
		#$listbox.AutoResizeColumns([System.Windows.Forms.ColumnHeaderAutoResizeStyle]::HeaderSize)
		$listbox.EndUpdate()
		$listbox.Refresh()#>
	}
	
	$form1.Controls.Add($listbox)
	$form1.Controls.Add($CloseButton)
	$form1.ShowDialog() | Out-Null
	
	$a = @()
	foreach ($b in $listbox.CheckedItems)
	{
		$a += "$($b.Text)`n"
	}
	$msgbox.popup($a, 0, ”Error”, 1) | out-null
	$a
}
### end code for listbox

function Read_Permissions ($items)
{
	write-host $targetfolder
    $newfoldername = ($targetFolder.split("\")[($targetFolder.split("\")).count - 1])
	$outputfolder = "$outputfolder\$($targetFolder.split("\")[2])\$newfoldername"
	Folder_Checks $outputfolder
	$outputfile = "$($outputfolder)\$($newfoldername)_Permissions_Output.bak.csv"
	if (test-path $outputfile)
	{
		if (!(IsFileLocked $outputfile))
		{
			remove-item $outputfile
		}
		else { $msgbox.popup(“The file $($outputfile) is opened“, 0, ”Error”, 1); return }
	}
	add-content -path $outputfile -value "path,user,permission,type"
	$i = 0
	foreach ($item in $items)
	{
		#calculate percentage
		$i++
		[int]$pct = ($i/$items.count) * 100
		#update the progress bar
		$progressbar1.Value = $pct
		$WinForm.refresh()
		
		$Error.clear()
		$acl = get-acl $item -ea "silentlycontinue"
		
		if ($Error)
		{
			if ($error[0].tostring() -like "*because it does not exist*") { }
			else { add-content -path $outputfile -value "`"$($item)`",Error,$($Error[0])" }
			$error.clear()
		}
		else
		{
			foreach ($access in $acl.access)
			{
				if ($access.filesystemrights -and (!($access.isinherited)) -or ($item -eq $items[0]))
				{
					switch ($access.filesystemrights.tostring().split(",")[0])
					{
						{ ($_ -eq "268435456") -or ($_ -eq "-536805376") -or ($_ -eq "-1610612736") } { }
						Default
						{
							$user = ($($access.identityreference.tostring())).split("\")[1]
							$domain = ($($access.identityreference.tostring())).split("\")[0]
							$type=""
							if (get-qaduser -identity $user -service $domain) { $type = "user" }
							if (get-qadgroup -identity $user -service $domain) { $type = "group" }
							add-content -path $outputfile -value "`"$($item)`",$($access.identityreference.tostring()),$($access.filesystemrights.tostring().split(",")[0]),$($type)" }
					}
				}
			}
		}
	}
}

function Apply_Permissions ($items, $filename)
{
	$newfoldername = $filename.split("_")[0]
	Folder_Checks $outputfolder
	$outputfile = "$($outputfolder)\$($newfoldername)_Permissions_Apply_Results.csv"
	if (!(test-path $outputfile)) { add-content -path $outputfile -value "path,user,permission,result" }
	$i = 0
	foreach ($item in $items)
	{
		#calculate percentage
		$i++
		[int]$pct = ($i/$items.count) * 100
		#update the progress bar
		$progressbar1.Value = $pct
		$WinForm.refresh()
		
		$inheritance = [system.security.accesscontrol.InheritanceFlags]"ContainerInherit, ObjectInherit"
		$propagation = [system.security.accesscontrol.PropagationFlags]"None"
        
        if ($item.applyto.tolower() -eq "thisfolderonly") {
            {
		      	$inheritance = "None"
				$propagation = "InheritOnly"
			}
		
		}
		$acl = get-acl $item.path -ea "silentlycontinue"
        $error.clear()
		$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($item.user, $item.permission, $inheritance, $propagation, "Allow")
		if ($error) { add-content -path $outputfile -value "`"$($item.path)`",$($item.user),$($item.permission),$($error[0].tostring())" }
        $error.clear()
        $acl.AddAccessRule($rule)
        if ($error) { add-content -path $outputfile -value "`"$($item.path)`",$($item.user),$($item.permission),$($error[0].tostring())" }
#$acl.SetAccessRuleProtection($false, $false)
		$error.clear()
		Set-Acl $item.path $acl -ea "SilentlyContinue"
		if ($error) { add-content -path $outputfile -value "`"$($item.path)`",$($item.user),$($item.permission),$($error[0].tostring())" }
		else { add-content -path $outputfile -value "`"$($item.path)`",$($item.user),$($item.permission),Success" }
	}
	
}
function Main_Code ()
{
	if ($checkBox4.checked)
	{
		if (!($objTextBoxJ.text) -or (!(Test-Path $objTextBoxJ.text))) { $msgbox.popup(“Please enter a valid input file“, 0, ”Error”, 1); return }
		$filename = (get-childitem $objTextBoxJ.text).name
		$Sources = Import-Csv $objTextBoxJ.text
	}
	else
	{
		if (!($objTextBox1.text) -or (!(Test-Path $objTextBox1.text))) { $msgbox.popup(“Please enter a valid Search Folder location“, 0, ”Error”, 1); return }
		$Sources = $objTextBox1.Text
		$filename = (get-childitem $objTextBox1.text).name
		$Sources = $sources | select @{ n = "source"; e = { $_ } }
	}
	if (!($objTextBox3.text) -or ($objTextBox3.text > 255)) { $msgbox.popup(“Please enter a valid Folder search Depth“, 0, ”Error”, 1); return }
	if (!($objTextBox2.text) -or (!(Test-Path $objTextBox2.text))) { $msgbox.popup(“Please enter a valid Output Folder location under Preferences“, 0, ”Error”, 1); return }
	
	$depth = $objTextBox3.text
	$outputfolder = $objTextBox2.text
	
	#get checkbox selection
	if ($checkBox1.checked) { $scope = "Files" }
	if ($checkBox2.checked) { $scope = "Folders" }
	if ($checkBox1.checked -and $checkBox2.checked) { $scope = "All" }
	if (!($scope)) { $msgbox.popup(“Please Select a Scope.“, 0, ”Error”, 1); return }
	#get radiobutton selection
	if ($radioButton1.checked) { $action = "Read" }
	if ($radioButton2.checked) { $action = "Apply" }
	if (!($action)) { $msgbox.popup(“Please Select an Action.“, 0, ”Error”, 1); return }
	
	switch ($action)
	{
		"Read"
		{
			foreach ($source in $Sources)
			{
				$targetfolder = $source.source
				$items = @()
				$items += $targetfolder
				switch ($scope)
				{
					"Files" { $items += Get-ChildItemToDepth -Path $targetfolder -ToDepth $depth | ?{ !($_.PSIsContainer) } | % { $_.fullname } }
					"Folders" { $items += Get-ChildItemToDepth -Path $targetfolder -ToDepth $depth | ?{ $_.PSIsContainer } | % { $_.fullname } }
					"All" { $items += Get-ChildItemToDepth -Path $targetfolder -ToDepth $depth | % { $_.fullname } }
				}
				Read_permissions $items
			}
		}
		"Apply" { Apply_Permissions $Sources $filename }
	}
	$msgbox.popup(“Output file has been written to $($outputfolder)“, 0, ”Information”, 1)
}

function Robocopy_Prep ()
{
	if ($checkBox3.checked)
	{
		if (!($objTextBoxI.text) -or (!(Test-Path $objTextBoxI.text))) { $msgbox.popup(“Please enter a valid input file“, 0, ”Error”, 1); return }
		$Sources = Import-Csv $objTextBoxI.text
		
	}
	else
	{
		if (!($objTextBox2.text) -or (!(Test-Path $objTextBox2.text))) { $msgbox.popup(“Please enter a valid Output Folder location under Preferences“, 0, ”Error”, 1); return }
		if (!($objTextBox4.text) -or (!(Test-Path $objTextBox4.text))) { $msgbox.popup(“Please enter a valid Source Folder location“, 0, ”Error”, 1); return }
		if (!($objTextBox5.text) -or (!(Test-Path $objTextBox5.text))) { $msgbox.popup(“Please enter a valid Destination Folder location“, 0, ”Error”, 1); return }
		
		$Sources = $objTextBox4.Text
		$Sources = $sources | select @{ n = "source"; e = { $_ } }, @{ n = "destination"; e = { $objTextBox5.Text } }
	}
	$objLabelR.Text = "Preping Copy ....."
	$objLabelR.Visible = $true
	
	$outputfolder = $objTextBox2.text
	$output = 1
	$destfound = @()
	
	foreach ($source in $Sources)
	{
		if (!($source.source)) { $msgbox.popup(“Input file contains blank entries“, 0, ”Error”, 1); return }
		$sourcefolder = $source.source
		$destfolder = $source.destination
		$newFolderName = ($destfolder.split("\")[($destfolder.split("\")).count - 1])
		$destfolder = $destfolder.substring(0, $destfolder.length - ($destfolder.split("\")[($destfolder.split("\")).count - 1]).length) + $newfoldername
		
		
		#check that destination directory is empty
		if (Get-ChildItem $destfolder)
		{
			$destfound += "$($destfolder)`n"
		}
		
	}
	if ($destfound)
	{
		$dupfile = "$($outputfolder)\$($newfoldername)_Duplicate_$(Generate_Date)" + ".txt"
		add-content -path $dupfile -value "Folder count: $($destfound.count)"
		add-content -path $dupfile -value $destfound
		if ($msgbox.popup(“Following destination foldes are not empty`n$destfound`nDo you want to continue with the copy?“, 0, ”Checking Destination Folders”, 3) -ne "6") { return }
	}
	$remote = 0
	foreach ($source in $Sources)
	{
		$sourcefolder = $source.source
		$destfolder = $source.destination
		$newFolderName = ($destfolder.split("\")[($destfolder.split("\")).count - 1])
		$destfolder = $destfolder.substring(0, $destfolder.length - ($destfolder.split("\")[($destfolder.split("\")).count - 1]).length) + $newfoldername
		
		$outputpath = "$($outputfolder)\$(($sourcefolder.split("\")[2]))\$($newFolderName)"
		Folder_Checks $outputpath
		$logFile = "$($outputpath)\$($newfoldername)_Robocopy_$(Generate_Date)" + ".txt"
		
		$excludedDir = "DNC_*"
		#Excluded_Dirs $sourcefolder $excludedDir
		$drive=$null
		if (!(Test-Path $sourcefolder))
		{
			if ($remote -eq 0)
			{
				#$IPC = $sourcefolder.substring(0, ($sourcefolder.split("\")[2].length + 3)) + "IPC`$"
				$cred = Get-Credential -Message "Enter Logon using domain\username format"
				$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cred.Password)
				$UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
				$remote = 1
			}
		Invoke-expression "net use Q: `"$($sourcefolder)`" /u:$($cred.username) $($unsecurepassword)" -ea silentlycontinue
		$drive = "Q:"
		}
		
		Process_Robocopy $sourcefolder $destfolder $logFile $drive
		if (test-path Q:) { Invoke-expression "net use Q: /d" }
        $remote = 0
	}
	$objLabelR.Visible = $false
	
	$msgbox.popup(“Robocopy Log is has been written to $($objTextBox2.text)“, 0, ”Information”, 1)
}

function Process_Robocopy ($sourcefolder, $destfolder, $logFile, $drive)
{
	$drive=$false
	$excluded = $objTextBox6.Text
	$excluded = $excluded.replace("`r`n", " ")
	
	foreach ($i in $excluded.split(" "))
	{
		[string]$excludedFiles += "`"$i`" "
	}
	$outputfolder = $objTextBox2.text
	$outFile = "$outputfolder\$(($sourcefolder.split("\")[2]))_Robocopy_results" + ".txt"
	if ($checkBox5.checked) { $mirror = "/MIR" }
	Else { $mirror = " " }
	if ($checkBox6.checked) { $copy = "/secfix /COPY:DATS" }
	Else { $copy = "/COPY:DAT" }
	if ($drive)
	{
		$runarglist = "`"$drive`" `"$destFolder`" /XF $excludedFiles /E /FP /R:2 /W:1 /XO /XD $excludedDir /NP /MT:48 $copy $mirror /log+:`"$logFile`""
	}
	else
	{
		$runarglist = "`"$sourceFolder`" `"$destFolder`" /XF $excludedFiles /E /FP /R:2 /W:1 /XO /XD $excludedDir /NP /MT:48 $copy $mirror /log+:`"$logFile`""
	}
	#start Robocopy process
	$objLabelR.Visible = $true
	$objLabelR.Text = "Copying ....."
	$Robocopy = Start-Process -FilePath robocopy.exe -ArgumentList $runarglist -PassThru -Wait -Verbose -NoNewWindow
	switch ($Robocopy.ExitCode)
	{
		0 { add-content -path $outfile -value "$(Generate_Date),$sourcefolder,SUCCESS" }
		1 { add-content -path $outfile -value "$(Generate_Date),$sourcefolder,SUCCESS" }
		2 { add-content -path $outfile -value "$(Generate_Date),$sourcefolder,SUCCESS" }
		4 { add-content -path $outfile -value "$(Generate_Date),$sourcefolder,WARNING,`"Some Mismatched files or directories were detected. Examine the output log. Some housekeeping may be needed.`"" }
		8 { add-content -path $outfile -value "$(Generate_Date),$sourcefolder,ERROR,`"Some files or directories could not be copied (copy errors occurred and the retry limit was exceeded). Check these errors further.`"" }
		16 { add-content -path $outfile -value "$(Generate_Date),$sourcefolder,ERROR,`"Usage error or an error due to insufficient access privileges on the source or destination directories.`"" }
		Default { add-content -path $outfile -value "$(Generate_Date),$sourcefolder,WARNING,`"$($lastexitcode)Verify Log file`"" }
	}
	$output = 0
	$output
}

function Excluded_Dirs($folder, $excludedDir)
{
	$items = Get-ChildItem $folder -Recurse | ?{ $_.PSIsContainer }
	$logFile2 = "$($outputpath)\$($newfoldername)_Excluded_Dirs_$(Generate_Date)" + ".txt"
	foreach ($item in $items)
	{
		if ($item.name -like $excludedDir)
		{
			if (!(test-path $logfile2)) { Add-Content -path $logfile2 -Value "source,destination" }
			Add-Content -path $logfile2 -Value "$($item.fullname),$destfolder"
		}
	}
}

function Save_Preferences ()
{
	if (!($objTextBox2.text) -or (!(Test-Path $objTextBox2.text)))
	{
		$msgbox.popup(“Please enter a valid Output Folder location“, 0, ”Error”, 1)
		return
	}
	$Optionshash['outputFolder'] = $objTextBox2.Text
	$optionshash | Export-Clixml -Path $optionsfile -Force
	$msgbox.popup(“Preferences Saved“, 0, ”Information”, 1)
}

function Generate_Date ()
{
	$date = Get-Date
	$year = $date.year
	$month = "{0:d2}" -f $date.month
	$day = "{0:d2}" -f $date.day
	$hours = "{0:d2}" -f $date.timeofday.hours
	$minutes = "{0:d2}" -f $date.timeofday.minutes
	$date = "$($year)-$($month)-$($day)_$hours$minutes"
	$date
}

function Groups_Tab
{
	if (!($objTextBox2.text) -or (!(Test-Path $objTextBox2.text))) { $msgbox.popup(“Please enter a valid Output Folder location under Preferences“, 0, ”Error”, 1); return }
	
	if ($objTextBox8.text)
	{
		if (!($objTextBox8.text) -or (!(Test-Path $objTextBox8.text))) { $msgbox.popup(“Please enter a valid input file“, 0, ”Error”, 1); return }
		if ($checkBox7.checked)
		{
			$files = Get-ChildItem -Path $objTextBox8.text -filter "*Permissions_Output*" -Recurse
		}
		else {$files = Get-ChildItem $objTextBox8.Text}
		foreach ($file in $files)
		{
			
			$inputfile = Import-Csv $file.FullName
			foreach ($item in $inputfile)
			{
				if (!($item.user)) { $msgbox.popup(“Input file contains blank entries“, 0, ”Error”, 1); return }
			}
			
			$i = 0
			$fullpath = $inputfile[0].path
			$newFolderName = ($destfolder.split("\")[($destfolder.split("\")).count - 1])
			$outputfolder = "$($objTextBox2.text)\$(($fullpath.split("\")[2]))\$($newFolderName)"
			Folder_Checks $outputfolder
			$outFile = "$($outputfolder)\$($newfoldername)_Groups_$(Generate_Date).csv"
			Add-Content -Path $outFile -Value "Path,Group,Logon,FullName,Permission,Disabled"
				
			foreach ($item in $inputfile)
			{
				$i++
				[int]$pct = ($i/$inputfile.count) * 100
				#update the progress bar
				$progressbar1.Value = $pct
				$WinForm.refresh()
				
				$domain = $item.user.split("\")[0]
				$groupname = $item.user.split("\")[1]
				if (Get-QADGroup $groupname) { Expand_Groups $domain $groupname $item.path $outfile $item.permission }
			}
		}
	}
	if ($objTextBox11.text)
	{
		$inputfile = Import-Csv $objTextBox11.Text
		$filename = (Get-ChildItem $objTextBox11.Text).Name
		$newfoldername = $filename.split("_")[0]
		$outputfile = "$($objTextBox2.text)\$($newfoldername)_Members_Results.csv"
		if (!(test-path $outputfile)) { add-content -path $outputfile -value "Date,Name,Comment,From,To,Result" }
		$DC = (get-QADComputer -computerRole 'DomainController')[0].dnsname
		
		#create groups in AD
		if ($checkBox8.checked)
		{
			$groups = $inputfile | ? { $_.type -eq "group" }
			foreach ($group in $groups)
			{
				if (!(get-QADGroup $group.name))
				{
					$Error.clear()
					New-QADGroup -SamAccountName $group.name -Name $group.name -Description $group.description -ParentContainer $group.OU | Out-Null
					if ($Error) { Add-Content -Path $outputfile -Value "$(Generate_Date),$($group.name),Not created,,,$($Error[0].ToString())" }
					else { Add-Content -Path $outputfile -Value "$(Generate_Date),$($group.name),Group created,,,Success" }
				}
			}
		}
		
		#add users to groups
		if ($checkBox9.checked)
		{
			$Users = $inputfile | ? { $_.type -eq "user" }
			foreach ($user in $Users)
			{
				if ($user.memberof)
				{
					$Error.clear()
					Add-QADGroupMember $user.memberof -Member $user.name
					if ($Error) { Add-Content -Path $outputfile -Value "$(Generate_Date),$($user.name),Not Added to Group $($user.memberof),,,$($Error[0].ToString())" }
					else { Add-Content -Path $outputfile -Value "$(Generate_Date),$($user.name),Added to Group $($user.memberof),,,Success" }
				}
			}
			#move users to OU
			foreach ($user in $Users)
			{
				if ($user.OU)
				{
					$oldOU = (Get-QADUser $user.name).parentcontainerdn
					if ($oldOU -eq $user.OU) { Add-Content -Path $outputfile -Value "$(Generate_Date),$($user.name),User Already in OU,`"$oldOU`",`"$($user.OU)`",Success" }
					else
					{
						$Error.clear()
						Move-QADObject $user.name -NewParentContainer $user.OU | Out-Null
						if ($Error) { Add-Content -Path $outputfile -Value "$(Generate_Date),$($user.name),User not moved,`"$oldOU`",`"$($user.OU)`",$($Error[0].ToString())" }
						else { Add-Content -Path $outputfile -Value "$(Generate_Date),$($user.name),User moved,`"$oldOU`",`"$($user.OU)`",Success" }
					}
				}
			}
			#move computers to OU
			$PCs = $inputfile | ? { $_.type -eq "computer" }
			foreach ($PC in $PCs)
			{
				if ($PC.OU)
				{
					$oldOU = (Get-QADComputer $PC.name).parentcontainerdn
					if ($oldOU -eq $PC.OU) { Add-Content -Path $outputfile -Value "$(Generate_Date),$($user.name),PC Already in OU,`"$oldOU`",`"$($user.OU)`",Success" }
					else
					{
						$Error.clear()
						Move-QADObject $PC.name -NewParentContainer $PC.OU | Out-Null
						if ($Error) { Add-Content -Path $outputfile -Value "$(Generate_Date),$($PC.name),PC not moved,`"$oldOU`",`"$($PC.OU)`",$($Error[0].ToString())" }
						else { Add-Content -Path $outputfile -Value "$(Generate_Date),$($PC.name),PC moved,`"$oldOU`",`"$($PC.OU)`",Success" }
					}
				}
			}
		}
	}
	$msgbox.popup("Output has been written to $($objTextBox2.text)", 0, ”Information”, 1)
}

function Expand_Groups ($domain, $groupname, $fullpath, $outfile, $perm)
{
	switch ($domain)
	{
		"NT AUTHORITY" { }
		"BUILTIN" { }
		Default
		{
			if ($domain -ne $lastdomain) { connect-qadservice $domain | out-null }
			$lastdomain = $domain
			if (Get-QADGroup $groupname)
			{
				$members = get-qadgroupmember $groupname
				foreach ($member in $members)
				{
					if (Get-QADGroup $member.samaccountname)
					{
						$domain = $member.ntaccountname.split("\")[0]
						Expand_Groups $domain $member.samaccountname $fullpath $outfile $perm
					}
					$status = (get-qaduser $member.samaccountname -service $domain).accountisdisabled
					add-content -path $outfile -value "`"$($fullpath)`",`"$($groupname)`",$($member.samaccountname),`"$($member.name)`",$($perm),$($status)"
				}
			}
		}
	}
}


$ErrorActionPreference = 'silentlyContinue'
$msgbox = new-object -comobject wscript.shell
$Browser = new-object -com Shell.Application
[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$OpenFileDialog.ShowHelp = $true

#import module for Quest commands
If (-not (Get-PSSnapin -Registered | ?{ $_.Quest.ActiveRoles.ADManagement }))
{
	$QADSnapinPath = "C:\Program Files\Quest Software\Management Shell for AD\Quest.ActiveRoles.ArsPowerShellSnapIn.dll"
	If (Test-Path $QADSnapinPath)
	{
		Import-Module $QADSnapinPath -WarningAction SilentlyContinue | out-null
	}
	Else
	{
		$msgbox.popup("Quest tools not installed.", 0, ”Error”, 1)
		#return
	}
}




$Commands = Get-Command
If ($Commands | ?{ $_.name -eq "Get-QADUser" }) { $QuestLoaded = $true }
Else { $msgbox.popup("Quest tools not installed.", 0, ”Error”, 1) }


$Error.clear()

$WinForm = New-Object Windows.Forms.Form
$WinForm.text = "File Folder Migration Tool"
$WinForm.Size = New-Object Drawing.Size(605, 500)
$WinForm.StartPosition = "CenterScreen"

#code for the tabs and buttons controlling them
$panel1 = new-object System.Windows.Forms.TabPage
$panel2 = new-object System.Windows.Forms.TabPage
$panel3 = new-object System.Windows.Forms.TabPage
$panel4 = new-object System.Windows.Forms.TabPage
$tab_contol1 = new-object System.Windows.Forms.TabControl
$separator = New-Object System.Windows.Forms.GroupBox
$Tooltip = New-Object System.Windows.Forms.ToolTip
$Tooltip.AutomaticDelay = 0
$Tooltip.ToolTipIcon = "info"
$button1 = new-object System.Windows.Forms.Button
$button2 = new-object System.Windows.Forms.Button
$button3 = new-object System.Windows.Forms.Button

$panel1.Location = new-object System.Drawing.Point(4, 22)
$panel1.Name = "tabPage1"
$panel1.Padding = new-object System.Windows.Forms.Padding(3)
$panel1.Size = new-object System.Drawing.Size(259, 52)
$panel1.TabIndex = 0
$panel1.Text = "Permissions"

$panel2.Location = new-object System.Drawing.Point(4, 22)
$panel2.Name = "tabPage2"
$panel2.Padding = new-object System.Windows.Forms.Padding(3)
$panel2.Size = new-object System.Drawing.Size(259, 52)
$panel2.TabIndex = 1
$panel2.Text = "Copy FIles/Folders"

$panel3.Location = new-object System.Drawing.Point(4, 22)
$panel3.Name = "tabPage3"
$panel3.Padding = new-object System.Windows.Forms.Padding(3)
$panel3.Size = new-object System.Drawing.Size(259, 52)
$panel3.TabIndex = 1
$panel3.Text = "Groups"

$panel4.Location = new-object System.Drawing.Point(4, 22)
$panel4.Name = "tabPage4"
$panel4.Padding = new-object System.Windows.Forms.Padding(3)
$panel4.Size = new-object System.Drawing.Size(259, 52)
$panel4.TabIndex = 0
$panel4.Text = "Preferences"

$tab_contol1.Location = new-object System.Drawing.Point(20, 60)
$tab_contol1.Name = "tabControl1"
$tab_contol1.SelectedIndex = 0
$tab_contol1.Size = new-object System.Drawing.Size(500, 400)
#this is to hide the tabs
$TabSizeMode = New-object System.Windows.Forms.TabSizeMode
$TabSizeMode = "Fixed"
$tab_contol1.SizeMode = $TabSizeMode
$tab_contol1.ItemSize = New-Object System.Drawing.Size(0, 1)
$TabAppearance = New-object System.Windows.Forms.TabAppearance
$TabAppearance = "Buttons"
$tab_contol1.Appearance = $TabAppearance

$progressBar1 = New-Object System.Windows.Forms.ProgressBar
$progressBar1.Name = 'progressBar1'
$progressBar1.Style = "Continuous"
$progressBar1.Location = new-object System.Drawing.Size(10, 440)
$progressBar1.size = new-object System.Drawing.Size(450, 10)
$progressBar1.Minimum = 0
$progressBar1.Maximum = 100
$WinForm.Controls.Add($progressBar1)

$Button1 = New-Object System.Windows.Forms.Button
$Button1.Location = New-Object System.Drawing.Size(20, 20)
$Button1.Size = New-Object System.Drawing.Size(75, 23)
$Button1.Text = "Permissions"
$button1.FlatStyle = 'Flat'
$Button1.Add_Click({
	$tab_contol1.SelectTab(0)
	$button1.FlatStyle = 'Flat'
	$button2.FlatStyle = 'Standard'
	$button3.FlatStyle = 'Standard'
	$Button4.FlatStyle = 'Standard'
})
$winForm.Controls.Add($Button1)

$Button2 = New-Object System.Windows.Forms.Button
$Button2.Location = New-Object System.Drawing.Size(100, 20)
$Button2.Size = New-Object System.Drawing.Size(125, 23)
$Button2.Text = "Copy Files/Folders"
$Button2.Add_Click({
	$tab_contol1.SelectTab(1)
	$button1.FlatStyle = 'Standard'
	$button2.FlatStyle = 'Flat'
	$button3.FlatStyle = 'Standard'
	$Button4.FlatStyle = 'Standard'
})
$winForm.Controls.Add($Button2)

$Button3 = New-Object System.Windows.Forms.Button
$Button3.Location = New-Object System.Drawing.Size(230, 20)
$Button3.Size = New-Object System.Drawing.Size(100, 23)
$Button3.Text = "Users/Groups"
$Button3.Add_Click({
	$tab_contol1.SelectTab(2)
	$button1.FlatStyle = 'Standard'
	$button2.FlatStyle = 'Standard'
	$button3.FlatStyle = 'Flat'
	$Button4.FlatStyle = 'Standard'
})
$winForm.Controls.Add($Button3)

$Button4 = New-Object System.Windows.Forms.Button
$Button4.Location = New-Object System.Drawing.Size(335, 20)
$Button4.Size = New-Object System.Drawing.Size(85, 23)
$Button4.Text = "Preferences"
$Button4.Add_Click({
	$tab_contol1.SelectTab(3)
	$button1.FlatStyle = 'Standard'
	$button2.FlatStyle = 'Standard'
	$button3.FlatStyle = 'Standard'
	$Button4.FlatStyle = 'Flat'
})
$winForm.Controls.Add($Button4)

$separator.Location = New-Object System.Drawing.Point(10, 60)
$separator.Name = 'separator'
$separator.Size = New-Object System.Drawing.Size(550, 5)
$winForm.Controls.Add($separator)

$tab_contol1.Controls.Add($panel1)
$tab_contol1.Controls.Add($panel2)
$tab_contol1.Controls.Add($panel3)
$tab_contol1.Controls.Add($panel4)
$WinForm.Controls.Add($tab_contol1)
######end code for tabs

######code for 1st tab
$checkBox4 = New-Object System.Windows.Forms.CheckBox
$checkBox4.Location = New-Object System.Drawing.Point(10, 10)
$checkBox4.Name = 'checkBox4'
$checkBox4.TabIndex = 1
$checkBox4.Text = 'Use Import File for Permissions'
$checkBox4.Size = New-Object System.Drawing.Size(260, 20)
$checkBox4.add_Click({
	if ($checkBox4.Checked)
	{
		$objLabel1.visible = $false
		$objTextBox1.visible = $false
		$Browsebtn.visible = $false
		$objLabelJ.visible = $true
		$objTextBoxJ.Visible = $true
		$BrowsebtnJ.visible = $true
	}
	else
	{
		$objLabel1.visible = $true
		$objTextBox1.visible = $true
		$Browsebtn.visible = $true
		$objLabelJ.visible = $false
		$objTextBoxJ.Visible = $false
		$BrowsebtnJ.visible = $false
	}
})

$objLabelJ = New-Object System.Windows.Forms.Label
$objLabelJ.text = "Enter input file"
$objLabelJ.Location = New-Object System.Drawing.Size(10, 40)
$objLabelJ.Size = New-Object System.Drawing.Size(260, 20)
$objLabelJ.Visible = $false

$objTextBoxJ = New-Object System.Windows.Forms.TextBox
$objTextBoxJ.Location = New-Object System.Drawing.Size(10, 60)
$objTextBoxJ.Size = New-Object System.Drawing.Size(260, 20)
$objTextBoxJ.Visible = $false

$BrowsebtnJ = New-Object System.Windows.Forms.Button
$BrowsebtnJ.Location = New-Object System.Drawing.Size(270, 60)
$BrowsebtnJ.Size = New-Object System.Drawing.Size(75, 23)
$BrowsebtnJ.Text = "Browse"
$BrowsebtnJ.Visible = $false
$BrowsebtnJ.Add_Click({
	$OpenFileDialog.title = "Select Input file"
	$OpenFileDialog.ShowDialog()
	$objTextBoxJ.Text = $OpenFileDialog.filename
})

$objLabel1 = New-Object System.Windows.Forms.Label
$objLabel1.text = "Search Starting Folder"
$objLabel1.Location = New-Object System.Drawing.Size(10, 40)
$objLabel1.Size = New-Object System.Drawing.Size(260, 20)

$objTextBox1 = New-Object System.Windows.Forms.TextBox
$objTextBox1.Location = New-Object System.Drawing.Size(10, 60)
$objTextBox1.Size = New-Object System.Drawing.Size(260, 20)
#$objTextBox1.text = "testing"

$Browsebtn = New-Object System.Windows.Forms.Button
$Browsebtn.Location = New-Object System.Drawing.Size(270, 60)
$Browsebtn.Size = New-Object System.Drawing.Size(75, 23)
$Browsebtn.Text = "Browse"
$Browsebtn.Add_Click({ BrowseFolders $objTextBox1 })

$groupBox1 = New-Object System.Windows.Forms.GroupBox
$groupBox2 = New-Object System.Windows.Forms.GroupBox
$groupBox3 = New-Object System.Windows.Forms.GroupBox
$checkBox1 = New-Object System.Windows.Forms.CheckBox
$checkBox2 = New-Object System.Windows.Forms.CheckBox
$radioButton1 = New-Object System.Windows.Forms.RadioButton
$radioButton2 = New-Object System.Windows.Forms.RadioButton

$groupBox1.Location = New-Object System.Drawing.Point(20, 100)
$groupBox1.Name = 'groupBox1'
$groupBox1.Size = New-Object System.Drawing.Size(150, 100)
$groupBox1.TabIndex = 1
$groupBox1.TabStop = $true
$groupBox1.Text = 'Select Search Scope'

$groupBox2.Location = New-Object System.Drawing.Point(200, 100)
$groupBox2.Name = 'groupBox2'
$groupBox2.Size = New-Object System.Drawing.Size(150, 100)
$groupBox2.TabIndex = 2
$groupBox2.TabStop = $true
$groupBox2.Text = 'Select Search Action'

$groupBox3.Location = New-Object System.Drawing.Point(370, 100)
$groupBox3.Name = 'groupBox3'
$groupBox3.Size = New-Object System.Drawing.Size(150, 100)
$groupBox3.TabIndex = 3
$groupBox3.TabStop = $true
$groupBox3.Text = 'Search Depth Level'

#search depth level field
$objTextBox3 = New-Object System.Windows.Forms.TextBox
$objTextBox3.Location = New-Object System.Drawing.Size(375, 120)
$objTextBox3.Size = New-Object System.Drawing.Size(50, 20)
$objTextBox3.text = 3
$groupBox3.Controls.Add($objTextBox3)

# checkBox1
$checkBox1.Location = New-Object System.Drawing.Point(35, 120)
$checkBox1.Name = 'checkBox1'
$checkBox1.TabIndex = 1
$checkBox1.Text = 'Files'
$groupBox1.Controls.Add($checkBox1)

# checkBox2
$checkBox2.Location = New-Object System.Drawing.Point(35, 140)
$checkBox2.Name = 'checkBox2'
$checkBox2.TabIndex = 2
$checkBox2.Text = 'Folders'
$checkBox2.Checked = $true
$groupBox1.Controls.Add($checkBox2)

# radioButton1
$radioButton1.Location = New-Object System.Drawing.Point(245, 120)
$radioButton1.Name = 'radioButton1'
$radioButton1.TabIndex = 4
$radioButton1.Text = 'Read'
$radioButton1.Checked = $true
$radioButton1.Add_CheckedChanged({ })
$radioButton1.add_Click({
	if ($radioButton1.Checked)
	{
		$objLabel1.visible = $true
		$objTextBox1.visible = $true
		$Browsebtn.Visible = $true
		$objLabelJ.visible = $false
		$objTextBoxJ.Visible = $false
		$BrowsebtnJ.visible = $false
		$checkBox4.Visible = $true
	}
})
$groupBox2.Controls.Add($radioButton1)

# radioButton2
$radioButton2.Location = New-Object System.Drawing.Point(245, 140)
$radioButton2.Name = 'radioButton2'
$radioButton2.TabIndex = 5
$radioButton2.Text = 'Apply'
$radioButton2.add_Click({
	if ($radioButton2.Checked)
	{
		$objLabel1.visible = $false
		$objTextBox1.visible = $false
		$Browsebtn.Visible = $false
		$objLabelJ.visible = $true
		$objTextBoxJ.Visible = $true
		$BrowsebtnJ.visible = $true
		$checkBox4.Visible = $false
		$checkBox4.Checked = $true
	}
})

$groupBox2.Controls.Add($radioButton2)

$RunButton = New-Object System.Windows.Forms.Button
$RunButton.Location = New-Object System.Drawing.Size(100, 280)
$RunButton.Size = New-Object System.Drawing.Size(75, 23)
$RunButton.Text = "Run"
$RunButton.Add_Click({ Main_Code })

$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Size(200, 280)
$CancelButton.Size = New-Object System.Drawing.Size(75, 23)
$CancelButton.Text = "Cancel"
$CancelButton.Add_Click({ $output = $null; $winform.Close() })

$panel1.Controls.Add($objLabel1)
$panel1.Controls.Add($objTextBox1)
$panel1.Controls.Add($Browsebtn)
$panel1.Controls.Add($checkBox1)
$panel1.Controls.Add($checkBox2)
$panel1.Controls.Add($groupBox1)
$panel1.Controls.Add($radioButton1)
$panel1.Controls.Add($radioButton2)
$panel1.Controls.Add($groupBox2)
$panel1.Controls.Add($objTextBox3)
$panel1.Controls.Add($groupBox3)
$panel1.Controls.Add($RunButton)
$panel1.Controls.Add($CancelButton)
$panel1.Controls.Add($checkBox4)
$panel1.Controls.Add($objLabelJ)
$panel1.Controls.Add($objTextBoxJ)
$panel1.Controls.Add($BrowsebtnJ)
#######end code for 1st tab

####### code for 2nd tab
$checkBox3 = New-Object System.Windows.Forms.CheckBox
$checkBox3.Location = New-Object System.Drawing.Point(10, 10)
$checkBox3.Name = 'checkBox3'
$checkBox3.TabIndex = 1
$checkBox3.Text = 'Use Import FIle for Copies'
$checkBox3.Size = New-Object System.Drawing.Size(260, 20)
$checkBox3.add_Click({
	if ($checkBox3.Checked)
	{
		$objLabel4.visible = $false
		$objLabel5.visible = $false
		$objTextBox4.visible = $false
		$objTextBox5.visible = $false
		$Browsebtn3.visible = $false
		$Browsebtn4.visible = $false
		$objLabelI.Visible = $true
		$objTextBoxI.Visible = $true
	}
	else
	{
		$objLabel4.visible = $true
		$objLabel5.visible = $true
		$objTextBox4.visible = $true
		$objTextBox5.visible = $true
		$Browsebtn3.visible = $true
		$Browsebtn4.visible = $true
		$objLabelI.Visible = $false
		$objTextBoxI.Visible = $false
	}
})

$objLabel4 = New-Object System.Windows.Forms.Label
$objLabel4.text = "Source Folder"
$objLabel4.Location = New-Object System.Drawing.Size(10, 40)
$objLabel4.Size = New-Object System.Drawing.Size(260, 20)

$objTextBox4 = New-Object System.Windows.Forms.TextBox
$objTextBox4.Location = New-Object System.Drawing.Size(10, 60)
$objTextBox4.Size = New-Object System.Drawing.Size(260, 20)

$Browsebtn3 = New-Object System.Windows.Forms.Button
$Browsebtn3.Location = New-Object System.Drawing.Size(270, 60)
$Browsebtn3.Size = New-Object System.Drawing.Size(75, 23)
$Browsebtn3.Text = "Browse"
$Browsebtn3.Add_Click({ BrowseFolders $objTextBox4 })

$objLabelI = New-Object System.Windows.Forms.Label
$objLabelI.text = "Enter input file"
$objLabelI.Location = New-Object System.Drawing.Size(10, 40)
$objLabelI.Size = New-Object System.Drawing.Size(260, 20)
$objLabelI.Visible = $false

$objTextBoxI = New-Object System.Windows.Forms.TextBox
$objTextBoxI.Location = New-Object System.Drawing.Size(10, 60)
$objTextBoxI.Size = New-Object System.Drawing.Size(260, 20)
$objTextBoxI.Visible = $false

$BrowsebtnI = New-Object System.Windows.Forms.Button
$BrowsebtnI.Location = New-Object System.Drawing.Size(270, 60)
$BrowsebtnI.Size = New-Object System.Drawing.Size(75, 23)
$BrowsebtnI.Text = "Browse"
$BrowsebtnI.Add_Click({
	$OpenFileDialog.title = "Select Input file"
	$OpenFileDialog.ShowDialog()
	$objTextBoxI.Text = $OpenFileDialog.filename
})

$objLabel5 = New-Object System.Windows.Forms.Label
$objLabel5.text = "Destination Folder"
$objLabel5.Location = New-Object System.Drawing.Size(10, 100)
$objLabel5.Size = New-Object System.Drawing.Size(260, 20)

$objTextBox5 = New-Object System.Windows.Forms.TextBox
$objTextBox5.Location = New-Object System.Drawing.Size(10, 120)
$objTextBox5.Size = New-Object System.Drawing.Size(260, 20)

$Browsebtn4 = New-Object System.Windows.Forms.Button
$Browsebtn4.Location = New-Object System.Drawing.Size(270, 120)
$Browsebtn4.Size = New-Object System.Drawing.Size(75, 23)
$Browsebtn4.Text = "Browse"
$Browsebtn4.Add_Click({ BrowseFolders $objTextBox5 })

$objLabel6 = New-Object System.Windows.Forms.Label
$objLabel6.text = "Enter files to exclude from Copy"
$objLabel6.Location = New-Object System.Drawing.Size(10, 160)
$objLabel6.Size = New-Object System.Drawing.Size(260, 20)

$objTextBox6 = New-Object System.Windows.Forms.TextBox
$objTextBox6.Location = New-Object System.Drawing.Size(10, 180)
$objTextBox6.Size = New-Object System.Drawing.Size(200, 150)
$objTextBox6.AcceptsReturn = $true
$objTextBox6.AcceptsTab = $false
$objTextBox6.Multiline = $true
$objTextBox6.ScrollBars = 'Both'
$objTextBox6.Text = "thumbs.db`r`ndesktop.ini`r`npagefile.sys`r`nhiberfil.sys`r`n`*.DS_Store`r`n`*.apdisk"

$checkBox5 = New-Object System.Windows.Forms.CheckBox
$checkBox5.Location = New-Object System.Drawing.Point(250, 200)
$checkBox5.Name = 'checkBox5'
$checkBox5.TabIndex = 2
$checkBox5.Text = 'Mirror'
$checkBox5.Checked = $false

$checkBox6 = New-Object System.Windows.Forms.CheckBox
$checkBox6.Location = New-Object System.Drawing.Point(250, 240)
$checkBox6.Name = 'checkBox6'
$checkBox6.TabIndex = 2
$checkBox6.Text = 'Copy Perms'
$checkBox6.Checked = $false

$objLabelR = New-Object System.Windows.Forms.Label
$objLabelR.Location = New-Object System.Drawing.Size(400, 230)
$objLabelR.Size = New-Object System.Drawing.Size(150, 20)
$objLabelR.Visible = $false
$objLabelR.Text = "Copying Files ..."

$RunButton2 = New-Object System.Windows.Forms.Button
$RunButton2.Location = New-Object System.Drawing.Size(100, 350)
$RunButton2.Size = New-Object System.Drawing.Size(75, 23)
$RunButton2.Text = "Run"
$RunButton2.Add_Click({ $output = Robocopy_Prep })

$CancelButton2 = New-Object System.Windows.Forms.Button
$CancelButton2.Location = New-Object System.Drawing.Size(200, 350)
$CancelButton2.Size = New-Object System.Drawing.Size(75, 23)
$CancelButton2.Text = "Cancel"
$CancelButton2.Add_Click({ $output = $null; $winform.Close() })

$panel2.Controls.Add($objTextBox4)
$panel2.Controls.Add($Browsebtn3)
$panel2.Controls.Add($objLabel5)
$panel2.Controls.Add($objTextBox5)
$panel2.Controls.Add($Browsebtn4)
$panel2.Controls.Add($objLabel6)
$panel2.Controls.Add($objTextBox6)
$panel2.Controls.Add($RunButton2)
$panel2.Controls.Add($CancelButton2)
$panel2.Controls.Add($objLabelR)
$panel2.Controls.Add($checkBox3)
$panel2.Controls.Add($objLabelI)
$panel2.Controls.Add($objTextBoxI)
$panel2.Controls.Add($BrowsebtnI)
$panel2.Controls.Add($checkBox5)
$panel2.Controls.Add($checkBox6)
####### end code for 2nd tab

####### code for 3rd tab
$objLabel9 = New-Object System.Windows.Forms.Label
$objLabel9.text = "Expand Groups:"
$objLabel9.Font.Underline = $true
$Tooltip.SetToolTip($objLabel10, "This will expand any groups that are found in the input permissions file")
$objLabel9.Location = New-Object System.Drawing.Size(10, 20)
$objLabel9.Size = New-Object System.Drawing.Size(260, 30)

$checkBox7 = New-Object System.Windows.Forms.CheckBox
$checkBox7.Location = New-Object System.Drawing.Point(270, 20)
$checkBox7.Name = 'checkBox7'
$checkBox7.Text = 'Expand all from Directory'
$checkBox7.Size = New-Object System.Drawing.Size(260, 30)
$checkBox7.Checked = $false

$objLabel8 = New-Object System.Windows.Forms.Label
$objLabel8.text = "Select Input"
$objLabel8.Location = New-Object System.Drawing.Size(10, 50)
$objLabel8.Size = New-Object System.Drawing.Size(260, 20)

$objTextBox8 = New-Object System.Windows.Forms.TextBox
$objTextBox8.Location = New-Object System.Drawing.Size(10, 70)
$objTextBox8.Size = New-Object System.Drawing.Size(360, 20)

$Browsebtn5 = New-Object System.Windows.Forms.Button
$Browsebtn5.Location = New-Object System.Drawing.Size(370, 70)
$Browsebtn5.Size = New-Object System.Drawing.Size(75, 23)
$Browsebtn5.Text = "Browse"
$Browsebtn5.Add_Click({
	if ($checkBox7.Checked)
	{
		BrowseFolders $objTextBox8
	}
	else
	{
		$OpenFileDialog.title = "Select Input file"
		$OpenFileDialog.ShowDialog()
		$objTextBox8.Text = $OpenFileDialog.filename
	}
})

$objLabel10 = New-Object System.Windows.Forms.Label
$objLabel10.text = "Prep Users/Groups:"
$objLabel10.Font.Underline = $true
$Tooltip.SetToolTip($objLabel10, "This will create groups that do not exist, add users to the groups and move users and computers to new OU")
$objLabel10.Location = New-Object System.Drawing.Size(10, 120)
$objLabel10.Size = New-Object System.Drawing.Size(260, 30)

$objLabel11 = New-Object System.Windows.Forms.Label
$objLabel11.text = "Select Input file"
$objLabel11.Location = New-Object System.Drawing.Size(10, 150)
$objLabel11.Size = New-Object System.Drawing.Size(260, 20)

$objTextBox11 = New-Object System.Windows.Forms.TextBox
$objTextBox11.Location = New-Object System.Drawing.Size(10, 170)
$objTextBox11.Size = New-Object System.Drawing.Size(360, 20)

$checkBox8 = New-Object System.Windows.Forms.CheckBox
$checkBox8.Location = New-Object System.Drawing.Point(50, 200)
$checkBox8.Name = 'checkBox8'
$checkBox8.Text = 'Create groups'
$checkBox8.Size = New-Object System.Drawing.Size(100, 30)
$checkBox8.Checked = $false

$checkBox9 = New-Object System.Windows.Forms.CheckBox
$checkBox9.Location = New-Object System.Drawing.Point(200, 200)
$checkBox9.Name = 'Checkbox9'
$checkBox9.Text = 'Populate Groups/Move Users and PCs'
$checkBox9.Size = New-Object System.Drawing.Size(260, 30)
$checkBox9.Checked = $false

$Browsebtn6 = New-Object System.Windows.Forms.Button
$Browsebtn6.Location = New-Object System.Drawing.Size(370, 170)
$Browsebtn6.Size = New-Object System.Drawing.Size(75, 23)
$Browsebtn6.Text = "Browse"
$Browsebtn6.Add_Click({
	$OpenFileDialog.title = "Select Input file"
	$OpenFileDialog.ShowDialog()
	$objTextBox11.Text = $OpenFileDialog.filename
})

$RunButton3 = New-Object System.Windows.Forms.Button
$RunButton3.Location = New-Object System.Drawing.Size(100, 280)
$RunButton3.Size = New-Object System.Drawing.Size(75, 23)
$RunButton3.Text = "Run"
$RunButton3.Add_Click({ Groups_Tab })

$CancelButton3 = New-Object System.Windows.Forms.Button
$CancelButton3.Location = New-Object System.Drawing.Size(200, 280)
$CancelButton3.Size = New-Object System.Drawing.Size(75, 23)
$CancelButton3.Text = "Close"
$CancelButton3.Add_Click({ $output = $null; $winform.Close() })

$panel3.Controls.Add($objLabel8)
$panel3.Controls.Add($objTextBox8)
$panel3.Controls.Add($Browsebtn5)
$panel3.Controls.Add($RunButton3)
$panel3.Controls.Add($CancelButton3)
$panel3.Controls.Add($objLabel9)
$panel3.Controls.Add($objLabel10)
$panel3.Controls.Add($objLabel11)
$panel3.Controls.Add($objTextBox11)
$panel3.Controls.Add($Browsebtn6)
$panel3.Controls.Add($checkBox7)
$panel3.Controls.Add($checkBox8)
$panel3.Controls.Add($checkBox9)
####### end code for 3rd tab

####### code for 4th tab
$objLabel2 = New-Object System.Windows.Forms.Label
$objLabel2.text = "Output Folder"
$objLabel2.Location = New-Object System.Drawing.Size(10, 20)
$objLabel2.Size = New-Object System.Drawing.Size(80, 20)

$objTextBox2 = New-Object System.Windows.Forms.TextBox
$objTextBox2.Location = New-Object System.Drawing.Size(100, 20)
$objTextBox2.Size = New-Object System.Drawing.Size(260, 20)
$objTextBox1.TabIndex = 1
#$objTextBox2.text = $PWD.path

$Browsebtn2 = New-Object System.Windows.Forms.Button
$Browsebtn2.Location = New-Object System.Drawing.Size(370, 20)
$Browsebtn2.Size = New-Object System.Drawing.Size(75, 23)
$Browsebtn2.Text = "Browse"
$Browsebtn2.Add_Click({ BrowseFolders $objTextBox2 })

$objLabel7 = New-Object System.Windows.Forms.Label
$objLabel7.text = "Preferences"
$objLabel7.Location = New-Object System.Drawing.Size(10, 60)
$objLabel7.Size = New-Object System.Drawing.Size(80, 20)

$objTextBox7 = New-Object System.Windows.Forms.TextBox
$objTextBox7.Location = New-Object System.Drawing.Size(100, 60)
$objTextBox7.Size = New-Object System.Drawing.Size(260, 20)

$SaveButton = New-Object System.Windows.Forms.Button
$SaveButton.Location = New-Object System.Drawing.Size(100, 340)
$SaveButton.Size = New-Object System.Drawing.Size(75, 23)
$SaveButton.Text = "Save"
$SaveButton.Add_Click({ Save_Preferences })

$panel4.Controls.Add($objTextBox2)
$panel4.Controls.Add($objLabel2)
$panel4.Controls.Add($Browsebtn2)
$panel4.Controls.Add($objLabel7)
$panel4.Controls.Add($objTextBox7)
$panel4.Controls.Add($SaveButton)
####### end code for 4th tab

$WinForm.Add_Load({
	$Global:optionsfile = "$($PWD.Path)\preferences.xml"
	if (test-path $optionsfile)
	{
		$Global:Optionshash = Import-Clixml -Path $optionsfile -ea 'SilentlyContinue'
		$objTextBox2.Text = $Optionshash['outputFolder']
	}
	else
	{
		$Global:Optionshash = @{ "outputFolder" = "Enter Output Folder" }
	}
	
})

$WinForm.Add_Shown($WinForm.Activate())
$WinForm.showdialog() | Out-Null
$output
