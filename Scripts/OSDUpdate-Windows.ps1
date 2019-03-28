#======================================================================================
#   Begin
#======================================================================================
Write-Host "OSDUpdate Microsoft Windows" -ForegroundColor Green
#======================================================================================
#   Get OS Information
#======================================================================================
$OSCaption = $((Get-WmiObject -Class Win32_OperatingSystem).Caption).Trim()
$OSArchitecture = $((Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture).Trim()
$OSVersion = $((Get-WmiObject -Class Win32_OperatingSystem).Version).Trim()
$OSBuildNumber = $((Get-WmiObject -Class Win32_OperatingSystem).BuildNumber).Trim()
Write-Host "Operating System: $OSCaption" -ForegroundColor Cyan
Write-Host "OS Architecture: $OSArchitecture" -ForegroundColor Cyan
Write-Host "OS Version: $OSVersion" -ForegroundColor Cyan
Write-Host "OS Build Number: $OSBuildNumber" -ForegroundColor Cyan
if ($OSCaption -Like "*Windows 10*") {
    $OSReleaseID = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId).ReleaseId
    Write-Host "OS Release ID: $OSReleaseID" -ForegroundColor Cyan
}
#======================================================================================
#   Updates
#======================================================================================
$Updates = @()
$UpdateCatalogs = Get-ChildItem $PSScriptRoot "Windows*.xml"
Try {
    foreach ($Catalog in $UpdateCatalogs) {
        $Updates += Import-Clixml -Path $Catalog.FullName
    }
}
Catch {}
#======================================================================================
#   Sessions
#======================================================================================
[xml]$SessionsXML = Get-Content -Path "$env:WinDir\Servicing\Sessions\Sessions.xml"

$Sessions = $SessionsXML.SelectNodes('Sessions/Session') | ForEach-Object {
    New-Object -Type PSObject -Property @{
        Id = $_.Tasks.Phase.package.id
        KBNumber = $_.Tasks.Phase.package.name
        TargetState = $_.Tasks.Phase.package.targetState
        Client = $_.Client
        Complete = $_.Complete
        Status = $_.Status
    }
}
$Sessions = $Sessions | Where-Object {$_.Id -like "Package*"}
$Sessions = $Sessions | Select-Object -Property Id, KBNumber, TargetState, Client, Status, Complete | Sort-Object Complete -Descending
#======================================================================================
#   Architecture
#======================================================================================
if ($OSArchitecture -like "*64*") {$Updates = $Updates | Where-Object {$_.UpdateArch -eq 'x64'}}
else {$Updates = $Updates | Where-Object {$_.UpdateArch -eq 'x86'}}
#======================================================================================
#   Operating System
#======================================================================================
if ($OSCaption -like "*Windows 7*") {$Updates = $Updates | Where-Object {$_.UpdateOS -eq 'Windows 7'}}
if ($OSCaption -like "*Windows 10*") {$Updates = $Updates | Where-Object {$_.UpdateOS -eq 'Windows 10'}}
IF ($OSVersion -like "10.*") {$Updates = $Updates | Where-Object {$_.UpdateBuild -eq $OSReleaseID}}
#======================================================================================
#   Get-Hotfix
#======================================================================================
$InstalledUpdates = Get-HotFix
#======================================================================================
#   Windows Updates
#======================================================================================
Write-Host "Updating Windows" -ForegroundColor Green
foreach ($Update in $Updates) {
    $UpdatePath = "$PSScriptRoot\$($Update.Title)\$($Update.FileName)"

    if (Test-Path "$UpdatePath") {
        Write-Host "$UpdatePath" -ForegroundColor DarkGray
        if ($InstalledUpdates | Where-Object HotFixID -like "*$($Update.KBNumber)") {
            Write-Host "KB$($Update.KBNumber) is already installed" -ForegroundColor Cyan
        } else {
            Write-Host "Installing $($Update.Title) ..." -ForegroundColor Cyan
            Dism /Online /Add-Package /PackagePath:"$UpdatePath" /NoRestart
        }
    } else {
        Write-Warning "Not Found: $UpdatePath"
    }
}
#======================================================================================
#   Complete
#======================================================================================