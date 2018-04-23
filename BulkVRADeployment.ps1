#requires -Version 5
#requires -RunAsAdministrator
<#
.SYNOPSIS
   This script automates the deployment of VRAs for the hosts in the specified CSV file using PowerCLI and the Zerto API to complete the process
.DESCRIPTION
   The script requires a user to prepopulate the VRADeploymentESXiHosts.csv with the necessary vCenter resources the VRA will utilize including the ESXi Host, Datastore,
   vSwitch / vDS Port Group, Memory, IP Address, Gateway, and Subnet for the VRA. These vCenter resources will then be utilized 
.EXAMPLE
   Examples of script execution
.VERSION 
   Applicable versions of Zerto Products script has been tested on.  Unless specified, all scripts in repository will be 5.0u3 and later.  If you have tested the script on multiple
   versions of the Zerto product, specify them here.  If this script is for a specific version or previous version of a Zerto product, note that here and specify that version 
   in the script filename.  If possible, note the changes required for that specific version.  
.LEGAL
   Legal Disclaimer:

----------------------
This script is an example script and is not supported under any Zerto support program or service.
The author and Zerto further disclaim all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose.

In no event shall Zerto, its authors or anyone else involved in the creation, production or delivery of the scripts be liable for any damages whatsoever (including, without 
limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or the inability 
to use the sample scripts or documentation, even if the author or Zerto has been advised of the possibility of such damages.  The entire risk arising out of the use or 
performance of the sample scripts and documentation remains with you.
----------------------
#>
#------------------------------------------------------------------------------#
# Declare variables
#------------------------------------------------------------------------------#
#Examples of variables:

##########################################################################################################################
#Any section containing a "GOES HERE" should be replaced and populated with your site information for the script to work.#  
##########################################################################################################################
# Configure the variables below
################################################
$LogDataDir = "C:\ZVRAPIBulkVRAScript\"
$ESXiHostCSV = "C:\ZVRAPIBulkVRAScript\VRADeploymentESXiHosts.csv"
$ZertoServer = "ZVMIpAddress"
$ZertoPort = "9669"
$ZertoUser = "ZertoUserAccount"
$ZertoPassword = "ZertoUserAccountPassword"
$vCenterServer = "vCenterServerIP"
$vCenterUser = "vCenterUserAccount"
$vCenterPassword = "vCenterPassword"
#------------------------------------------------------------------------------#
# Configure logging
#------------------------------------------------------------------------------#
$Transcript = "$LogDataDir\ZVMInstallerLog.log" 
start-transcript -path $Transcript

#------------------------------------------------------------------------------#
# Nothing to configure below this line
#------------------------------------------------------------------------------#
Write-Host -ForegroundColor Yellow "Informational line denoting start of script GOES HERE." 
Write-Host -ForegroundColor Red "   Legal Disclaimer:

----------------------
This script is an example script and is not supported under any Zerto support program or service.
The author and Zerto further disclaim all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose.

In no event shall Zerto, its authors or anyone else involved in the creation, production or delivery of the scripts be liable for any damages whatsoever (including, without 
limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or the inability 
to use the sample scripts or documentation, even if the author or Zerto has been advised of the possibility of such damages.  The entire risk arising out of the use or 
performance of the sample scripts and documentation remains with you.
----------------------
"
#------------------------------------------------------------------------------#
# Setting Cert Policy - required for successful auth with the Zerto API 
#------------------------------------------------------------------------------#
Write-Host "The cert policy original is  $([System.Net.ServicePointManager]::CertificatePolicy)"
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy -WarningAction SilentlyContinue
Write-Host "The cert policy is now  $([System.Net.ServicePointManager]::CertificatePolicy)"

#-------------------------------------------------------------------------------#
# Importing PowerCLI snap-in required for successful authentication with Zerto API
#-------------------------------------------------------------------------------#
function LoadSnapin{
  param($PSSnapinName)
  if (!(Get-PSSnapin | where {$_.Name   -eq $PSSnapinName})){
    Add-pssnapin -name $PSSnapinName
  }
}
# Loading snapins and modules
LoadSnapin -PSSnapinName   "VMware.VimAutomation.Core"
#-------------------------------------------------------------------------------#
# Connecting to vCenter - required for successful authentication with Zerto API
#-------------------------------------------------------------------------------#
connect-viserver -Server $vCenterServer -User $vCenterUser -Password $vCenterPassword
#-------------------------------------------------------------------------------#
# Building Zerto API string and invoking API
#-------------------------------------------------------------------------------#
$baseURL = "https://" + $ZertoServer + ":"+$ZertoPort+"/v1/"
# Authenticating with Zerto APIs
$xZertoSessionURI = $baseURL + "session/add"
$authInfo = ("{0}:{1}" -f $ZertoUser,$ZertoPassword)
$authInfo = [System.Text.Encoding]::UTF8.GetBytes($authInfo)
$authInfo = [System.Convert]::ToBase64String($authInfo)
$headers = @{Authorization=("Basic {0}" -f $authInfo)}
$sessionBody = '{"AuthenticationMethod": "1"}'
$TypeJSON = "application/json"
$TypeXML = "application/xml"

Try
{
$xZertoSessionResponse = Invoke-WebRequest -Uri $xZertoSessionURI -Headers $headers -Method POST -Body $sessionBody -ContentType $TypeJSON
}
Catch
{
Write-Host $_.Exception.ToString()
$error[0] | Format-List -Force
}


#Extracting x-zerto-session from the response, and adding it to the actual API
$xZertoSession = $xZertoSessionResponse.headers.get_item("x-zerto-session")
$zertoSessionHeader_json = @{"Accept"="application/json"
"x-zerto-session"=$xZertoSession}


# Get SiteIdentifier for getting Network Identifier later in the script
$SiteInfoURL = $BaseURL+"localsite"
$SiteInfoCMD = Invoke-RestMethod -Uri $SiteInfoURL -TimeoutSec 100 -Headers $zertoSessionHeader_json -ContentType $TypeJSON
$SiteIdentifier = $SiteInfoCMD | Select SiteIdentifier -ExpandProperty SiteIdentifier
$VRAInstallURL = $BaseURL+"vras"
#------------------------------------------------------------------------------#
# Importing the CSV of ESXi hosts to deploy VRA to
#------------------------------------------------------------------------------#
$ESXiHostCSVImport = Import-Csv $ESXiHostCSV

#------------------------------------------------------------------------------#
# Starting Install Process for each ESXi host specified in the CSV
#------------------------------------------------------------------------------#
foreach ($ESXiHost in $ESXiHostCSVImport)
{
# Setting Current variables for ease of use throughout script
$VRAESXiHostName = $ESXiHost.ESXiHostName
$VRADatastoreName = $ESXiHost.DatastoreName
$VRAPortGroupName = $ESXiHost.PortGroupName
$VRAGroupName = $ESXiHost.VRAGroupName
$VRAMemoryInGB = $ESXiHost.MemoryInGB
$VRADefaultGateway = $ESXiHost.DefaultGateway
$VRASubnetMask = $ESXiHost.SubnetMask
$VRAIPAddress = $ESXiHost.VRAIPAddress
# Get NetworkIdentifier for API
$APINetworkURL = $BaseURL+"virtualizationsites/$SiteIdentifier/networks"
$APINetworkCMD = Invoke-RestMethod -Uri $APINetworkURL -TimeoutSec 100 -Headers $zertoSessionHeader_json -ContentType $TypeJSON
$NetworkIdentifier = $APINetworkCMD | Where-Object {$_.VirtualizationNetworkName -eq $VRAPortGroupName}  | Select -ExpandProperty NetworkIdentifier 
# Get HostIdentifier for API
$APIHostURL = $BaseURL+"virtualizationsites/$SiteIdentifier/hosts"
$APIHostCMD = Invoke-RestMethod -Uri $APIHostURL -TimeoutSec 100 -Headers $zertoSessionHeader_json -ContentType $TypeJSON
$VRAESXiHostID = $APIHostCMD | Where-Object {$_.VirtualizationHostName -eq $VRAESXiHostName}  | Select -ExpandProperty HostIdentifier 
# Get DatastoreIdentifier for API
$APIDatastoreURL = $BaseURL+"virtualizationsites/$SiteIdentifier/datastores"
$APIDatastoreCMD = Invoke-RestMethod -Uri $APIDatastoreURL -TimeoutSec 100 -Headers $zertoSessionHeader_json -ContentType $TypeJSON
$VRADatastoreID = $APIDatastoreCMD | Where-Object {$_.DatastoreName -eq $VRADatastoreName}  | Select -ExpandProperty DatastoreIdentifier 
# Creating JSON Body for API settings
$JSON =
"{
    ""DatastoreIdentifier"":  ""$VRADatastoreID"",
    ""GroupName"":  ""$VRAGroupName"",
    ""HostIdentifier"":  ""$VRAESXiHostID"",
    ""HostRootPassword"":null,
    ""MemoryInGb"":  ""$VRAMemoryInGB"",
    ""NetworkIdentifier"":  ""$NetworkIdentifier"",
    ""UsePublicKeyInsteadOfCredentials"":true,
    ""VraNetworkDataApi"":  {
                              ""DefaultGateway"":  ""$VRADefaultGateway"",
                              ""SubnetMask"":  ""$VRASubnetMask"",
                              ""VraIPAddress"":  ""$VRAIPAddress"",
                              ""VraIPConfigurationTypeApi"":  ""Static""
                          }
}"
write-host "Executing $JSON"
# Now trying API install cmd
Try 
{
 Invoke-RestMethod -Method Post -Uri $VRAInstallURL -Body $JSON -ContentType $TypeJSON -Headers $zertoSessionHeader_json
}
Catch {
 Write-Host $_.Exception.ToString()
 $error[0] | Format-List -Force
}
# Waiting 180 seconds before deploying the next VRA
write-host "Waiting 180 seconds before deploying the next VRA"
sleep 180
# End of per Host operations below
}
# End of per Host operations above
#-------------------------------------------------------------#
# Disconnecting from vCenter
#-------------------------------------------------------------#
disconnect-viserver $vCenterServer -Force -Confirm:$false

