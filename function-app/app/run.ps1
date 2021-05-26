using namespace System.Net

#region Initialize

# Input bindings are passed in via param block.
param(
    $Request,
    $TriggerMetadata
)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
[System.Net.Mail.MailAddress]$user = $Request.Query.User
if (-not $user) {
    [System.Net.Mail.MailAddress]$user = $Request.Body.User
}
if (Test-Path "$env:HOME/site/wwwroot/app/driveMaps.json") {
    $jsonPath = "$env:HOME/site/wwwroot/app/driveMaps.json"
    $drvPath = Get-Content $jsonPath -raw
    $mapRef = $ExecutionContext.InvokeCommand.ExpandString( $drvPath ) | ConvertFrom-Json
}
else {
    $jsonPath = "$PSScriptRoot/driveMaps.json"
    $drvPath = Get-Content $jsonPath -raw
    $mapRef = $ExecutionContext.InvokeCommand.ExpandString( $drvPath ) | ConvertFrom-Json
}
$hash = (Get-FileHash $jsonPath).Hash
$hashcheck = $hash.Substring($hash.length - 6, 6)

$mapRef
#endregion

#region Functions

function Get-AuthHeader {
    param (
        [Parameter(mandatory = $true)]
        [string]$tenant_id,
        [Parameter(mandatory = $true)]
        [string]$client_id,
        [Parameter(mandatory = $true)]
        [string]$client_secret,
        [Parameter(mandatory = $true)]
        [string]$resource_url
    )
    $body = @{
        resource      = $resource_url
        client_id     = $client_id
        client_secret = $client_secret
        grant_type    = "client_credentials"
        scope         = "openid"
    }
    try {
        $response = Invoke-RestMethod -Method post -Uri "https://login.microsoftonline.com/$tenant_id/oauth2/token" -Body $body -ErrorAction Stop
        $headers = @{ }
        $headers.Add("Authorization", "Bearer " + $response.access_token)
        return $headers
    }
    catch {
        Write-Error $_.Exception
    }
}

function Get-JsonFromGraph {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $token,
        [Parameter(Mandatory = $true)]
        $strQuery,
        [parameter(mandatory = $true)] [ValidateSet('v1.0', 'beta')]
        $ver

    )
    #proxy pass-thru
    $webClient = new-object System.Net.WebClient
    $webClient.Headers.Add("user-agent", "PowerShell Script")
    $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

    try {
        $header = $token
        if ($header) {
            #create the URL
            $url = "https://graph.microsoft.com/$ver/$strQuery"

            #Invoke the Restful call and display content.
            Write-Verbose $url
            $query = Invoke-RestMethod -Method Get -Headers $header -Uri $url -ErrorAction STOP
            if ($query) {
                if ($query.value) {
                    #multiple results returned. handle it
                    $query = Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/$ver/$strQuery" -Headers $header
                    $result = @()
                    while ($query.'@odata.nextLink') {
                        Write-Verbose "$($query.value.Count) objects returned from Graph"
                        $result += $query.value
                        Write-Verbose "$($result.count) objects in result array"
                        $query = Invoke-RestMethod -Method Get -Uri $query.'@odata.nextLink' -Headers $header
                    }
                    $result += $query.value
                    Write-Verbose "$($query.value.Count) objects returned from Graph"
                    Write-Verbose "$($result.count) objects in result array"
                    return $result
                }
                else {
                    #single result returned. handle it.
                    $query = Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/$ver/$strQuery" -Headers $header
                    return $query
                }
            }
            else {
                $errMsg = @{
                    errNumber = 404
                    errMsg    = "No results found. Either there literally is nothing there or your query was malformed."
                }
            }
            throw;
        }
        else {
            $errMsg = @{
                errNumber = 401
                errMsg    = "Authentication Failed during attempt to create Auth header."
            }
            throw;
        }
    }
    catch {
        return $errMsg
    }
}

#endregion

#region Process
$params = @{
    tenant_id     = $env:tenant_id
    client_id     = $env:client_id
    client_secret = $env:client_secret
    resource_url  = "https://graph.microsoft.com"
}
$token = Get-AuthHeader @params

if ($user) {
    $status = [HttpStatusCode]::OK
    $userQuery = "users?`$filter=startswith(userPrincipalName,'{0}')&`$select=id" -f $user
    $userId = (Get-JsonFromGraph -token $token -strQuery $userQuery -ver v1.0).id
    $userQuery
    $user
    $userId
    if ($userId) {
        $groupQuery = "users/$userId/memberOf"
        $groups = (Get-JsonFromGraph -token $token -strQuery $groupQuery -ver v1.0).displayName
    }

    $drivesToMap = @()
    $drivesToMap += ($mapRef.drives | Where-Object { $_.group -eq "BASE" }).drives

    $printersToMap = @()
    $printersToMap += ($mapRef.printers | Where-Object { $_.group -eq "BASE" }).printers

    foreach ($group in $groups) {

        if ($mapRef.drives.group -match $group -or $mapRef.printers.group -match $group) {
            
            $drivesToMap += ($mapRef.drives | Where-Object { $_.group -eq $group }).drives
            $printersToMap += ($mapRef.printers | Where-Object { $_.group -eq $group }).printers
        }
    }

    $result = [PSCustomObject]@{
        hash     = $hashCheck
        drives   = $drivesToMap | Where-Object { $null -ne $_ }
        printers = $printersToMap | Where-Object { $null -ne $_ }
    }
}
else {
    $status = [HttpStatusCode]::BadRequest
    $result = "Please pass a name on the query string or in the request body."
}

#endregion

#region Output
# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = $status
        Body       = $result
    })
#endregion