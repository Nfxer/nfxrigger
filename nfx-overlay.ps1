Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$statePath = Join-Path $env:USERPROFILE "rigmod_state.json"
$modes = @{
    0 = "50/50"
    1 = "45/10/45"
    2 = "Blackjack"
    3 = "Paper"
    4 = "HiLo"
    5 = "Russian Roulette"
}

function Get-StateValue {
    param(
        [Parameter(Mandatory = $true)] $State,
        [Parameter(Mandatory = $true)] [string] $Name,
        $Fallback
    )

    if ($null -eq $State -or $null -eq $State.PSObject.Properties[$Name]) {
        return $Fallback
    }
    return $State.$Name
}

function Get-BindName {
    param($Code)

    if ($null -eq $Code) { return "None" }
    $keyCode = -1
    try { $keyCode = [int]$Code } catch { return "None" }

    if ($keyCode -lt 0) { return "None" }
    if ($keyCode -lt 8) { return "Mouse $($keyCode + 1)" }
    if (($keyCode -ge 65 -and $keyCode -le 90) -or ($keyCode -ge 48 -and $keyCode -le 57)) {
        return [string][char]$keyCode
    }
    return "Key $keyCode"
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Nfx Status Overlay"
$form.Size = New-Object System.Drawing.Size(460, 205)
$form.StartPosition = "Manual"
$form.Location = New-Object System.Drawing.Point(40, 40)
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(17, 17, 17)
$form.FormBorderStyle = "FixedToolWindow"

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.AutoSize = $false
$statusLabel.Size = New-Object System.Drawing.Size(440, 38)
$statusLabel.Location = New-Object System.Drawing.Point(10, 16)
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$statusLabel.ForeColor = [System.Drawing.Color]::Gray
$statusLabel.BackColor = $form.BackColor
$statusLabel.TextAlign = "MiddleCenter"
$statusLabel.Text = "WAITING FOR GAME..."
$form.Controls.Add($statusLabel)

$itemLabel = New-Object System.Windows.Forms.Label
$itemLabel.AutoSize = $false
$itemLabel.Size = New-Object System.Drawing.Size(440, 28)
$itemLabel.Location = New-Object System.Drawing.Point(10, 60)
$itemLabel.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Regular)
$itemLabel.ForeColor = [System.Drawing.Color]::White
$itemLabel.BackColor = $form.BackColor
$itemLabel.TextAlign = "MiddleCenter"
$form.Controls.Add($itemLabel)

$modeLabel = New-Object System.Windows.Forms.Label
$modeLabel.AutoSize = $false
$modeLabel.Size = New-Object System.Drawing.Size(440, 24)
$modeLabel.Location = New-Object System.Drawing.Point(10, 92)
$modeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$modeLabel.ForeColor = [System.Drawing.Color]::LightGray
$modeLabel.BackColor = $form.BackColor
$modeLabel.TextAlign = "MiddleCenter"
$form.Controls.Add($modeLabel)

$featureLabel = New-Object System.Windows.Forms.Label
$featureLabel.AutoSize = $false
$featureLabel.Size = New-Object System.Drawing.Size(440, 24)
$featureLabel.Location = New-Object System.Drawing.Point(10, 120)
$featureLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$featureLabel.ForeColor = [System.Drawing.Color]::DimGray
$featureLabel.BackColor = $form.BackColor
$featureLabel.TextAlign = "MiddleCenter"
$form.Controls.Add($featureLabel)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 100
$timer.Add_Tick({
    if (-not (Test-Path -LiteralPath $statePath)) {
        $statusLabel.Text = "WAITING FOR GAME..."
        $statusLabel.ForeColor = [System.Drawing.Color]::Gray
        $itemLabel.Text = ""
        $modeLabel.Text = ""
        $featureLabel.Text = ""
        return
    }

    try {
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    } catch {
        return
    }

    $tab = -1
    try { $tab = [int](Get-StateValue $state "tab" -1) } catch {}

    $modeFromState = Get-StateValue $state "mode" $null
    $mode = if ($null -ne $modeFromState -and [string]$modeFromState -ne "") {
        [string]$modeFromState
    } elseif ($modes.ContainsKey($tab)) {
        $modes[$tab]
    } else {
        "Unknown Mode"
    }

    $lastCard = -1
    try { $lastCard = [int](Get-StateValue $state "last_card" -1) } catch {}
    if ($tab -eq 4 -and $lastCard -ne -1) {
        $mode = "$mode (Ref: $($lastCard + 1))"
    }

    $winner = [string](Get-StateValue $state "winner" "None")
    if ([string]::IsNullOrWhiteSpace($winner)) {
        $winner = "None"
    }

    $paperLowEnabled = (Get-StateValue $state "paper_low_enabled" $false) -eq $true
    $paperLowPlayer = -1
    try { $paperLowPlayer = [int](Get-StateValue $state "paper_low_player" -1) } catch {}
    $paperLowBind = Get-BindName (Get-StateValue $state "paper_low_bind" $null)
    $rouletteOutcome = [string](Get-StateValue $state "roulette_outcome" $winner)
    if ([string]::IsNullOrWhiteSpace($rouletteOutcome)) {
        $rouletteOutcome = $winner
    }

    $modeLabel.Text = "Mode: $mode"
    if ($tab -eq 3) {
        if ($paperLowEnabled) {
            $pickText = if ($paperLowPlayer -ge 1 -and $paperLowPlayer -le 4) { "Player $paperLowPlayer" } else { $winner }
            $featureLabel.Text = "Paper Force Low: ON | $pickText | Toggle: $paperLowBind"
            $featureLabel.ForeColor = [System.Drawing.Color]::FromArgb(80, 220, 120)
        } else {
            $featureLabel.Text = "Paper Force Low: OFF | Toggle: $paperLowBind"
            $featureLabel.ForeColor = [System.Drawing.Color]::DimGray
        }
    } elseif ($tab -eq 5) {
        $featureLabel.Text = "Russian Target: $rouletteOutcome"
        $featureLabel.ForeColor = [System.Drawing.Color]::FromArgb(102, 204, 255)
    } else {
        $featureLabel.Text = ""
        $featureLabel.ForeColor = [System.Drawing.Color]::DimGray
    }

    if ($state.active -eq $true) {
        $statusLabel.Text = "RIG: ACTIVE"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 68, 68)
        if ($tab -eq 3 -and $paperLowEnabled) {
            $itemLabel.Text = "Low Outcome >>> $winner <<<"
        } else {
            $itemLabel.Text = "Outcome >>> $winner <<<"
        }
    } else {
        $statusLabel.Text = "RIG: DISABLED"
        $statusLabel.ForeColor = [System.Drawing.Color]::Gray
        $itemLabel.Text = "Waiting for toggle..."
    }
})

$timer.Start()
[void]$form.ShowDialog()
