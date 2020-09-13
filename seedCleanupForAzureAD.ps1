
# ************************************************************************
# DISCLAIMER: This script is provided "as-is" without any warranty of
# any kind, either expressed or implied.
# ************************************************************************


# Import a decrypted base32 seed file in CSV format:
Import-Csv C:\seeds.csv |
# Select ('UPN' is added) what columns we are interested in for working with Microsoft O365 & Azure AD: 
Select-object "UPN","Serial Number","Secret Key","Time Interval","Manufacturer","Model" |
# Correct the sorting so that it is ascending order by authenticator serial number instead of random order:
Sort-Object "Serial Number" | 
# Replace "GA" with "Thales" so that the customer has visibilty of the vendor in the Microsoft Azure AD portal:
ForEach-Object {
    $_.Manufacturer = $_.Manufacturer -replace 'GA', 'Thales'
    $_
} | 
# Also replace "LT" with "OTP110" so that the customer has visibilty of the model in the Microsoft Azure AD portal:
ForEach-Object {
    $_.Model = $_.Model -replace 'LT', 'OTP110'
    $_
} | 
# Export our changes to a new file ready for import with Microsoft Azure AD:
Export-Csv -Path "C:\correctedSeeds.csv" -NoTypeInformation

