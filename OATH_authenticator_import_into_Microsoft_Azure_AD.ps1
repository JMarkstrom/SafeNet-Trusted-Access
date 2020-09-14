  
##########################################################################
# OATH authenticator import into Microsoft Azure AD                        
##########################################################################
# version: 1.0
# last updated on: 2020-09-13
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

##########################################################################
# Settings:
$inputFile = "C:\seeds.csv" # Replace with path to decrypted csv file

# This function gets called to create a new CSV file for Microsoft Azure AD:
Function formatForAzure {
    Import-Csv $inputFile |
    # Select ('UPN' is added) what columns we are interested in for working with Microsoft O365 & Azure AD: 
    Select-object "UPN","Serial Number","Secret Key","Time Interval","Manufacturer","Model" |
    # Correct the sorting so that it is ascending order by authenticator serial number instead of random order:
    Sort-Object "Serial Number" | 
    # Replace "GA" with "Thales" so that the customer has visibilty of the vendor in the Microsoft Azure AD portal:
    ForEach-Object {
    # Replace "GA" with "Thales" so that the customer has visibility of the vendor in the Microsoft Azure AD portal:
    $_.Manufacturer = $_.Manufacturer -replace 'GA', 'Thales'
    # Also replace "LT" with "OTP110" so that the customer has visibility of the model in the Microsoft Azure AD portal:
    $_.Model = $_.Model -replace 'LT', 'OTP110'
    $_
}
}

# This function prompts the user to save the new CSV file created:
Function Save-File ([string]$initialDirectory) {

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $OpenFileDialog.Title = "Save generated Microsoft Azure seed file as:"
    $OpenFileDialog.initialDirectory = $SaveInitialPath
    $OpenFileDialog.filter = "CSV (*.csv)| *.csv"
	$OpenFileDialog.FileName = $SaveFileName
    $OpenFileDialog.ShowDialog() | Out-Null
    return $OpenFileDialog.filename
}

# Here we call the create CSV function and store it in a variable:
$results = formatForAzure

# Here we call the function to save the file prompting the user for location:
$SaveMyFile = Save-File
Write-Output $results | Export-CSV $SaveMyFile -NoTypeInformation
