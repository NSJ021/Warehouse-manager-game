#Requires -Version 5.1
<#
.SYNOPSIS
    Physics budget stress test: how many rigid bodies survive?

.DESCRIPTION
    Sweeps crate count in two passes.

      solo        One peer. Pure simulation cost, no replication. Isolates what
                  the physics alone costs per crate.
      networked   Four peers, which is the shipping maximum. The difference from
                  the solo pass is what replication costs.

    Each pass runs twice:

      settled     Sleeping allowed. Steady state, a tidy warehouse.
      awake       Nothing sleeps. The honest worst case, and the one that counts:
                  a HELD crate never sleeps, and nor does a rack mid-collapse.

    Prints a markdown table ready to paste into docs, and writes a CSV.

    Caveats it is honest about: headless means no rendering, so these are physics
    and network numbers only - a real client also has a frame budget to draw
    them. And all peers share one machine, which is fine on a 24-thread part but
    is not four separate PCs.

.EXAMPLE
    ./tools/run-stress.ps1
.EXAMPLE
    ./tools/run-stress.ps1 -Counts 6,50,100 -SkipNetworked
#>
[CmdletBinding()]
param(
    [string]$Godot = $env:GODOT_BIN,
    [int[]]$Counts = @(6, 50, 100, 200, 400),
    [int[]]$SoloCounts = @(6, 50, 100, 200, 400, 800),
    [int]$WarmupMs = 1500,
    [int]$SampleMs = 3000,
    [switch]$SkipNetworked
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectDir = 'warehouse-manager'
$scene = 'res://test/stress/physics_budget.tscn'

if ([string]::IsNullOrWhiteSpace($Godot)) {
    $Godot = 'C:\Users\spenc\OneDrive\Desktop\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe'
}
if (-not (Test-Path $Godot)) {
    Write-Host "FAIL: Godot not found at $Godot" -ForegroundColor Red
    exit 2
}

$logDir = Join-Path $env:TEMP 'nice-little-earner-stress'
if (Test-Path $logDir) { Remove-Item $logDir -Recurse -Force }
New-Item -ItemType Directory -Path $logDir | Out-Null

$results = New-Object System.Collections.Generic.List[object]

function Start-Peer {
    param([string]$Name, [string]$Role, [int]$CrateCount, [string]$Mode, [int]$Peers)
    $out = Join-Path $logDir "$Name.out.log"
    $err = Join-Path $logDir "$Name.err.log"
    New-Item -ItemType File -Path $out, $err -Force | Out-Null
    $godotArgs = @(
        '--headless', '--path', $projectDir, $scene, '--',
        "--role=$Role", "--crates=$CrateCount", "--mode=$Mode", "--peers=$Peers",
        "--warmup-ms=$WarmupMs", "--sample-ms=$SampleMs"
    )
    $p = Start-Process -FilePath $Godot -ArgumentList $godotArgs `
        -WorkingDirectory $repoRoot -NoNewWindow -PassThru `
        -RedirectStandardOutput $out -RedirectStandardError $err
    return [pscustomobject]@{ Process = $p; Out = $out; Err = $err; Name = $Name }
}

function Get-PeerLog {
    param($Job)
    $text = ''
    foreach ($f in @($Job.Out, $Job.Err)) {
        if (Test-Path $f) { $text += (Get-Content $f -Raw -Encoding UTF8 -ErrorAction SilentlyContinue) }
    }
    if ($null -eq $text) { return '' }
    return $text
}

function Wait-PeerExit {
    param($Job, [int]$TimeoutSeconds = 120)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while (-not $Job.Process.HasExited) {
        if ((Get-Date) -gt $deadline) {
            try { Stop-Process -Id $Job.Process.Id -Force -ErrorAction Stop } catch {}
            return $false
        }
        Start-Sleep -Milliseconds 120
    }
    try { $Job.Process.WaitForExit() } catch {}
    return $true
}

function Read-Result {
    param($Job, [string]$Pass)
    $text = Get-PeerLog $Job
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^\[stress\] RESULT (.+)$') {
            $row = [ordered]@{ pass = $Pass }
            foreach ($pair in ($Matches[1] -split '\s+')) {
                $kv = $pair -split '=', 2
                if ($kv.Count -eq 2) { $row[$kv[0]] = $kv[1] }
            }
            $results.Add([pscustomobject]$row)
            return $true
        }
        if ($line -match '^\[stress\] ABORT (.+)$') {
            Write-Host "      ABORT: $($Matches[1])" -ForegroundColor Red
            return $false
        }
    }
    Write-Host "      no result line from $($Job.Name)" -ForegroundColor Red
    return $false
}

function Invoke-Case {
    param([int]$CrateCount, [string]$Mode, [int]$Peers, [string]$Pass)
    Write-Host ("  {0,-10} crates={1,-4} mode={2}" -f $Pass, $CrateCount, $Mode) -NoNewline

    $tag = "$Pass-$Mode-$CrateCount"
    $hostJob = Start-Peer -Name "$tag-host" -Role 'host' -CrateCount $CrateCount -Mode $Mode -Peers $Peers
    $clients = New-Object System.Collections.Generic.List[object]

    if ($Peers -gt 1) {
        $ready = $false
        $deadline = (Get-Date).AddSeconds(60)
        while ((Get-Date) -lt $deadline) {
            if ((Get-PeerLog $hostJob) -match 'READY-TO-ACCEPT') { $ready = $true; break }
            if ($hostJob.Process.HasExited) { break }
            Start-Sleep -Milliseconds 120
        }
        if (-not $ready) {
            Write-Host '  -> host never became ready' -ForegroundColor Red
            if (-not $hostJob.Process.HasExited) {
                try { Stop-Process -Id $hostJob.Process.Id -Force -ErrorAction Stop } catch {}
            }
            return
        }
        for ($i = 1; $i -lt $Peers; $i++) {
            $clients.Add((Start-Peer -Name "$tag-client$i" -Role "client$i" -CrateCount $CrateCount -Mode $Mode -Peers $Peers))
        }
    }

    [void](Wait-PeerExit -Job $hostJob)
    foreach ($c in $clients) { [void](Wait-PeerExit -Job $c -TimeoutSeconds 60) }

    $ok = Read-Result -Job $hostJob -Pass $Pass
    foreach ($c in $clients) { [void](Read-Result -Job $c -Pass $Pass) }

    if ($ok) {
        $r = $results | Where-Object { $_.pass -eq $Pass -and $_.role -eq 'host' -and [int]$_.crates -eq $CrateCount -and $_.mode -eq $Mode } | Select-Object -Last 1
        Write-Host ("  -> phys {0,6} ms   sent {1,7} kb/s   active {2}" -f $r.phys_ms, $r.sent_kbps, $r.active) -ForegroundColor Green
    }
}

Write-Host ''
Write-Host '=== physics budget stress test ===' -ForegroundColor Cyan
Write-Host "cpu:  $((Get-CimInstance Win32_Processor).Name)"
Write-Host "logs: $logDir"
Write-Host ''

Write-Host 'PASS 1 - solo (no replication, pure simulation cost)' -ForegroundColor Cyan
foreach ($mode in @('settled', 'awake')) {
    foreach ($n in $SoloCounts) { Invoke-Case -CrateCount $n -Mode $mode -Peers 1 -Pass 'solo' }
}

if (-not $SkipNetworked) {
    Write-Host ''
    Write-Host 'PASS 2 - networked, 4 peers (the shipping maximum)' -ForegroundColor Cyan
    foreach ($mode in @('settled', 'awake')) {
        foreach ($n in $Counts) { Invoke-Case -CrateCount $n -Mode $mode -Peers 4 -Pass 'net4' }
    }
}

# ------------------------------------------------------------------ report

$csv = Join-Path $logDir 'results.csv'
$results | Export-Csv -Path $csv -NoTypeInformation
Write-Host ''
Write-Host "csv: $csv" -ForegroundColor DarkGray

Write-Host ''
Write-Host '--- host, by pass and mode (markdown) ---' -ForegroundColor Cyan
Write-Host ''
Write-Host '| pass | mode | crates | host phys ms | host proc ms | active bodies | sent kb/s |'
Write-Host '|---|---|---|---|---|---|---|'
foreach ($r in ($results | Where-Object { $_.role -eq 'host' })) {
    Write-Host ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} |" -f `
        $r.pass, $r.mode, $r.crates, $r.phys_ms, $r.proc_ms, $r.active, $r.sent_kbps)
}

Write-Host ''
Write-Host '--- worst client per case (markdown) ---' -ForegroundColor Cyan
Write-Host ''
Write-Host '| mode | crates | client phys ms | client proc ms |'
Write-Host '|---|---|---|---|'
$clientRows = $results | Where-Object { $_.role -ne 'host' }
foreach ($grp in ($clientRows | Group-Object { "$($_.mode)|$($_.crates)" })) {
    $worst = $grp.Group | Sort-Object { [double]$_.proc_ms } -Descending | Select-Object -First 1
    Write-Host ("| {0} | {1} | {2} | {3} |" -f $worst.mode, $worst.crates, $worst.phys_ms, $worst.proc_ms)
}

Write-Host ''
Write-Host 'Budget reminder: one physics tick is 16.67 ms at 60 Hz, and physics is' -ForegroundColor Yellow
Write-Host 'only one line in that budget. Headless means rendering is NOT included.' -ForegroundColor Yellow
exit 0
