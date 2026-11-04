param(
    [string]$Repository = 'super-crystal/Todo-note',
    [string]$Tag = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$versionLine = Select-String -LiteralPath 'pubspec.yaml' -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+'
if (!$versionLine) { throw 'pubspec.yaml must declare a semantic app version.' }
$version = $versionLine.Matches[0].Groups[1].Value
if (!$Tag) { $Tag = "v$version" }
if ($Tag -ne "v$version") { throw 'Release tag must match the APK version.' }
$apkName = "shiguang-todo-$version.apk"
$apkPath = Join-Path $projectRoot "output/$apkName"
if (!(Test-Path -LiteralPath $apkPath)) { throw 'Build and validate the APK before publishing.' }
$pending = git status --porcelain
if ($pending) { throw 'Commit the iteration before publishing.' }
git push -u origin main
if ($LASTEXITCODE -ne 0) { throw 'Git push failed. No release was created.' }

# Reuse Git Credential Manager without writing credentials to disk or logs.
$credentialLines = "protocol=https`nhost=github.com`n`n" | git credential fill
if ($LASTEXITCODE -ne 0) { throw 'GitHub credentials are not available.' }
$credential = @{}
foreach ($line in $credentialLines) {
    if ($line -match '^([^=]+)=(.*)$') { $credential[$Matches[1]] = $Matches[2] }
}
if (!$credential['password']) { throw 'GitHub credential has no access token.' }
$headers = @{
    Authorization = "Bearer $($credential['password'])"
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}
try {
    $commit = (git rev-parse HEAD).Trim()
    $body = @{
        tag_name = $Tag
        target_commitish = $commit
        name = "拾光清单 $Tag"
        body = (Get-Content -LiteralPath 'RELEASE_NOTES.md' -Raw)
        draft = $true
        prerelease = $false
    } | ConvertTo-Json
    $release = Invoke-RestMethod -Method Post -Uri "https://api.github.com/repos/$Repository/releases" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body))
    $uploadUrl = ($release.upload_url -replace '\{.*\}$', '') + "?name=$apkName"
    $asset = Invoke-RestMethod -Method Post -Uri $uploadUrl -Headers $headers -ContentType 'application/vnd.android.package-archive' -InFile $apkPath
    if ($asset.size -ne (Get-Item -LiteralPath $apkPath).Length) { throw 'Uploaded APK size mismatch; release remains a draft.' }
    $digest = 'sha256:' + (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($asset.digest -ne $digest) { throw 'Uploaded APK digest mismatch; release remains a draft.' }
    $published = Invoke-RestMethod -Method Patch -Uri "https://api.github.com/repos/$Repository/releases/$($release.id)" -Headers $headers -ContentType 'application/json' -Body '{"draft":false}'
    Write-Output $published.html_url
    Write-Output ($published.assets | Where-Object name -eq $apkName | Select-Object -First 1 -ExpandProperty browser_download_url)
} finally {
    $headers.Clear()
    $credential.Clear()
    $credentialLines = $null
}
