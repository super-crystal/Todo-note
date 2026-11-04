$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$javac = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin/javac.exe' } else { 'javac' }
$java = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin/java.exe' } else { 'java' }
$classes = Join-Path $projectRoot '.tools/native-check'
New-Item -ItemType Directory -Force -Path $classes | Out-Null
& $javac -encoding UTF-8 -d $classes 'android/app/src/main/java/cn/shiguang/shiguang_todo/ReminderTiming.java' 'android/app/src/test/java/cn/shiguang/shiguang_todo/ReminderTimingTest.java'
if ($LASTEXITCODE -ne 0) { throw 'Native reminder timing compilation failed.' }
& $java -cp $classes cn.shiguang.shiguang_todo.ReminderTimingTest
if ($LASTEXITCODE -ne 0) { throw 'Native reminder timing checks failed.' }
