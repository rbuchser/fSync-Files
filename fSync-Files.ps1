Function fSync-Files {
	<#
		.NOTES
			Author: Buchser Roger
			
		.SYNOPSIS
			Function will synchronize a File to other Servers.
			
		.DESCRIPTION
			Function will synchronize a File to other Servers in Enviroment. If the File to Sync is older than a File to be replaced, a Message will appear.
			
		.PARAMETER SourceFiles
			Define the Files to be synchronized against Servers.
			
		.PARAMETER TargetServers
			Define all Target Servers. Deafult is all Servers in Exchange Environment.
			
		.EXAMPLE
			fSync-Files -SourceFiles $PROFILE.AllUsersCurrentHost -TargetServers (1..6 | ForEach {"LAB-SRV-0$_"})
			Synchronize the Powerhell Profile to Servers LAB-SRV-01 to LAB-SRV-06.
			
		.EXAMPLE
			fSync-Files Result.csv LAB-MGT-03
			Synchronize the File 'Result.csv' from current Directory to Server 'LAB-MGT-03' in the same Directory.
			
		.EXAMPLE
			fSync-Files -SourceFiles C:\Scripts\*.ps1 -TargetServers LAB-EX-01,LAB-EX-02,LAB-EX-03,LAB-EX-04
			Synchronize all Powershell Scripts *.ps1 to other Servers.
	#>
	
	PARAM (
		[Parameter(Mandatory=$True,Position=0)][String[]]$SourceFiles,
		[Parameter(Mandatory=$True,Position=1)][String[]]$TargetServers
	)
	
	# Function Variables
	[String]$CurrentDate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
		
	# Define ServerTargetScope
	[String[]]$ServerTargetScope = $TargetServers | Where {$_ -notmatch $Env:COMPUTERNAME} | Sort
	[String[]]$SourceItems = Get-ChildItem $SourceFiles -ErrorAction SilentlyContinue
		
	If (($SourceItems) -AND ($ServerTargetScope)) {
		
		$Continue = ""
		While ($Continue -notmatch "[Y|N]") {
			$SourceItems | Select LastWriteTime,Name,@{E={$_.Directory};N='Source Directory'} | Sort Name | ft -AutoSize
			Write-Host "INFO: Synchronizing total $(($SourceItems | Measure).Count) Files to total $(($ServerTargetScope | Measure).Count) Target Servers." -f White
			Write-Host "$($ServerTargetScope -Join ' | ')"
			Write-Host
			Write-Host "Do you want to Continune? (Y/N) " -f Cyan -NoNewLine
			$Continue = Read-Host
			Write-Host
		}
		
		If ($Continue -eq "N") {
			Write-Host "`nScript will abord... Bye!`n" -f Yellow
			Break
		}
	
		ForEach ($SourceFile in $SourceItems) {
			$ErrorCount = $Null
			If ((Test-Path $SourceFile) -AND (($ServerTargetScope | Measure).Count -ge 1)) {
				$FileToSync = Get-Item $SourceFile
				$SourceFileDate = $FileToSync.LastWriteTime

				# Check for newer Files
				ForEach ($Server in $ServerTargetScope) {
					If ($FileToSync.DirectoryName -like "\\*\*") {
						$TargetFile = $FileToSync.FullName
					} Else {
						$TargetFile = "\\$Server\$(($FileToSync.DirectoryName).Replace(':','$'))\$($FileToSync.Name)"
					}
					If (Test-Path $TargetFile) {
						$TargetFileDate = (Get-Item $TargetFile).LastWriteTime
						If ($SourceFileDate -lt $TargetFileDate) {
							Write-Host "The File that you want to sync from Source Server `'$($Env:COMPUTERNAME)`' is older than the File on Target Server `'$Server`'!!" -f Red
							Write-Host "File Name:        $($FileToSync.Name)" -f DarkGray
							Write-Host "Directory:        $($SourceFile.Directory)" -f DarkGray
							Write-Host "Source File Date: $($SourceFileDate.ToString('yyyy-MM-dd HH:mm:ss'))" -f White -NoNewLine
							Write-Host "  `[$($Env:COMPUTERNAME)`]" -f Gray
							Write-Host "Target File Date: $($TargetFileDate.ToString('yyyy-MM-dd HH:mm:ss'))" -f White -NoNewLine
							Write-Host "  `[$Server`]" -f Gray
							Write-Host
							$ErrorCount++
						}
					}
				}

				If ($ErrorCount) {
					$Continue = ""
					While ($Continue -notmatch "[Y|N]") {
						Write-Host "WARNING: Do you want to Continune overwriting newer Files with older Files? (Y/N) " -f Yellow -NoNewLine
						$Continue = Read-Host
						Write-Host
					}
					If ($Continue -eq "N") {
						Write-Host "`nScript will abord... Bye!`n" -f Yellow
						Break
					}
				}
				
				$Result = @()
				ForEach ($Server in $ServerTargetScope) {
					
					If ($FileToSync.DirectoryName -like "\\*\*") {
						$DestinationPath = "\\$Server\$($FileToSync.DirectoryName.Split("\",4)[-1])"
					} Else {
						$DestinationPath = "\\$Server\$(($FileToSync.DirectoryName).Replace(':','$'))\"
					}

					If (Test-Path $DestinationPath) {
						Try {
							Copy-Item -Path $FileToSync.FullName -Destination $DestinationPath | Out-Null
							Write-Host "Successfully copying File `'$($FileToSync.Name)`' to Server `'$Server`'" -f Green
							$Result += "$CurrentDate;Success;$($FileToSync.FullName);$($DestinationPath + $($FileToSync.Name));"
						} Catch {
							Write-Host "Error copying `'$($FileToSync.Name)`' to Server `'$Server`'" -f Red
							$Result += "$CurrentDate;Fail;$($FileToSync.FullName);$($DestinationPath + $($FileToSync.Name));$(($Error[0].Exception.LABsage).ToString())"
							$Error[0]
						}
					} Else {
						New-Item $DestinationPath -Type Directory -ErrorAction SilentlyContinue | Out-Null
						If (Test-Path $DestinationPath) {
							Try {
								Copy-Item -Path $FileToSync.FullName -Destination $DestinationPath | Out-Null
								Write-Host "Successfully copying File `'$($FileToSync.Name)`' to Server `'$Server`'" -f Green
								$Result += "$CurrentDate;Success;$($FileToSync.FullName);$($DestinationPath + $($FileToSync.Name));"
							} Catch {
								Write-Host "Error copying `'$($FileToSync.Name)`' to Server `'$Server`'" -f Red
								$Result += "$CurrentDate;Fail;$($FileToSync.FullName);$($DestinationPath + $($FileToSync.Name));$(($Error[0].Exception.LABsage).ToString())"
								$Error[0]
							}
						} Else {	
							Write-Host "Cannot find Destination Directory $DestinationPath`... `nScript will abord... Bye!`n" -f Yellow
							$Error[0]
						}
					}
				}
				Write-Host
			} ElseIf (!(Test-Path $SourceFile)) {
				Write-Host "Cannot find Source Files... `nScript will abord... Bye!`n" -f Yellow
				$Error
				Break
			} Else {
				Write-Host "Cannot find Target Server... `nScript will abord... Bye!`n" -f Yellow
				Break
			}
		}
	} ElseIf (!($ServerTargetScope)){
		Write-Host "`nCannot find a Server in TargetScope to Sync Files... `n" -f Yellow
	} Else {
		Write-Host "`nCannot find any Source Files to Sync... `n" -f Yellow
	}
}
