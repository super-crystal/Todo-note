param([switch]$SkipChecks)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$flutter = if (Test-Path -LiteralPath '.tools/flutter/bin/flutter.bat') {
    Join-Path $projectRoot '.tools/flutter/bin/flutter.bat'
} else { 'flutter' }
$dart = if (Test-Path -LiteralPath '.tools/flutter/bin/dart.bat') {
    Join-Path $projectRoot '.tools/flutter/bin/dart.bat'
} else { 'dart' }
function Invoke-Checked([scriptblock]$Command) {
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" }
}
Invoke-Checked { & $flutter pub get }
if (!$SkipChecks) {
    & (Join-Path $PSScriptRoot 'test-reminder-timing.ps1')
    Invoke-Checked { & $dart format . }
    Invoke-Checked { & $flutter analyze }
    Invoke-Checked { & $flutter test test/data/todo_repository_test.dart test/data/task_tags_test.dart test/data/reminder_lead_test.dart test/features/todo/state/todo_state_test.dart test/features/todo/state/calendar_state_test.dart test/features/todo/state/task_search_test.dart test/features/todo/state/task_schedule_test.dart test/features/todo/state/reminder_service_test.dart test/features/todo/ui/home_screen_test.dart test/features/todo/ui/task_calendar_test.dart test/features/todo/ui/reminder_lead_field_test.dart }
}
if (!(Test-Path -LiteralPath 'android/key.properties')) {
    New-Item -ItemType Directory -Force -Path '.signing' | Out-Null
    $password = [Guid]::NewGuid().ToString('N')
    $keytool = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin/keytool.exe' } else { 'keytool' }
    # Keep the signing identity across builds so installs can be upgraded in place.
    if (Test-Path -LiteralPath '.signing/release.jks') {
        throw 'Signing key exists but key.properties is missing. Restore its credentials before building.'
    }
    Invoke-Checked {
        & $keytool -genkeypair -noprompt -keystore '.signing/release.jks' -alias shiguang -keyalg RSA -keysize 3072 -validity 10000 -storepass $password -keypass $password -dname 'CN=Shiguang Todo'
    }
    @("storePassword=$password", "keyPassword=$password", 'keyAlias=shiguang', 'storeFile=../../.signing/release.jks') | Set-Content -LiteralPath 'android/key.properties' -Encoding ascii
}
Invoke-Checked { & $flutter build apk --release }
New-Item -ItemType Directory -Force -Path output | Out-Null
$versionLine = Select-String -LiteralPath 'pubspec.yaml' -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+'
if (!$versionLine) { throw 'pubspec.yaml must declare a semantic app version.' }
$apkName = "shiguang-todo-$($versionLine.Matches[0].Groups[1].Value).apk"
$apkPath = Join-Path $projectRoot "output/$apkName"
Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-release.apk' -Destination $apkPath -Force
# Keep the current APK after the replacement has succeeded.
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'output') -Filter 'shiguang-todo-*.apk' -File |
    Where-Object FullName -ne $apkPath | Remove-Item -Force
Get-FileHash -LiteralPath $apkPath -Algorithm SHA256
