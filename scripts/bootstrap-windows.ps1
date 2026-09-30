$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-Location (Split-Path $PSScriptRoot)
New-Item -ItemType Directory -Force vendor | Out-Null
function Checkout-Dependency($Name, $Url, $Commit) {
    $Directory = "vendor/$Name"
    if (!(Test-Path "$Directory/.git")) { git clone --filter=blob:none $Url $Directory }
    git -C $Directory checkout --detach $Commit
    if ($LASTEXITCODE -ne 0) { throw "Cannot check out $Name" }
}
Checkout-Dependency libebur128 https://github.com/jiixyj/libebur128.git 67b33abe1558160ed76ada1322329b0e9e058b02
Checkout-Dependency vst3sdk https://github.com/steinbergmedia/vst3sdk.git 3cdf9ca5d1f5b1b21e0a86832aa4abe55607bd96
git -C vendor/vst3sdk submodule update --init --recursive base pluginterfaces public.sdk cmake
if ($LASTEXITCODE -ne 0) { throw 'VST3 SDK submodules failed' }
if (!(Test-Path vendor/webview2/build/native/include/WebView2.h)) {
    Invoke-WebRequest https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/1.0.3650.58/microsoft.web.webview2.1.0.3650.58.nupkg -OutFile vendor/webview2.zip
    Expand-Archive vendor/webview2.zip vendor/webview2 -Force
}
Checkout-Dependency json-source https://github.com/nlohmann/json.git v3.12.0
New-Item -ItemType Directory -Force vendor/json | Out-Null
Copy-Item vendor/json-source/single_include/nlohmann/json.hpp vendor/json/json.hpp -Force
Copy-Item vendor/json-source/LICENSE.MIT vendor/json/LICENSE.MIT -Force
Write-Host 'Windows dependencies ready.'
