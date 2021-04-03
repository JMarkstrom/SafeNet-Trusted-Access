  
##########################################################################
# OATH authenticator import into Microsoft Azure AD                        
##########################################################################
# version: 1.1
# last updated on: 2021-04-03 by Jonas Markström
# see readme.md for more info.
#
# NOTE: This script takes in the generic Thales authenticator seed file for 3rd
# party use and manipulates it for compliance with current Microsoft OATH import 
# requirements. In the script, the OTP110 authenticator is used, but the script 
# can be easily modified to support the Thales OTP Display Card and others.
#
# LIMITATIONS/ KNOWN ISSUES: N/A
#
# ************************************************************************
# DISCLAIMER: This script is provided "as-is" without any warranty of
# any kind, either expressed or implied.
# ************************************************************************
#
##########################################################################

# Clear the screen (because why not):
Clear-Host


##########################################################################
# CHECKS AND BALANCES:

# Inform the user that the selected file will be overwritten:
[console]::beep(300, 150); Write-Host "`nPLEASE READ:`n============`nContinuing script execution you will be asked to browse to a source file. This source file MUST be a decrypted Thales OTP 110 seed file in CSV format.`nThe script will then modify the EXISTING file by shifting and renaming its columns. Exit the script if you want to backup the original file.`n"

# Ask confirmation:
do {
    $ans = Read-Host "Continue!? y/n"
    if ($ans -eq 'N') { return }
}
until($ans -eq 'Y')(Write-Output "`nOK, now browse to your seed file (window may not be in focus)")


##########################################################################
# BROWSE TO SOURCE FILE FUNCTION:

Function Open-File ([string]$initialDirectory) {

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
        
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = "Save generated Microsoft Azure seed file as:"
    $OpenFileDialog.initialDirectory = $OpenInitialPath
    $OpenFileDialog.filter = "CSV (*.csv)| *.csv"
    $OpenFileDialog.FileName = $OpenFileName
    $OpenFileDialog.ShowDialog() | Out-Null
    return $OpenFileDialog.filename
}

##########################################################################
# SEED FILE MODIFICATION:

# Call the browse function above and store the selected file in a variable:
$results = Open-File

# Reformat the selected file:
$reformat = Import-Csv $results |
# Select ('UPN' is added) what columns we are interested in for working with Microsoft O365 & Azure AD: 
Select-object "UPN", "Serial Number", "Secret Key", "Time Interval", "Manufacturer", "Model" |
# Correct the sorting so that it is ascending order by authenticator serial number instead of random order:
Sort-Object "Serial Number" | 
# Replace "GA" with "Thales" so that the customer has visibilty of the vendor in the Microsoft Azure AD portal:
ForEach-Object {
    # Replace "GA" with "Thales" so that the customer has visibility of the vendor in the Microsoft Azure AD portal:
    $_.Manufacturer = $_.Manufacturer -replace 'GA', 'Thales'
    # Also replace "LT" with "OTP110" so that the customer has visibility of the model in the Microsoft Azure AD portal:
    $_.Model = $_.Model -replace 'LT', 'OTP 110'
    $_
    
}

# Save the reformatted data to the existing file removing double quotes:
Write-Output $reformat | Export-CSV -Path $results -NoTypeInformation
(Get-Content $results -Raw).replace('"', '') | Set-Content $results

# Write a confirmation and then exit the script:
[console]::beep(300, 150); Write-Host "`nOK, we are done! Your original file has been modified."
Read-host "Press any key to exit"
Return 


