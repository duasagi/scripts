# ============================================
# Script: check-approved-ritm.ps1
# Purpose: Check for approved RITM items in ServiceNow
# ============================================

param(
    [string]$ServiceNowUrl,
    [string]$Username,
    [string]$Password
)

Write-Host "Starting RITM approval check at $(Get-Date)..."

# Encode credentials (for Basic Auth)
$pair = "$Username`:$Password"
$encodedCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{
    Authorization = "Basic $encodedCreds"
    "Content-Type" = "application/json"
}

# Example: ServiceNow Table API query for RITMs with 'approved' state
# NOTE: Change the table and query according to your instance setup
$apiUrl = "$ServiceNowUrl/api/now/table/sc_req_item?sysparm_query=state=1&stage=request_approved^ORDERBYDESCsys_updated_on&sysparm_limit=5"

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get

    if ($response.result.Count -gt 0) {
        Write-Host "✅ Approved RITMs found:"
        foreach ($ritm in $response.result) {
            Write-Host "Number: $($ritm.number) | Short Description: $($ritm.short_description)"
        }
    }
    else {
        Write-Host "❌ No approved RITMs found."
    }
}
catch {
    Write-Host "⚠️ Error connecting to ServiceNow:"
    Write-Host $_.Exception.Message
}

Write-Host "Check completed at $(Get-Date)"
