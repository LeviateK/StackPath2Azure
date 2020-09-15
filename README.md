# StackPath2Azure
If you use StackPath and Azure Web Apps, this will help automate Azure network security <br>
Automatically obtains all current StackPath IPs via API and sends them to your Azure App Services/Slots for a specific resource group as network allows, blocking all traffic not originating from StackPath

# Requires<br>
  StackPath account with ClientID and ClientSecret, refer to their documentation for how-to obtain <br/>  
  StackPath & Azure accounts setup to accept requests for the apps you have in Azure - DNS/WAF/CDN Configuraton

# Usage <br>
  .\Inject-StackPath2Azure-v1.ps1 -SPClientID  -SPClientSecret -ResourceGroup
