# Archived
This repo is being archived as it has been superceeded by a newer version of the script that uses the Zerto REST API. 
You can find the new script here: [Latest VRA Bulk Deploy Script](https://github.com/ZertoPublic/Zerto-Site-Deployment/tree/master/API-Examples/BulkVRADeployment)

# Legal Disclaimer
This script is an example script and is not supported under any Zerto support program or service. The author and Zerto further disclaim all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose.

In no event shall Zerto, its authors or anyone else involved in the creation, production or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or the inability to use the sample scripts or documentation, even if the author or Zerto has been advised of the possibility of such damages. The entire risk arising out of the use or performance of the sample scripts and documentation remains with you.

# Bulk-VRA-Deployment
This script automates the deployments of VRAs based on the hosts in the specified CSV file using PowerCLI and the Zerto API. The CSV is required to be filled out before running the script so that the script can utilize the necessary vCenter resources when creating the VRAs. Please note this script is intended to be used only with ESXi hosts 5.5 and newer. The script doesn't call for a host root password and is instead using the Zerto VRA VIB deployment that was introduced in ZVR 4.5. 

# Prerequisites 
Environment Requirements:
- PowerShell 5.0 
- VMware PowerCLI 6.0+
- ZVR 5.0u3 + 
- ESXi Host 5.5+ for VMware VIB deployment support 
- Network access to the ZVM and vCenter, use the target site ZVM for storage info to be populated
- Access permission to write in and create (or create it manually and ensure the user has permission to write within)the directory specified for logging


Script Requirements: 
- ZVM ServerName, Username and password with permission to access the API of the ZVM
- vCenter ServerName, Username and password to establish as session using PowerCLI to the vCenter
- VRADeploymentESXiHost.csv required info completed
- VRADeploymentESXiHost.csv accessible by host running script 

# Running Script 
Once the necessary requirements have been completed select an appropriate host to run the script from. To run the script type the following:

.\BulkVRADeployment.ps1

