param(
    [string]
    $requestBase64
)

function stringify($content) {
    if ((!$content) -or ($content -is [System.String])) {
        return $content
    } elseif ($content -is [System.Byte[]]) {
        return [System.Text.Encoding]::ASCII.GetString($content)
    } else {
        return $content.ToString()
    }
}

$httpLogs = Join-Path $env:USERPROFILE "http.log"
Add-Content -Path $httpLogs -Value "encrypted: $requestBase64" -Force | Out-Null

$decoded = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($requestBase64))
$reqObj = ConvertFrom-Json $decoded
$uri = [System.UriBuilder]$reqObj.url
$uri.Host = "localhost"
$req = @{ "Uri" = $uri.ToString() }

if ($reqObj.method) {
    $req.Method = [Microsoft.PowerShell.Commands.WebRequestMethod]$reqObj.method
}

if ($reqObj._body) {
    $req.Body = $reqObj._body
}

if ($reqObj.headers) {
    $req.Headers = @{}
    foreach ($prop in $reqObj.headers | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) {
        ## NOTE: not all http headers follow the same syntax. This delimitation logic is assumed to work for all headers we use
        $req.Headers[$prop] = $reqObj.headers.$prop -Join ","
    }
}

$transformed = $req | ConvertTo-Json -Compress -Depth 100
Add-Content -Path $httpLogs -Value "transformed: $transformed" -Force | Out-Null

try {
    $res = Invoke-WebRequest -UseBasicParsing -UseDefaultCredentials @req
} catch {
    $res = $_.Exception.Response
} finally {
    $result = ConvertTo-Json @{
        "url" = $res.ResponseUri;
        "status" = $res.StatusCode;
        "statusText" = $res.StatusDescription;
        "type" = $res."Content-Type";
        "headers" = $res.Headers;
        "body" = stringify $res.Content
    } -Compress -Depth 100
    Add-Content -Path $httpLogs -Value "result: $result" -Force | Out-Null
    $result
}