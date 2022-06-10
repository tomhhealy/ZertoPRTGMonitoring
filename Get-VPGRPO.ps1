<#
.SYNOPSIS
Get-VPGStatus.ps1 retrieves information from the Zerto API hosted and maintained by My2Cloud. The intention of this script is to output all VPGs as individual channels and their current RPO to the PRTG Monitoring Platform.

.DESCRIPTION
Get-VPGStatus.ps1 is intended for use within the PRTG monitoring platform. Instructions for how the script should be configured are contained within my blog post.
The script itself must be placed in the following location - C:\Program Files (x86)\Paessler\PRTG Network Monitor\Custom Sensors\EXEXML\
You must pass the username, password, zorgId and TenantId paramteres to the script in order for it to work.
The OAuth2 Bearer token will be automatically generated every 8 hours and is stored in a variable.

.PARAMETER Username
Represents your username OR email address used to login to the My2CLoud platform.

.PARAMETER Password
Represents the password used to login to the My2Cloud platform. NOTE this value is visible inside the sensor settings in PRTG.

.PARAMETER TenandId
Represents the My2Cloud Tenant ID.

.PARAMETER zorgId
Represents the Zerto Organization ID.

.NOTES
Author: Tom Healy
Company: Total Computer Networks Ltd
Version: 1.3
Version History:
    1.0 22/01/2022  Initial creation of script.
    1.1 23/01/2022  Updated script to now use command line parameters for interchangeable information such as zOrgs, 
    1.2 09/02/2022  Updated script to now call logoff endpoint via REST API due to session limit being reached.
    1.3 27/04/2022  Updated script to use a different LogOut endpoint via REST API to resolve issues with session limit.
    1.4 06/06/2022  Updated script to include logoffInvoke last and then discard the output. This can still call the logoff endpoint so should no longer cause the sensor to error in PRTG.
#>

# -- | Configured command line parameters | -- #
[CmdletBinding()] param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $Username,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $Password,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $tenantId,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $zorgId
)

# -- | Authentication | -- #
$authHeaders = @{'Abp.TenandId' = $tenantId}
$authBody = '{"userNameOrEmailAddress": "' + $Username + '","password":"' + $Password + '"}'
$authInvoke = Invoke-RestMethod -Uri "https://****CUSTOMER****.my2cloud.net:44301/api/TokenAuth/Authenticate" -Method POST -Body $authBody -ContentType 'application/json' -Headers $authHeaders


# -- | My2Cloud - GetVpgs API Call | -- #
$apiHeaders = @{"Authorization" = "Bearer " + $authInvoke.result.accessToken}
$apiUri = "https://****CUSTOMER****.my2cloud.net:44301/api/services/app/ZertoService/GetVpgs?zorgIdentifier=" + $zorgId
$apiInvoke = Invoke-RestMethod -Uri $apiUri -Headers $apiHeaders -Method GET -ContentType 'application/json'

# -- | Converts the results from the API call to useable format in PowerShell due to nested Json result | -- #
$convertToJson = $apiInvoke.result.vpgs | ConvertTo-Json
$vpgResults = $convertToJson | ConvertFrom-Json

# -- | Starts creating the XML output for PRTG unformatted | -- #
$XML = "<PRTG>"
foreach ($vpgResult in $vpgResults)
{
    $vpgName = $vpgResult.name
    $vpgRpo = $vpgResult.actualRpo
    $XML += "<result><channel>$vpgName</channel><value>$vpgRpo</value><unit>TimeSeconds</unit><LimitMaxWarning>150</LimitMaxWarning><LimitMaxError>300</LimitMaxError></result>"
}
$XML += "</PRTG>"

# -- | Creates the XML writer to format the XML for PRTG to read | -- #
function Out-XML ([xml]$XML)
{
    $StringWriter = New-Object System.IO.StringWriter;
    $XmlWriter = New-Object System.Xml.XmlTextWriter $StringWriter;
    $XmlWriter.Formatting = "indented";
    $XML.WriteTo($XmlWriter);
    $XmlWriter.Flush();
    $StringWriter.Flush();
    Write-Output $StringWriter.ToString();
}
Out-XML "$XML"


#$logoffHeaders.Add("Content-Type", "application/json")


# -- | Call the logoff endpoint | -- #
$logoffHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$logoffHeaders.Add("Accept", "*/*")
$logoffHeaders.Add("Authorization", "Bearer $($authInvoke.result.accessToken)")
$logoffInvoke = Invoke-RestMethod 'https://****CUSTOMER****.my2cloud.net:44301/api/TokenAuth/LogOut' -Method 'GET' -Headers $logoffHeaders
$logoffInvoke | Out-Null
