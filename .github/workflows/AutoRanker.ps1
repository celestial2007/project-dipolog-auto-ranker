# ==========================================
# Project Dipolog - GitHub Auto-Ranker
# ==========================================

$groupId = "871914208"
$visitorRole = "12884901889"
$targetRole = "774298073"

$apiKey = $env:ROBLOX_API_KEY

if (-not $apiKey) {
    Write-Host "ERROR: Roblox API key is missing." -ForegroundColor Red
    exit 1
}

$headers = @{
    "x-api-key" = $apiKey
}

$stateFile = "known-members.json"

function Get-AllMembers {
    $members = @()
    $token = $null

    do {
        $url = "https://apis.roblox.com/cloud/v2/groups/$groupId/memberships?pageSize=100"

        if ($token) {
            $url += "&pageToken=$([uri]::EscapeDataString($token))"
        }

        $page = Invoke-RestMethod `
            -Uri $url `
            -Headers $headers `
            -Method Get

        $members += $page.groupMemberships
        $token = $page.nextPageToken

    } while ($token)

    return $members
}

Write-Host "Checking Project Dipolog..."

$members = @(Get-AllMembers)

# ------------------------------------------
# First run:
# Save everybody who is already a member.
# Nobody gets ranked on the first run.
# ------------------------------------------

if (-not (Test-Path $stateFile)) {

    $knownMembers = @(
        $members | ForEach-Object {
            $_.path
        }
    )

    $knownMembers | ConvertTo-Json | Set-Content $stateFile

    Write-Host ""
    Write-Host "First run completed." -ForegroundColor Green
    Write-Host "Existing members have been recorded."
    Write-Host "They will NOT be ranked."
    Write-Host "Future members will be automatically ranked."

    exit 0
}

# ------------------------------------------
# Load previously known members
# ------------------------------------------

$knownMembers = @(Get-Content $stateFile | ConvertFrom-Json)

$newMembers = @(
    $members | Where-Object {
        $knownMembers -notcontains $_.path
    }
)

Write-Host "New members found: $($newMembers.Count)"

# ------------------------------------------
# Process NEW members only
# ------------------------------------------

foreach ($member in $newMembers) {

    $membershipId = $member.path.Split('/')[-1]
    $userId = $member.user.Split('/')[-1]

    # Only rank new members who are still Visitors.
    if ($member.role -ne "groups/$groupId/roles/$visitorRole") {
        Write-Host "User $userId is not a Visitor. Skipping."
        continue
    }

    Write-Host "New Visitor detected: $userId" -ForegroundColor Yellow

    $body = @{
        role = "groups/$groupId/roles/$targetRole"
    } | ConvertTo-Json

    try {

        Invoke-RestMethod `
            -Uri "https://apis.roblox.com/cloud/v2/groups/$groupId/memberships/$membershipId`:assignRole" `
            -Headers $headers `
            -Method Post `
            -ContentType "application/json" `
            -Body $body

        Write-Host "SUCCESS: $userId -> [CIV] Dipolognon" -ForegroundColor Green

    }
    catch {

        Write-Host "FAILED: $userId" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# ------------------------------------------
# Remember everyone currently in the group
# ------------------------------------------

$allKnownMembers = @(
    $members | ForEach-Object {
        $_.path
    }
)

$allKnownMembers | ConvertTo-Json | Set-Content $stateFile

Write-Host "Finished."
