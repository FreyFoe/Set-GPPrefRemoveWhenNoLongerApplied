Function Set-GPPrefRemoveWhenNoLongerApplied
    {
        <#
        .SYNOPSIS
        This Function is used to enable the option "Remove this item if it is no longer applied" to Registry Preferences in a Group Policy

        .DESCRIPTION
        This should be run in Powershell on a Domain Controller.
        You need to specify the Group Policy Object Name you are looking to check/adjust.
        It will then go through and check for settings in both the User and Machine by getting the content from their XML files.

        Once this has been done, it will then tell you there are X out of Y items in the policy which do not have the setting configured.
        If you are running this with the silent parameter, it will just adjust them automatically.
        Otherwise, it will display a pop-up, asking if you'd like to proceed with changing them.

        .PARAMETERS
        -GroupPolicyName
        This is required as it will be used to query the GPO you want to query

        -Silent
        This will cause the script to automatically correct the values without prompting you.

        -Scope
        This will allow you to pick from "User" "Machine" or "All"
        If you do not specify this, it will use all by default.

        .EXAMPLES
        Set-GPPrefRemoveWhenNoLongerApplied -GroupPolicyName "Standard Example Policy"
        This would query the Group Policy Named "Standard Example Policy" and pull back information on any Group Policy Registry Preferences which do not have this setting configured and give you the option to change it.

        Set-GPPrefRemoveWhenNoLongerApplied -GroupPolicyName "Standard Example Policy" -Silent
        This would query the Group Policy Named "Standard Example Policy" and pull back information on any Group Policy Registry Preferences which do not have this setting configured and change it.

        Within a Script:

        Get-GPO -All | Foreach-Object { Set-GPPrefRemoveWhenNoLongerApplied -GroupPolicyName $_.DisplayName -Silent }
        This would find all group policies and recursively run the function silently against them all.

        .NOTES
        Modified Date: 2023-07-19
        Version 1.2

        #>
        Param(
            [parameter(Mandatory=$True, position=0)]
            [string]$GroupPolicyName,
            [parameter(Mandatory=$False, position=1)]
            [switch]$Silent,
            [parameter(Mandatory=$False, position=2)]
            [ValidateSet('User','Machine','All')]
            [string]$Scope
            )

        IF (!$Scope) { $Scope = 'All' }
        Add-Type -AssemblyName System.Windows.Forms

        $OrignalPref = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
        IF ((Get-WindowsFeature -Name GPMC -ErrorAction SilentlyContinue).InstallState -ne "Installed")
            {
                Write-Host "Adding GPMC Module to Powershell..." -ForegroundColor Yellow
                Install-WindowsFeature -Name GPMC -IncludeAllSubFeature -IncludeManagementTools -ErrorAction SilentlyContinue -Confirm:$false
                Write-Host "Installed!" -ForegroundColor Green
            }
        $ProgressPreference = $OrignalPref

        IF ((Get-WmiObject -Class Win32_OperatingSystem).ProductType -ne "2")
            {
                Write-Host "!!!Warning!!!`n`nThis is not a Domain Controller.`nThis function must be used on the Domain Controller"
            }
        ELSE
            {
                $GPO = Get-GPO -Name $GroupPolicyName
                $MachinePath = "\\$($GPO.DomainName)\SYSVOL\$($GPO.DomainName)\Policies\{$($GPO.ID)}\Machine\Preferences\Registry\Registry.xml"
                $UserPath = "\\$($GPO.DomainName)\SYSVOL\$($GPO.DomainName)\Policies\{$($GPO.ID)}\User\Preferences\Registry\Registry.xml"
                $XMLPaths = New-Object System.Collections.Generic.List[PSObject] #### - Create a blank collections object to Popluate With Server Type Options- ####
                IF ($Scope -match 'ALL|MACHINE') { $XMLPaths.Add((New-Object -TypeName PSCustomObject  -Property @{Path=$MachinePath;Desc="Machine"})) }
                IF ($Scope -match 'ALL|USER') { $XMLPaths.Add((New-Object -TypeName PSCustomObject  -Property @{Path=$UserPath;Desc="User"})) }

                Foreach ($XMLPath in $XMLPaths)
                    {
                        Write-Host "Checking for $($XMLPath.Desc) Setting..." -ForegroundColor Magenta
                        IF (!(Test-Path -LiteralPath $XMLPath.Path -ErrorAction SilentlyContinue))
                            {
                                Write-Host "No $($XMLPath.Desc) Settings Found!" -ForegroundColor Cyan
                            }
                        ELSE
                            {
                                Write-Host "$($XMLPath.Desc) Settings Found!" -ForegroundColor Yellow
                                Write-Host "Checking Registry Preferences in $($XMLPath.Desc) Settings..." -ForegroundColor Yellow
                                [xml]$XMLContent = Get-Content $XMLPath.Path
                                $RegistrySettings = $XMLContent.Registrysettings.Registry
                                $RegistrySettingsNotRemoved = $RegistrySettings | Where-Object RemovePolicy -eq $null
                                IF (!$RegistrySettingsNotRemoved)
                                    {
                                        Write-Host "All $($RegistrySettings.count) Preferences Have `"Remove this item if it is no longer applied`" Set!" -ForegroundColor Green
                                    }
                                ELSE
                                    {
                                        $Message = "Warning:`n`n$($RegistrySettingsNotRemoved.name.count) out of $($RegistrySettings.Count) does not have the option:`n`"Remove this item if it is no longer applied`" Set!`n`nPress 'Yes' to set this on all items.`nPress No to ignore these"
                                        $Title = "Settings Incorrect!"
                                        IF ($Silent)
                                            {
                                                While ($RegistrySettingsNotRemoved)
                                                    {
                                                        Foreach ($RegSetting in $RegistrySettingsNotRemoved)
                                                            {
                                                                $RegSetting.SetAttribute("removePolicy","1")
                                                                $RegSetting.SetAttribute("bypassErrors","1") 
                                                            }
                                                        $XMLContent.Save($XMLPath.Path)
                                                        Start-Sleep 1
                                                        [xml]$XMLContent = Get-Content $XMLPath.Path
                                                        $RegistrySettings = $XMLContent.Registrysettings.Registry
                                                        $RegistrySettingsNotRemoved = $RegistrySettings | Where-Object RemovePolicy -eq $null
                                                    }
                                                Write-Host "Adjusted! No More Incorrect Settings!" -ForegroundColor Yellow
                                            }
                                        ELSE
                                            {
                                                IF (([System.Windows.Forms.MessageBox]::Show($Message,$Title, "YesNo" , "Question" , "Button1")) -eq "Yes")
                                                    {
                                                        While ($RegistrySettingsNotRemoved)
                                                            {
                                                                Foreach ($RegSetting in $RegistrySettingsNotRemoved)
                                                                    {
                                                                        $RegSetting.SetAttribute("removePolicy","1")
                                                                        $RegSetting.SetAttribute("bypassErrors","1") 
                                                                    }
                                                                $XMLContent.Save($XMLPath.Path)
                                                                Start-Sleep 1
                                                                [xml]$XMLContent = Get-Content $XMLPath.Path
                                                                $RegistrySettings = $XMLContent.Registrysettings.Registry
                                                                $RegistrySettingsNotRemoved = $RegistrySettings | Where-Object RemovePolicy -eq $null
                                                            }
                                                        Write-Host "Adjusted! No More Incorrect Settings!" -ForegroundColor Yellow
                                                    }
                                            }
                                    }
                            }
                    }
            }
    }
