##########################################################################
# O365 Federation with SafeNet Trusted Access (STA)                   
##########################################################################
# version: 1.0
# last updated on: 2019-11-21
# see readme.md for more info.
#
# ************************************************************************
# DISCLAIMER: This script is provided "as-is" without any warranty of
# any kind, either expressed or implied.
# ************************************************************************

# STA welcome message:
Clear-Host
$disclaimer = @'
--------------------------------------------------------------------------------------------------------------
Welcome to O365 federation with:
   _____        __     _   _      _     _______             _           _                                
  / ____|      / _|   | \ | |    | |   |__   __|           | |         | |     /\                        
 | (___   __ _| |_ ___|  \| | ___| |_     | |_ __ _   _ ___| |_ ___  __| |    /  \   ___ ___ ___ ___ ___ v.1.0
  \___ \ / _` |  _/ _ | . ` |/ _ | __|    | | '__| | | / __| __/ _ \/ _` |   / /\ \ / __/ __/ _ / __/ __|
  ____) | (_| | ||  __| |\  |  __| |_     | | |  | |_| \__ | ||  __| (_| |  / ____ | (_| (_|  __\__ \__ \
 |_____/ \__,_|_| \___|_| \_|\___|\__|    |_|_|   \__,_|___/\__\___|\__,_| /_/    \_\___\___\___|___|___/

This script allows you to federate Office365 (O365) to SafeNet Trusted Access (STA) and in addition it allows
you to return a previously federated organization to its default managed state.

DISCLAIMER: This script is provided "as-is" without any warranty of any kind, either expressed or implied.
==============================================================================================================
'@

##########################################################################
# DISPLAY LOGO:
$disclaimer

##########################################################################
# PREREQUISITES:

Start-Sleep -s 1
#Check if MSOnline module is installed:
Write-Verbose "Checking if MSOnline module is installed"

if (Get-Module -ListAvailable -Name MSOnline) {
    Write-Output "`nNOTE: We've checked and all prerequisites looks to be met!`n"
}
else {
    function Find-Dependencies-Menu {
        param (
            [string]$Title = 'install modules menu:'
        )

        [console]::beep(300, 150); Write-Output  "`nNOTE: We've checked and we've found a required module (MSOnline) to be missing`n"
        pause
        Write-Output " `n Press 'i' to install missing module(s)"
        Write-Output " Press 'q' to quit and exit"
    }


    # Install MSOnline if not installed
    Function Install-Prerequisites {
        Write-Verbose "Trying to install modules..."
        #TODO: Exit the script on error here!
        Install-Module MSOnline -Scope CurrentUser 
    }

    # Menu loop to manage dependency installation:
    do {
        Find-Dependencies-Menu

        $input = Read-Host "`nMake a selection"
        switch ($input) {
            'i' {
                Clear-Host
                Install-Prerequisites
            }

            'q' {
                return
            }
        }
        pause
    }
    until ($input -eq 'i')

}

# Just wait a bit before returning to main menu:
Start-Sleep -s 2


##########################################################################
# MAIN MENU:


# Prompt user to select to federate to STA or return to original state
function Select-Federation-Task-Menu {
    param (
        [string]$Title = 'Office365 federation with STA menu:'
    )
    Write-Output  "`nTell us what you would like to do today!`n"
    Write-Output " Press '1' to federate to SafeNet Trusted Access (STA)"
    Write-Output " Press '2' to return federated domain to its default managed state"
    Write-Output " Press '3' to test authentication to Office365"
    Write-Output " Press 'q' to quit and exit"
}


##########################################################################
# NEW FEDERATION FUNCTION:


Function New-Federation {
    Write-Output "`nNOTE: Please authenticate as an Office365 admin when prompted!"
    Start-Sleep -s 2
    Clear-Host
    # Before running any commands we must connect to Office365:
    Write-Verbose "Connecting to Office365 so that we may run our commands"
    Connect-MsolService

    # Of all domains, get the one that is the first created (initial):
    Write-Verbose "Trying to get the initial domain so we can set it as default"
    $targetDefaultDomain = ((get-msoldomain | Where-Object { $_.isinitial -eq $true }).name)

    # Set the inial domain as default so that main domain can be federated:
    Write-Verbose "Trying to set initial domain as default to avoid errors later"
    Set-MsolDomain -Name $targetDefaultDomain -IsDefault

    # Present available domains in a nicely formatted list:
    Write-Output "`nThe following domains exist within your organization:`n"

    # List domains here:
    Write-Verbose "Get all domains here and then index them listing by name only"
    $domains = Get-MsolDomain
    foreach ($domain in $domains) {

        # List domains by name with number prepended: 
        Write-Output ("{0}) {1}" -f ($domains.indexOf($domain) + 1), $domain.name)
    }

    # Ask the user to select one domain from the list:
    $targetFederationDomain = Read-Host "`nSelect your target domain by number"
    $targetFederationDomain = $domains[$targetFederationDomain - 1].name

    Function Validate-Name {
        [cmdletbinding()]
        Param(
            [parameter()]
            [ValidateNotNullorEmpty()]
            [string]$Item
        )

    }
    
    do {
        try {
            # Prompt the user to name the Office365 to SafeNet Trusted Access federation:
            Validate-Name -Item ($targetFederationName = read-host "`nName the federation")
        }
        catch {
            Write-Output "`nNOTE: You must name the federation. It can be any name, 'STA' for instance!`n"
            pause
            #Start-Sleep -s 2
            clear-host
        }
    } until ($targetFederationName)
   
    Write-Output "`nNow browse to your metadata file as downloaded from SafeNet Trusted Access..."
    Start-Sleep -s 1

    # Import SafeNet Trusted Access (IdP) metadata for population into Office365 (SP):
    function Get-Setting-From-STA-Metadata($Metadata) {
        [xml]$IdPMetadata = $Metadata
        $global:metadataUrl = $IdPMetadata.EntitiesDescriptor.EntityDescriptor.IDPSSODescriptor.SingleSignOnService |
        ? { $_.Binding -eq "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" } |
        % { $_.Location }
        $global:metadataUri = $IdPMetadata.EntitiesDescriptor.EntityDescriptor.entityID
        $global:metadataCert = $IdPMetadata.EntitiesDescriptor.EntityDescriptor.IDPSSODescriptor.KeyDescriptor |
        ? { $_.use -eq "signing" } |
        Select-Object -Last 1 |
        % { $_.KeyInfo.X509Data.X509Certificate }
    }

    # Ask the user to browse to the metadata document:
    try {
       
        Function Get-FileName($initialDirectory) {
            [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
                        
            $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $OpenFileDialog.initialDirectory = $initialDirectory
            $OpenFileDialog.filter = "metadata (*.xml)| *.xml"
            $OpenFileDialog.ShowDialog() | Out-Null
            $OpenFileDialog.filename
        }
        $inputfile = Get-FileName "Desktop"
        $inputdata = get-content $inputfile
        Get-Setting-From-STA-Metadata (Get-Content $inputfile)
    }
    catch [System.Management.Automation.RuntimeException] {
        Clear-Host
        write-verbose "User probably closed the browse window!"
        Write-Output "`nOoops! An error occurred (you probably closed the Browse window, yes?)`n"
        Start-Sleep -s 1
        return


    
    }
    # Print the info collected and ask user to confirm before execution:
    Write-Output "`nHere is a summary of what you have provided and what we have fetched from metadata:`n"

    Write-Output "Office365 domain to be federated:" $targetFederationDomain
    Write-Output "Name of the federation:" $targetFederationName
    Write-Output "IdP Issuer URI (STA):" $metadataUri
    Write-Output "IdP Single Sign-On URL (STA):" $metadataUrl
    Write-Output "IdP Signature Certificate:`n"
    $metadataCert
    Write-Output "`n"

    do {
        $ans = Read-Host "All good!? y/n"
        if ($ans -eq 'N') { return }
    }
    until($ans -eq 'Y')(Write-Output "`nOK, now creating federation with STA...")

    # Must use local variables next so converting:    
    $url = $metadataUrl
    $uri = $metadataUri
    $cert = $metadataCert

    Write-Verbose "Writing configuration to Office365"
    try {
        Set-MsolDomainAuthentication -DomainName $targetFederationDomain -Authentication Federated -FederationBrandName $targetFederationName -PassiveLogOnUri $url -IssuerUri $uri -LogOffUri $url -PreferredAuthenticationProtocol Samlp -SigningCertificate $cert
    }
    catch {
        #[System.Management.Automation.RuntimeException]
        Clear-Host
        write-verbose "User probably closed the browse window!"
        Write-Output "`nOoops! An error occurred (you probably closed the Browse window, yes?)`n"
        Start-Sleep -s 1
        return
    }
   
    Start-Sleep -s 2
    Write-Output "`nThanks, we are all set now!"
    Start-Sleep -s 2
    Clear-Host

}


##########################################################################
# REMOVE FEDERATION FUNCTION:

Function Remove-Federation {
    Write-Output "`nNOTE: Please authenticate as an Office365 admin when prompted!"
    Start-Sleep -s 2
    Clear-Host
    # Before running any commands we must connect to Office365:
    Write-Verbose "Connecting to Office365 so that we may run our commands"
    Connect-MsolService

    # Present federated domain(s) in a nicely formatted list:
    Write-Output "`nThe following federated domains exist within your organization:`n" 

    $domains = (Get-MsolDomain -Authentication Federated)
    $idx = 0
    foreach ($domain in $domains) {
        $idx++
        # List domains by name with number prepended: 
        Write-Output ("{0}) {1}" -f ($idx, $domain.name))
    }

    # Ask the user to select one domain from the list:
    #TODO: Handle case when no domain is federated OR when user selects wrong number
    $targetManagedDomain = Read-Host "`nSelect your target domain by number"
    $targetManagedDomain = $domains[$targetManagedDomain - 1].name

    # Print the info collected and ask user to confirm before execution:
    Write-Output "`nAre you sure you want to break the federation for:`n"

    Write-Output $targetManagedDomain

    Write-Output "`n"

    do {
        $ans = Read-Host "All good!? y/n"
        if ($ans -eq 'n') { return }
    }
    until($ans -eq 'y')(Write-Output "`nOK, now returning selected domain to managed mode...")

    # TODO: This needs some error handling!
    Set-MsolDomainAuthentication -DomainName $targetManagedDomain -Authentication Managed


    Start-Sleep -s 2
    Write-Output "`nThanks, we are all set now!"
    Start-Sleep -s 2
    Clear-Host
}


##########################################################################
# TEST AUTHENTICATION FUNCTION:

Function Test-Authentication {

    # Test authentication to O365
    Connect-MsolService
    Write-Output "The authentication that just took place should tell you if your domain is federated or not."
    Write-Output "`nBelow you will also find a table of properties per domain:"

    # List all domains in the organization by name hiding all other info:
    Get-MsolDomain  |Format-Table
 
    
}


##########################################################################
# MAIN MENU LOOP:
do {
    Select-Federation-Task-Menu

    $input = Read-Host "`nPlease make a selection"
    switch ($input) {
        '1' {
            Clear-Host
            New-Federation
        }
        '2' {
            Clear-Host
            Remove-Federation
        }
        '3' {
            Clear-Host
            Test-Authentication
        }
        'q' {
            return
        }
    }
    pause
    cls
}
until ($input -eq 'q')
