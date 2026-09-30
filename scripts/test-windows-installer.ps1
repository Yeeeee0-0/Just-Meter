$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot)
$installer = (Get-ChildItem outputs/*Windows*Setup.exe | Select-Object -First 1).FullName
$app = "$env:ProgramFiles/Just Meter/Just Meter.exe"
$vst = "$env:CommonProgramFiles/VST3/JustMeter.vst3/Contents/x86_64-win/JustMeter.vst3"
$uninstaller = "$env:ProgramFiles/Just Meter/unins000.exe"
# Execute only inside an isolated CI runner, never on a developer workstation.
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Installer integration tests require an isolated GitHub Actions runner' }
$results = @()
foreach ($case in @(@{Components='app'; Language='english'}, @{Components='vst3'; Language='chinesesimplified'}, @{Components='app,vst3'; Language='english'})) {
    $process = Start-Process $installer -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /TYPE=custom /COMPONENTS=`"$($case.Components)`" /LANG=$($case.Language)" -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Installer exit $($process.ExitCode)" }
    $hasApp = Test-Path $app; $hasPlugin = Test-Path $vst
    if ($hasApp -ne ($case.Components -match 'app') -or $hasPlugin -ne ($case.Components -match 'vst3')) { throw "Wrong installed components: $($case.Components)" }
    $results += @{ components=$case.Components; language=$case.Language; app=$hasApp; vst3=$hasPlugin; installExit=$process.ExitCode }
    $remove = Start-Process $uninstaller -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -Wait -PassThru
    if ($remove.ExitCode -ne 0 -or (Test-Path $app) -or (Test-Path $vst)) { throw 'Uninstall did not remove installed binaries' }
}
$results | ConvertTo-Json | Set-Content outputs/windows-installer.json -Encoding utf8
Write-Host 'PASS: app-only, VST3-only, both; English/Chinese; correct destinations; uninstall'
