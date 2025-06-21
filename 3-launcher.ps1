<# 3‑launcher.ps1
   Launches apps, folders, URLs, shell‑URIs & scripts for a workspace
   FINAL — June 2025 (elevates .ps1 items)
#>

param(
    [string]$Workspace    # optional:  px  Study
)

# ---------------------- 1. Load config ----------------------------
$configPath = Join-Path $PSScriptRoot 'config.json'
if (-not (Test-Path $configPath)) {
    Write-Error "config.json not found. Run setup first."
    exit 1
}

$config        = Get-Content $configPath | ConvertFrom-Json
$allWorkspaces = $config.workspaces.PSObject.Properties.Name

# ---------------------- 2. Pick workspace -------------------------
if (-not $Workspace) {
    Write-Host ""
    Write-Host "Available workspaces:"
    Write-Host "[0] Exit"
    for ($i = 0; $i -lt $allWorkspaces.Count; $i++) {
        Write-Host "[$($i + 1)] $($allWorkspaces[$i])"
    }

    $choice = Read-Host "Enter number to launch"
    if ($choice -eq '0') { Write-Host "Exit."; exit 0 }

    if ($choice -match '^\d+$' -and $choice -ge 1 -and $choice -le $allWorkspaces.Count) {
        $Workspace = $allWorkspaces[[int]$choice - 1]
    } else {
        Write-Error "Invalid choice."
        exit 1
    }
}

$items = $config.workspaces.$Workspace
if (-not $items) {
    Write-Error "Workspace '$Workspace' not found."
    exit 1
}

Write-Host "Launching workspace: $Workspace"

# ---------------------- 3. Helper ---------------------------------
function Invoke-LauncherItem {
    param([pscustomobject]$obj)

    $p = $obj.path
    $b = $obj.browser

    try {
        switch ($true) {

            # ------------------- URL -------------------
            { $p -match '^https?://' } {
                if     ($b)                     { Start-Process $b $p }
                elseif ($config.defaultBrowser) { Start-Process $config.defaultBrowser $p }
                else                            { Start-Process $p }
                break
            }

            # ------------- shell: URI -----------------
            { $p -match '^shell:' } {
                Start-Process explorer.exe $p
                break
            }

            # ------------- PS1 script -----------------
            { ($p -like '*.ps1') -and (Test-Path $p) } {
                $wd = Split-Path $p -Parent
                Start-Process powershell.exe `
                    -WorkingDirectory $wd `
                    -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$p`"" `
                    -Verb RunAs               # elevation so the script can self‑clean
                break
            }

            # ---------- existing file/folder ----------
            { Test-Path $p } {
                if ((Get-Item $p).PSIsContainer) { Start-Process explorer.exe $p }
                else                             { Start-Process $p }
                break
            }

            # -------------- fallback ------------------
            default { Write-Warning "Path not found or unsupported: $p" }
        }
    }
    catch {
        Write-Warning "Failed to launch: $p"
    }
}

# ---------------------- 4. Launch items ---------------------------
foreach ($itm in $items) { Invoke-LauncherItem $itm }

Write-Host "All launch tasks completed."
