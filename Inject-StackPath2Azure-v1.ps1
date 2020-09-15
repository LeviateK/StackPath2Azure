# Inject-StackPath2Azure
# Automatically takes all StackPath IPs and sends them to your Azure App Services/Slots for a specific resource group as network allows, blocking all traffic not coming from StackPath
# Will update all applications and any slots they have tied to them
# Requires StackPath account with ClientID and ClientSecret, refer to their documentation for how-to obtain
# Also requires that you have your StackPath & Azure accounts setup to accept requests for the apps you have in Azure - DNS/WAF/CDN Configuraton
# v1.0 - 9.15.2020 - Initial Release

# Input Parameters
param(
$SPClientID, $SPClientSecret, $ResourceGroup
)
# Helper Function to show progress bar
function ShowMeTheProgress ($array, $iteration)
{
    
    $CurrentOp = ($array.IndexOf($iteration)+1)
    $Percent = ($CurrentOp/$array.count)*100
    Write-Progress -Activity "Processing StackPath IPs" -PercentComplete $Percent -CurrentOperation "IP $CurrentOp  of $($array.count)"
}
# Format and send/receive request to StackPath API
$AuthHeaders = @{"Content-Type" = "application/json"}
$AuthBody = @{client_id = $SPClientID; client_secret = $SPClientSecret; grant_type =  "client_credentials"}
$SPAuth = Invoke-WebRequest -Uri https://gateway.stackpath.com/identity/v1/oauth2/token -Method POST -Body (ConvertTo-Json $AuthBody) -Headers $AuthHeaders
$SPAuthToken = $SPAuth | ConvertFrom-Json
# Get the IP list back as JSON
$IPs = Invoke-WebRequest -Uri https://gateway.stackpath.com/cdn/v1/ips -Method GET -Headers (@{Authorization="Bearer $($SPAuthToken.access_token)"; "Content-Type" = "application/json"})
$jsonIPs = $IPs.Content | ConvertFrom-Json
# Connect to Azure and get all web apps for specified resource group
Connect-AzAccount
$WebApps = Get-AzWebApp -ResourceGroupName $ResourceGroup

# Helper Function to update Azure Network Settings with StackPath IPs
function UpdateStackPathIPs ($ipList, $ApplicationName, $SlotName)
{
    
    if ([string]::IsNullOrEmpty($SlotName))
    {
        $Config = Get-AzWebAppAccessRestrictionConfig -ResourceGroupName "$($ResourceGroup)" -Name "$($ApplicationName)"
    }
    else
    {
        $lowerAppName = $ApplicationName.ToLower()
        $actSlotName = $SlotName.Replace("$($lowerAppName)/","")
        $Config = Get-AzWebAppAccessRestrictionConfig -ResourceGroupName "$($ResourceGroup)" -Name "$($ApplicationName)" -SlotName $actSlotName
    }
    $shortdate = Get-Date -Format MMddyyyy
    foreach ($ip in $ipList.results)
    {
        ShowMeTheProgress -array $ipList.results -iteration $ip
        $IPCheck = $Config.MainSiteAccessRestrictions.IPAddress.IndexOf($ip)
        if ($IPCheck -eq -1)
        {
            if ([string]::IsNullOrEmpty($SlotName))
            {
            
                try
                {
                    Add-AzWebAppAccessRestrictionRule -ResourceGroupName "$($ResourceGroup)" -WebAppName "$($ApplicationName)" -Name "StackPath WAF/CDN - $($Shortdate)" -Priority 100 -Action Allow -IpAddress $ip
                }
                catch
                {
                    write-host Unable to Add $ip to $ApplicationName -ForegroundColor Yellow
                }
            }
            else
            {
            
                try
                {
                    Add-AzWebAppAccessRestrictionRule -ResourceGroupName "$($ResourceGroup)" -WebAppName "$($ApplicationName)" -SlotName $actSlotName -Name "StackPath WAF/CDN - $($Shortdate) " -Priority 100 -Action Allow -IpAddress $ip  
                }
                catch
                {
                    write-host Unable to Add $ip to $SlotName -ForegroundColor Yellow
                }
            }
        }
        else
        {
            if ([string]::IsNullOrEmpty($SlotName))
            {
                write-host "IP Addresses $($ip) Already Exists on $($ApplicationName)" -ForegroundColor Yellow
            }
            else
            {
                write-host "IP Addresses $($ip) Already Exists on $($ApplicationName) : $($SlotName)" -ForegroundColor Magenta
            }

        }
    }
}

# Go through all Web Apps and update IPs
foreach ($App in $WebApps)
{
    # 1 - Process WebApp
    write-host Production: $App.Name -ForegroundColor Cyan
    UpdateStackPathIPs -ipList $jsonIPs -ApplicationName $App.Name
    # 2 - Check WebApp for slots and update those; parameter == SlotName
    $webAppSlots = @(Get-AzWebAppSlot -ResourceGroupName $ResourceGroup -Name $App.Name)
    if ($webAppSlots.count -gt 0)
    {
        write-host Slot: $webAppSlots.Name -ForegroundColor Magenta
        foreach ($webAppSlot in $webAppSlots)
        {
            UpdateStackPathIPs -ipList $jsonIPs -ApplicationName $App.Name -SlotName $webAppSlot.Name
        }
    }
}

# Disconnect from Azure
Disconnect-AzAccount | Out-Null