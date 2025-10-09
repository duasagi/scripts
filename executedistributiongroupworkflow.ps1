# ============================================
# Script: check-approved-ritm.ps1
# Purpose: Fetch approved RITMs from ServiceNow and
#          trigger specific GitHub Actions workflows based on RITM description
# ============================================

param(
    [string]$ServiceNowUrl,
    [string]$Username,
    [string]$Password,
    [string]$GitHubRepo,          # Example: "OrgName/RepoName"
    [string]$GitHubToken,         # GitHub Personal Access Token
    [string]$LogPath = "C:\ritm_execution_log.txt"
)

Write-Host "🚀 Starting RITM approval check at $(Get-Date)..."

# Encode ServiceNow credentials (for Basic Auth)
$pair = "$Username`:$Password"
$encodedCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{
    Authorization = "Basic $encodedCreds"
    "Content-Type" = "application/json"
}

# ServiceNow API URL for approved RITMs
$apiUrl = "$ServiceNowUrl/api/now/table/sc_req_item?sysparm_query=state=1^stage=request_approved&sysparm_limit=20"

# Initialize result collection
$ritmResults = @()

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get

    if ($response.result.Count -gt 0) {
        Write-Host "✅ Approved RITMs found: $($response.result.Count)"

        foreach ($ritm in $response.result) {
            $ritmNumber = $ritm.number
            $shortDesc = $ritm.short_description
            $desc = $ritm.description

            Write-Host "`n🔹 Processing RITM: $ritmNumber"
            Write-Host "Short Description: $shortDesc"
            Write-Host "Description: $desc"

            $workflowFile = $null
            $status = "Not Executed"
            $remarks = ""

            # Match request type to workflow file
            if ($desc -match 'create distribution group') {
                $workflowFile = "create-distribution-group.yml"
            }
            elseif ($desc -match 'remove distribution group') {
                $workflowFile = "remove-distribution-group.yml"
            }
            elseif ($desc -match 'add member to shared mailbox') {
                $workflowFile = "add-member-shared-mailbox.yml"
            }
            elseif ($desc -match 'remove member from shared mailbox') {
                $workflowFile = "remove-member-shared-mailbox.yml"
            }
            elseif ($desc -match 'teams management') {
                $workflowFile = "teams-management.yml"
            }
            else {
                $remarks = "No matching workflow found"
                Write-Host "⚠️ $remarks for $ritmNumber"
                $ritmResults += [PSCustomObject]@{
                    RITM        = $ritmNumber
                    Workflow    = "N/A"
                    Status      = "Skipped"
                    Remarks     = $remarks
                }
                continue
            }

            # Trigger GitHub workflow
            try {
                $gitHubApiUrl = "https://api.github.com/repos/$GitHubRepo/actions/workflows/$workflowFile/dispatches"
                $gitHeaders = @{
                    Authorization = "Bearer $GitHubToken"
                    Accept        = "application/vnd.github+json"
                }

                $body = @{
                    ref = "main"
                    inputs = @{
                        ritm_number = $ritmNumber
                        short_description = $shortDesc
                        description = $desc
                    }
                } | ConvertTo-Json

                Write-Host "⏳ Triggering workflow '$workflowFile' for $ritmNumber ..."
                Invoke-RestMethod -Uri $gitHubApiUrl -Headers $gitHeaders -Method Post -Body $body
                Write-Host "✅ Workflow triggered successfully for $ritmNumber"

                $status = "Success"
                $remarks = "Workflow triggered"
            }
            catch {
                $status = "Failed"
                $remarks = $_.Exception.Message
                Write-Host "❌ Failed to trigger workflow for $ritmNumber:`n$remarks"
            }

            # Log the outcome
            $ritmResults += [PSCustomObject]@{
                RITM        = $ritmNumber
                Workflow    = $workflowFile
                Status      = $status
                Remarks     = $remarks
            }
        }

        # Write summary log
        Write-Host "`n📝 Writing summary to log file: $LogPath"
        $ritmResults | Out-File -FilePath $LogPath -Append
        Write-Host "`n✅ RITM Processing Completed. Summary:"
        $ritmResults | Format-Table -AutoSize
    }
    else {
        Write-Host "❌ No approved RITMs found."
    }
}
catch {
    Write-Host "⚠️ Error connecting to ServiceNow:"
    Write-Host $_.Exception.Message
}

Write-Host "`n✅ Script completed at $(Get-Date)"
