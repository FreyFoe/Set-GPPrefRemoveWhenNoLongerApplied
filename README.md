# Set-GPPrefRemoveWhenNoLongerApplied
This function can be used to Enable the "Remove When No Longer Applied" on Group Policy Registry Preferences

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
This would query the Group Policy Named "Standard Example Policy" and pull back information on any Group Policy Registry Preferences which do not have this setting configured and give you an option to change it.

Set-GPPrefRemoveWhenNoLongerApplied -GroupPolicyName "Standard Example Policy" -Silent
This would query the Group Policy Named "Standard Example Policy" and pull back information on any Group Policy Registry Preferences which do not have this setting configured and change it.

Within a Script:

Get-GPO -All | Foreach-Object { Set-GPPrefRemoveWhenNoLongerApplied -GroupPolicyName $_.DisplayName -Silent }
This would find all group policies and recursively run the function silently against them all.

.NOTES
Modified Date: 2023-07-19
Version 1.2

#>
