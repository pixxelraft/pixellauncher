<# PixelLauncher 1‑setup.ps1
     All‑in‑one wizard to create, update, or rebuild workspaces.
     FINAL — June 2025 (array‑conversion compatibility fix)
#>

# ────────────────── 0.  Helper functions ─────────────────────────────
function Save-Config {
    param($ConfigObj, $Path)
    $ConfigObj | ConvertTo-Json -Depth 6 |
        Set-Content -Path $Path -Encoding UTF8
    Write-Host "Config saved to: $Path"
}

function Ensure-ExecutionPolicy {
    $pol = Get-ExecutionPolicy -Scope CurrentUser
    if ($pol -in @('Restricted','Undefined')) {
        try {
            Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force -ErrorAction Stop
            Write-Host "Execution policy set to RemoteSigned (CurrentUser)."
        } catch {
            Write-Warning "Could not change execution policy. Run PowerShell as Administrator or set it manually."
        }
    }
}

function Ensure-px {
    $profile = $PROFILE
    if (-not (Test-Path $profile)) { New-Item -ItemType File -Path $profile -Force | Out-Null }
    (Get-Content $profile -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch 'function px' }) |
        Set-Content $profile
    $launcher = Join-Path $PSScriptRoot '3-launcher.ps1'
    Add-Content $profile "`nfunction px { & '$launcher' @args }"
    Write-Host "px helper added to profile → $profile"
}

# ────────────────── Workspace helpers ────────────────────────────────
function Read-Items {
    param([string]$WsName)
    $list = New-Object System.Collections.ArrayList
    while ($true) {
        $p = (Read-Host "  Add app/folder/URL for '$WsName' (blank to finish)").Trim('"').Trim()
        if ([string]::IsNullOrWhiteSpace($p)) { break }

        $b = ''
        if ($p -match '^https?://') {
            Write-Host "    Using default browser: $defaultBrowser (leave blank unless override)"
            $b = (Read-Host "    Browser override (blank = default)").Trim('"').Trim()
        }
        $null = $list.Add([PSCustomObject]@{ path = $p ; browser = $b })
    }
    return $list
}

function Add-Workspace {
    param([Hashtable]$Ws)

    $name = (Read-Host "Enter workspace name").Trim()
    if (-not $name)             { Write-Warning "Blank name."            ; return }
    if ($name -eq 'Sanitize')   { Write-Warning "Sanitize is reserved."  ; return }
    if ($Ws.ContainsKey($name)) { Write-Warning "Workspace already exists."; return }

    $arrList = Read-Items -WsName $name          # returns ArrayList
    $items   = @($arrList)                       # robust array conversion

    if ($items.Length -gt 0) {
        $Ws[$name] = $items
        Write-Host "Workspace '$name' added."
    } else {
        Write-Warning "No items entered; workspace not created."
    }
}

function Delete-Workspace {
    param([Hashtable]$Ws)
    $names = @($Ws.Keys | Where-Object { $_ -ne 'Sanitize' } | Sort-Object)
    if (-not $names) { Write-Host "No deletable workspaces."; return }
    for ($i = 0; $i -lt $names.Count; $i++) { Write-Host "[$($i+1)] $($names[$i])" }
    $idx = (Read-Host "Number to delete (0 cancel)").Trim()
    if ($idx -eq '0') { return }
    if ($idx -match '^\d+$' -and $idx -ge 1 -and $idx -le $names.Count) {
        $target = $names[$idx - 1]
        if ((Read-Host "Type YES to confirm '$target'").Trim().ToUpper() -eq 'YES') {
            $Ws.Remove($target)
            Write-Host "Workspace '$target' deleted."
        }
    } else { Write-Warning "Invalid choice." }
}

function Edit-Workspace {
    param([Hashtable]$Ws)
    $names = @($Ws.Keys | Where-Object { $_ -ne 'Sanitize' } | Sort-Object)
    if (-not $names) { Write-Host "No editable workspaces."; return }
    for ($i = 0; $i -lt $names.Count; $i++) { Write-Host "[$($i+1)] $($names[$i])" }
    $sel = (Read-Host "Number to edit (0 cancel)").Trim()
    if ($sel -eq '0') { return }
    if (-not ($sel -match '^\d+$' -and $sel -ge 1 -and $sel -le $names.Count)) { Write-Warning "Invalid"; return }
    $wsName = $names[[int]$sel - 1]

    $items = New-Object System.Collections.ArrayList
    foreach ($it in $Ws[$wsName]) { $null = $items.Add($it) }

    while ($true) {
        Write-Host "`nEditing '$wsName'"
        for ($i = 0; $i -lt $items.Count; $i++) {
            $extra = if ($items[$i].browser) { " (Browser: $($items[$i].browser))" } else { '' }
            Write-Host "[$($i+1)] $($items[$i].path)$extra"
        }
        Write-Host "[A] Add  [D] Del  [Q] Quit"
        $a = (Read-Host "Choice").Trim().ToUpper()
        switch ($a) {
            'Q' {
                $Ws[$wsName] = @($items)          # persist with robust conversion
                Write-Host "Workspace '$wsName' updated."
                return
            }
            'A' {
                $addList = Read-Items -WsName $wsName
                foreach ($new in $addList) { $null = $items.Add($new) }
            }
            'D' {
                $d = (Read-Host "Item number to remove").Trim()
                if ($d -match '^\d+$') {
                    $i = [int]$d - 1
                    if ($i -ge 0 -and $i -lt $items.Count) {
                        $items.RemoveAt($i); Write-Host "Removed."
                    } else { Write-Warning "Range." }
                } else { Write-Warning "Invalid number." }
            }
            default { Write-Warning "Bad option." }
        }
    }
}

# ────────────────── 1.  Prep & config ────────────────────────────────
Ensure-ExecutionPolicy
$configPath     = Join-Path $PSScriptRoot 'config.json'
$workspaces     = @{}
$defaultBrowser = ''

if (Test-Path $configPath) {
    $cfg            = Get-Content $configPath | ConvertFrom-Json
    $defaultBrowser = $cfg.defaultBrowser
    foreach ($p in $cfg.workspaces.PSObject.Properties) { $workspaces[$p.Name] = $p.Value }
}
$sanitizePath           = Join-Path $PSScriptRoot '0-sanitize.ps1'
$workspaces['Sanitize'] = @([PSCustomObject]@{ path = $sanitizePath ; browser = '' })

# ────────────────── 2.  Main loop ────────────────────────────────────
while ($true) {
    Write-Host "`nPixelLauncher Setup Menu"
    Write-Host "[1] Add workspace"
    Write-Host "[2] Delete workspace"
    Write-Host "[3] Edit workspace items"
    Write-Host "[4] Change default browser (current: $defaultBrowser)"
    Write-Host "[5] View workspaces"
    Write-Host "[6] Save & exit"
    Write-Host "[7] Rebuild from scratch"
    Write-Host "[0] Exit without saving"
    $c = (Read-Host "Option").Trim().ToUpper()
    switch ($c) {
        '1' { Add-Workspace    -Ws $workspaces }
        '2' { Delete-Workspace -Ws $workspaces }
        '3' { Edit-Workspace   -Ws $workspaces }
        '4' { $defaultBrowser = (Read-Host "Full browser exe (blank default)").Trim() }
        '5' { $workspaces.Keys | Sort-Object | ForEach-Object { Write-Host " - $_" } }
        '6' {
            Save-Config ([PSCustomObject]@{ defaultBrowser = $defaultBrowser ; workspaces = $workspaces }) $configPath
            Ensure-px
            Write-Host "Configuration saved. Bye!"
            exit 0
        }
        '7' {
            if ((Read-Host "Type RESET").Trim().ToUpper() -eq 'RESET') {
                Remove-Item $configPath -Force -ErrorAction SilentlyContinue
                $workspaces              = @{}
                $defaultBrowser          = ''
                $workspaces['Sanitize']  = @([PSCustomObject]@{ path = $sanitizePath ; browser = '' })
                Write-Host "Config cleared."
            }
        }
        '0' { Write-Host "Exit."; exit 0 }
        default { Write-Warning "Invalid selection." }
    }
}
