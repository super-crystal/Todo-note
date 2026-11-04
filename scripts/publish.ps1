param(
    [string]$Repository = 'super-crystal/Todo-note',
    [string]$Tag = 'v1.0.0'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$apkPath = Join-Path $projectRoot 'output/shiguang-todo-latest.apk'
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
    $uploadUrl = ($release.upload_url -replace '\{.*\}$', '') + '?name=shiguang-todo-latest.apk'
    $asset = Invoke-RestMethod -Method Post -Uri $uploadUrl -Headers $headers -ContentType 'application/vnd.android.package-archive' -InFile $apkPath
    if ($asset.size -ne (Get-Item -LiteralPath $apkPath).Length) { throw 'Uploaded APK size mismatch; release remains a draft.' }
    $published = Invoke-RestMethod -Method Patch -Uri "https://api.github.com/repos/$Repository/releases/$($release.id)" -Headers $headers -ContentType 'application/json' -Body '{"draft":false}'
    Write-Output $published.html_url
    Write-Output $asset.browser_download_url
} finally {
    $headers.Clear()
    $credential.Clear()
    $credentialLines = $null
}
