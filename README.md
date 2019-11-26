### Table Of Contents
  * [AWS Federation with SafeNet Trusted Access (STA)](https://github.com/JMarkstrom/SafeNet-Trusted-Access/blob/master/README.md#aws-federation-with-safenet-trusted-access-sta)
  * [Office365 Federation with SafeNet Trusted Access (STA)](https://github.com/JMarkstrom/SafeNet-Trusted-Access/blob/master/README.md#office365-federation-with-safenet-trusted-access-sta)


## AWS Federation with SafeNet Trusted Access (STA)
                                                                                                       
*Get AWS temporary security credentials by authenticating to SafeNet Trusted Access with your username
and One Time Password (OTP). You may use ANY supported software or hardware authenticator in either TOTP 
(time-based) or HOTP (event-based) programming mode. Note that credential life-span is controlled by AWS!*
 
**DISCLAIMER**: This script is provided "as-is" without any warranty of any kind, either expressed or implied.

<sub>Click below for video demonstration (version 1.0 shown):<sub>

[![Watch the video demonstration](https://i.imgur.com/nNiQZ23.png)](https://youtu.be/ij9U8tsGtjE)

## Prerequisites
You will need to meet the following prequisites to make use of this script:

* Python 3 (get it here: https://www.python.org/downloads/)
* Beautiful Soup for Python (get it using PIP with: `pip install --upgrade boto beautifulsoup4 requests`)
* AWS CLI (get it here for Windows: https://s3.amazonaws.com/aws-cli/AWSCLI64PY3.msi )
* AWS CLI Profile configured 
* AWS app configured in SafeNet Trusted Access


## Usage
First, you will need to set a few parameters in the script. These are well explained, but you will need access to your SafeNet Trusted Access (STA) tenant to set them. Then, just run the script as you would any Python script, e.g.: `py AWS_Federation_with_SafeNet_Trusted_Access_v1.0.py`

## Release History
* 2019.11.21 `v1.0.0` Initial Release

# Office365 Federation with SafeNet Trusted Access (STA)

*This script allows you to federate Office365 (O365) to SafeNet Trusted Access (STA) and in addition it allows
you to return a previously federated organization to its default managed state as well as test authentication.*

**DISCLAIMER**: This script is provided "as-is" without any warranty of any kind, either expressed or implied.

<sub>Click below for video demonstration (version 1.0 shown):<sub>
 
[![Watch the video demonstration](https://i.imgur.com/uoyL9ek.png)](https://youtu.be/ecSAiq9g5P8)

## Prerequisites
You will need to meet the following prequisites to make use of this script:

* Powershell is present on machine
* MSOnline module is installed (as administrator run:  `Install-Module MSOnline`)
* Administrator privileges on Office365 domain
* Office365 app template (partially) configured for SafeNet Trusted Access
* A designated STA test user (preferably one that is admin in O365)

## Usage
To use the script simply run it in Powershell, e.g.: `.\STA_Federate_Office365.ps1 (enter)`

## Release History
* 2019.11.21 `v1.0.0` Initial Release
