$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot)
New-Item -ItemType Directory -Force outputs | Out-Null
$runtime = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' -ErrorAction SilentlyContinue
if (!$runtime.pv) {
    Invoke-WebRequest 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile build/WebView2Setup.exe
    $signature = Get-AuthenticodeSignature build/WebView2Setup.exe
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') { throw 'Invalid Microsoft runtime signature' }
    $install = Start-Process build/WebView2Setup.exe -ArgumentList '/silent /install' -Wait -PassThru
    if ($install.ExitCode -ne 0) { throw "Runtime installation failed: $($install.ExitCode)" }
}
$report = Join-Path $PWD outputs/windows-ui.json
$file = Join-Path $PWD Tests/Reference-1kHz-stereo-minus20dBFS.wav
$app = Start-Process 'build/windows/Release/Just Meter.exe' -ArgumentList "--smoke-test `"$report`" --analyze `"$file`"" -PassThru
if (!$app.WaitForExit(60000)) { Stop-Process $app.Id -Force; throw 'Standalone editor did not become ready' }
if ($app.ExitCode -ne 0 -or !(Test-Path $report)) { throw 'Standalone test failed' }
$outer = Get-Content $report -Raw | ConvertFrom-Json
$encoded = $outer.result | ConvertFrom-Json
$ui = $encoded | ConvertFrom-Json
if (!$outer.webview -or !$ui.ready -or $ui.widgets -ne 4 -or $ui.errors) { throw "Invalid UI result: $encoded" }
$value = [double]::Parse($ui.integrated.Replace('−','-'), [Globalization.CultureInfo]::InvariantCulture)
if ([Math]::Abs($value + 20) -gt 0.15) { throw "Meter display is not driven by decoded audio: $value" }
$dll = (Get-ChildItem build/windows/VST3/Release -Recurse -File -Filter '*.vst3' | Select-Object -First 1).FullName
if (!$dll) { throw 'VST3 binary not found' }
$test = Start-Process build/windows/Release/WindowsPluginHost.exe -ArgumentList "`"$dll`"" -PassThru -NoNewWindow
if (!$test.WaitForExit(60000)) { Stop-Process $test.Id -Force; throw 'VST3 editor timed out' }
if ($test.ExitCode -ne 0) { throw 'VST3 integration test failed' }
Write-Host 'Standalone and VST3 editor checks passed.'
