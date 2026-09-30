$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot)
New-Item -ItemType Directory -Force build/windows-package/Licenses, outputs | Out-Null
Copy-Item vendor/libebur128/COPYING build/windows-package/Licenses/libebur128-MIT.txt -Force
Copy-Item vendor/vst3sdk/LICENSE.txt build/windows-package/Licenses/VST3-SDK-MIT.txt -Force
Copy-Item LICENSE build/windows-package/Licenses/Just-Meter-MIT.txt -Force
Copy-Item THIRD_PARTY_NOTICES.md build/windows-package/Licenses/ -Force
Copy-Item vendor/json/LICENSE.MIT build/windows-package/Licenses/nlohmann-json-MIT.txt -Force
Copy-Item vendor/webview2/LICENSE.txt build/windows-package/Licenses/WebView2.txt -Force
Copy-Item 'build/windows/Release/Just Meter.exe' build/windows-package/ -Force
Copy-Item build/windows/VST3/Release/JustMeter.vst3 build/windows-package/ -Recurse -Force
Copy-Item docs/Windows.md build/windows-package/README.md -Force
Compress-Archive -Path build/windows-package/* -DestinationPath outputs/Just-Meter-0.1.3-Windows-x64-preview-Portable.zip -Force
if (!(Test-Path vendor/WebView2RuntimeInstallerX64.exe)) {
    Invoke-WebRequest 'https://go.microsoft.com/fwlink/p/?LinkId=2124701' -OutFile vendor/WebView2RuntimeInstallerX64.exe
}
$signature = Get-AuthenticodeSignature vendor/WebView2RuntimeInstallerX64.exe
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') { throw 'Invalid Microsoft runtime signature' }
Invoke-WebRequest 'https://raw.githubusercontent.com/kira-96/Inno-Setup-Chinese-Simplified-Translation/main/ChineseSimplified.isl' -OutFile vendor/ChineseSimplified.isl
$compiler = "${env:ProgramFiles(x86)}/Inno Setup 6/ISCC.exe"
if (!(Test-Path $compiler)) { throw 'Install Inno Setup 6 before packaging' }
& $compiler installer/windows/JustMeter.iss
if ($LASTEXITCODE) { throw 'Installer build failed' }
$hashes = Get-ChildItem outputs/Just-Meter-*-Windows-* -File | Where-Object Extension -In '.exe','.zip' | ForEach-Object { $h=Get-FileHash $_.FullName -Algorithm SHA256; "$($h.Hash.ToLower())  $($_.Name)" }
[IO.File]::WriteAllLines((Join-Path $PWD outputs/Just-Meter-0.1.3-Windows-SHA256SUMS.txt), $hashes, [Text.UTF8Encoding]::new($false))
