##########################################################################
# MFA for AWS CLI using SafeNet Trusted Access (STA)                           
##########################################################################
# version: 1.0
# last updated on: 2019-11-21
# see readme.md for more info.
#
# NOTE: This script was adapted from a script written by Quint Van Deman
# published on the AWS Security Blog (https://amzn.to/2gT8IAZ). Notable
# changes includes that SafeNet Trusted Access (STA) is used instead of 
# Microsoft AD FS and that two forms are used instead of one as STA will
# collect only username on the first page to premiere Push OTP over manual
# credential input. Moreover the script sets temporary access tokens in 
# the profile of the authenticated user instead of in SAML profile.
#
# LIMITATIONS/ KNOWN ISSUES: The script currently does not detect if the
# user approves a Push Authentication request, instead it submits the
# One Time Password (OTP) "manually" to the IdP and then parses the
# SAML response. A Push request may still be triggered (disregard it).
#
# ************************************************************************
# DISCLAIMER: This script is provided "as-is" without any warranty of
# any kind, either expressed or implied.
# ************************************************************************

#!/usr/bin/python3
import sys
import boto.sts
import requests
import getpass
import configparser
import base64
import logging
import xml.etree.ElementTree as ET
import re
from bs4 import BeautifulSoup
from os.path import expanduser
from urllib.parse import urlparse, urlunparse
import time
import datetime
##########################################################################
# AWS variables

# region: The default AWS region that this script will connect
# to for all API calls (note that some regions may not work)
region = 'us-east-2'

# output format: The AWS CLI output format that will be configured in the
# user profile (affects subsequent CLI calls)
outputformat = 'json'

# awsconfigfile: The file where this script will store the temp
# credentials under the user profile
awsconfigfile = '/.aws/credentials'

# SSL certificate verification: Whether or not strict certificate
# verification is done, False should only be used for dev/test
sslverification = True

##########################################################################
# SafeNet Trusted Access variables

# cloud_idp: The FQDN for your cloud zone. Use "sta.eu.safenetid.com" for
# EU hosted tenants and "sta.us.safenetid.com" for US hosted tenants
cloud_idp = 'idp.eu.safenetid.com'

# tenant_reference_id: The unique ID for your virtual server, found in the 
# tenant specific console URL, in the User Portal URL or in metadata files
tenant_reference_id = 'BWTYF307CZ-STA'

# aws_app_name: The name you have given to the AWS app within the STA console
# use "%20" (excluding "") instead of any blank spaces 
aws_app_name = 'AWS'

# idpentryurl: The URL for the STA IdP including all the variables we need
idpentryurl = "https://" + cloud_idp + "/auth/realms/" + tenant_reference_id + "/protocol/saml/clients/" + aws_app_name
#https://idp.eu.safenetid.com/auth/realms/E6MQD34PJN-STA/protocol/saml/clients/Amazon%20Web%20Services
#https://idp.eu.safenetid.com/auth/realms/E6MQD34PJN-STA/protocol/saml/clients/Amazon%20Web%20Services?sas_user=jonas

##########################################################################
# Debugging if you are having any major issues:

#logging.basicConfig(level=logging.DEBUG)

##########################################################################
# STA welcome message:
print('''
 --------------------------------------------------------------------------------------------------------------
Welcome to MFA for AWS CLI using:

  ____         __      _   _      _     _____               _           _      _                        
 / ___|  __ _ / _| ___| \ | | ___| |_  |_   __ __ _   _ ___| |_ ___  __| |    / \   ___ ___ ___ ___ ___  v.1.0
 \___ \ / _` | |_ / _ |  \| |/ _ | __|   | || '__| | | / __| __/ _ \/ _` |   / _ \ / __/ __/ _ / __/ __| 
  ___) | (_| |  _|  __| |\  |  __| |_    | || |  | |_| \__ | ||  __| (_| |  / ___ | (_| (_|  __\__ \__ \
 |
  ____/ \__,_|_|  \___|_| \_|\___|\__|   |_||_|   \__,_|___/\__\___|\__,_| /_/   \_\___\___\___|___|___/ 
                                                                                                        
Get AWS temporary security credentials by authenticating to SafeNet Trusted Access with your username
and One Time Password (OTP). You may use ANY supported software or hardware authenticator in either TOTP 
(time-based) or HOTP (event-based) programming mode. Note that credential life-span is controlled by AWS! 
 
DISCLAIMER: This script is provided "as-is" without any warranty of any kind, either expressed or implied.
==============================================================================================================

''')
# Pause for a second to admire the fancy art work ;)
time.sleep(1)

##########################################################################
# Capture user credentials:

# Prompt for STA username
print("(STA) username:", end=' ')
sas_user = input()

# Prompt for One Time Password (OTP) and print it (why not, its an OTP!?)
# TODO: A future version should submit only username to handle authentication via Push to device/desktop
print("OTP:", end=' ')
password = input()

print('')

##########################################################################
# Send credentials and get SAML response:

# Initiate session handler
session = requests.Session()

# Opens the initial IdP url and follows all of the HTTP302 redirects, and
# gets the resulting login page
formresponse = session.get(idpentryurl, verify=sslverification)
# Capture the idpauthformsubmiturl, which is the final url after all the 302s
idpauthformsubmiturl = formresponse.url

# Parse the response and extract all the necessary values
formsoup = BeautifulSoup(formresponse.text, "html.parser")
payload = {}

login_form = formsoup.find(id="sas-login-form")
for inputtag in login_form.find_all(re.compile('(INPUT|input)')):
    name = inputtag.get('name','')
    value = inputtag.get('value','')
	
    if "user" in name.lower():
        # In STA the username field is called "sas_user"
        payload[name] = sas_user
    else:
        #Simply populate the parameter with the existing value (picks up hidden fields in the login form)
        payload[name] = value

idpauthformsubmiturl = login_form.get('action')

# Performs the submission of the STA login form with the above post data
response = session.post(
    idpauthformsubmiturl, data=payload, verify=sslverification)

# For SafeNet Trusted Access we need to parse a second form and submit the OTP 
login_form = BeautifulSoup(response.text, "html.parser").find(id="sas-login-form")
payload = {}

for inputtag in login_form.find_all(re.compile('(INPUT|input)')):
    name = inputtag.get('name', '')
    value = inputtag.get('value', '')

    if "sas_response" in name:
        payload[name] = password
    else:
        payload[name] = value

response = session.post(login_form.get("action"), data=payload, verify=sslverification)

# Debug the response if needed
# print (response.text)

# Decode the response and extract the SAML assertion
soup = BeautifulSoup(response.text,"html.parser")
assertion = ''
# Look for the SAMLResponse attribute of the input tag (determined by
# analyzing the debug print lines above)
for inputtag in soup.find_all('input'):
    if(inputtag.get('name') == 'SAMLResponse'): 
	#print(inputtag.get('value'))
        assertion = inputtag.get('value')

# Better error handling is required for production use.
if (assertion == ''):
    #TODO: Insert valid error checking/handling
    print('Ooops! Wrong username/password or the response did not contain a valid SAML assertion')
    sys.exit(0)

# Debug only
# print(base64.b64decode(assertion))

# Parse the returned assertion and extract the authorized roles
awsroles = []
root = ET.fromstring(base64.b64decode(assertion))
for saml2attribute in root.iter('{urn:oasis:names:tc:SAML:2.0:assertion}Attribute'):
    if (saml2attribute.get('Name') == 'https://aws.amazon.com/SAML/Attributes/Role'):
        for saml2attributevalue in saml2attribute.iter('{urn:oasis:names:tc:SAML:2.0:assertion}AttributeValue'):
            awsroles.append(saml2attributevalue.text)


# Note the format of the attribute value should be role_arn,principal_arn
# but lots of blogs list it as principal_arn,role_arn so let's reverse
# them if needed
for awsrole in awsroles:
    chunks = awsrole.split(',')
    if 'saml-provider' in chunks[0]:
        newawsrole = chunks[1] + ',' + chunks[0]
        index = awsroles.index(awsrole)
        awsroles.insert(index, newawsrole)
        awsroles.remove(awsrole)
		

# If I have more than one role, ask the user which one they want,
# otherwise just proceed
print("")
if len(awsroles) > 1:
    i = 0
    print("Please choose the role you would like to assume:")
    for awsrole in awsroles:
        print('[', i, ']: ', awsrole.split(',')[0])
        i += 1
    print("Selection: ", end=' ')
    selectedroleindex = input()

    # Basic sanity check of input
    if int(selectedroleindex) > (len(awsroles) - 1):
        print('You selected an invalid role index, please try again')
        sys.exit(0)

    role_arn = awsroles[int(selectedroleindex)].split(',')[0]
    principal_arn = awsroles[int(selectedroleindex)].split(',')[1]
else:
    role_arn = awsroles[0].split(',')[0]
    principal_arn = awsroles[0].split(',')[1]

# Use the assertion to get an AWS STS token using Assume Role with SAML
conn = boto.sts.connect_to_region(region)
token = conn.assume_role_with_saml(role_arn, principal_arn, assertion)

# Write the AWS STS token into the AWS credential file
home = expanduser("~")
filename = home + awsconfigfile

# Read in the existing config file
config = configparser.RawConfigParser()
config.read(filename)

# Put the credentials into the STA user's profile
# TODO: Consider (option)to export the keys/token as environmental variables
if not config.has_section(sas_user):
    config.add_section(sas_user)

config.set(sas_user, 'output', outputformat)
config.set(sas_user, 'region', region)
config.set(sas_user, 'aws_access_key_id', token.credentials.access_key)
config.set(sas_user, 'aws_secret_access_key', token.credentials.secret_key)
config.set(sas_user, 'aws_session_token', token.credentials.session_token)

# Write the updated config file
with open(filename, 'w+') as configfile:
    config.write(configfile)

##########################################################################
# Provide user feedback

# Provide token expiry in a more friendly format
# TODO: Ideally the value should be presented in user local timezone
expiry_dt = datetime.datetime.fromisoformat(token.credentials.expiration.replace("Z", "+00:00")).strftime("%Y-%m-%d %H:%M:%S")

# Provide some user feedback:
print('Great job! You have now obtained temporary credentials for AWS CLI')
print('NOTE: These credentials will expire at {0} UTC.'.format(expiry_dt)) 
print('Simply run the script again to refresh credentials on expiry.\n\n')
