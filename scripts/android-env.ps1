# Load this into PowerShell using: . .\scripts\android-env.ps1
$ViewQRoot = Split-Path $PSScriptRoot -Parent
$ViewQJava = Join-Path $ViewQRoot '.tools\java\jdk-21.0.13+9'
$ViewQSdk = Join-Path $ViewQRoot '.tools\android-sdk'
if (Test-Path $ViewQJava) { $env:JAVA_HOME = $ViewQJava }
if (Test-Path $ViewQSdk) {
    $env:ANDROID_HOME = $ViewQSdk
    $env:ANDROID_SDK_ROOT = $ViewQSdk
}
$env:GRADLE_USER_HOME = Join-Path $ViewQRoot '.tools\gradle-cache'
$env:PATH = "$(Join-Path $ViewQRoot '.tools\flutter\bin');$(Join-Path $ViewQSdk 'platform-tools');$env:PATH"
