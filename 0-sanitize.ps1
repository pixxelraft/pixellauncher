<# 0‑sanitize.ps1
   System cleanup: Recycle Bin, temp folders, clipboard, DNS
   Auto‑elevates to Administrator
   Final — June 2025
#>

# ------------------------ 0. Elevate if needed ------------------------
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "Re-launching as Administrator..."
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -WindowStyle Normal
    exit
}

# ------------------------ 1. Start cleaning ---------------------------
Write-Host "`nCleaning system..." -ForegroundColor Cyan

# 1.1 Recycle Bin
try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Host "Recycle Bin cleared." -ForegroundColor Green
} catch {
    Write-Host "Could not clear Recycle Bin." -ForegroundColor Yellow
}

# 1.2 Temp folders  (— fixed: no confirmation prompts)
$tempTargets = @("$env:TEMP", "C:\Windows\Temp")
foreach ($t in $tempTargets) {
    if (-not (Test-Path $t)) { continue }

    $deleted = 0
    try {
        # Only top‑level items; each removed with ‑Recurse to clear sub‑content silently
        Get-ChildItem -Path $t -Force -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            $deleted++
        }
        Write-Host "Temp cleaned: $t ($deleted items)" -ForegroundColor Green
    } catch {
        Write-Host "Could not clean: $t" -ForegroundColor Yellow
    }
}

# 1.3 Clipboard
try {
    Set-Clipboard ""
    Write-Host "Clipboard cleared." -ForegroundColor Green
} catch {
    Write-Host "Could not clear clipboard." -ForegroundColor Yellow
}

# 1.4 DNS cache
try {
    ipconfig /flushdns | Out-Null
    Write-Host "DNS flushed." -ForegroundColor Green
} catch {
    Write-Host "Could not flush DNS." -ForegroundColor Yellow
}

Write-Host "`nDone. System is fresh." -ForegroundColor Green
