#Requires -Version 5.1
<#
.SYNOPSIS
    The whole test suite, one command.

.DESCRIPTION
    Two layers, cheapest first:

      smoke        Every scene loads and instances. ~2 seconds. Catches stale
                   paths after a move, and a new class_name the editor has not
                   registered yet.
      integration  Two real processes over real ENet, driving the real keypress
                   path: grab, two-player carry, handoff, release, then solo
                   drag and its promotion back into a carry -- then a second
                   scenario for storage: place, a cell taking more than one,
                   a full cell refusing, a dragged crate refused above the
                   floor row (ADR 19), and LIFO retrieval -- then a third
                   scenario for a day: begin_run(), a broadcast manifest,
                   the truck dump into Goods IN, the door deriving itself
                   open, and the host-only right to call it a night early.
                   This is the layer that matters, because host authority
                   and held-item handoff are exactly what unit tests cannot
                   reach.

    Fails loudly and prints the failing steps plus both sides' state, so a red run
    tells you what disagreed without rerunning anything.

    Zero tolerance on engine errors and warnings: a clean run has none, so any at
    all fail the suite. A flaky netcode test is worse than no test, because it
    teaches you to ignore red.

.PARAMETER Godot
    Path to the Godot executable. Defaults to $env:GODOT_BIN, then the known
    install on this machine.

.PARAMETER SmokeOnly
    Skip the integration layer. For a fast check while editing.

.PARAMETER KeepLogs
    Print the full log paths and leave them in place on success too.

.EXAMPLE
    ./tools/run-tests.ps1
.EXAMPLE
    ./tools/run-tests.ps1 -SmokeOnly
#>
[CmdletBinding()]
param(
    [string]$Godot = $env:GODOT_BIN,
    [switch]$SmokeOnly,
    [switch]$KeepLogs,
    [int]$StartupTimeoutSeconds = 30,
    [int]$RunTimeoutSeconds = 200
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- setup

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectDir = 'warehouse-manager'   # relative on purpose: the absolute path
                                    # contains a space, and Start-Process does
                                    # not quote arguments for you.

if ([string]::IsNullOrWhiteSpace($Godot)) {
    $Godot = 'C:\Users\spenc\OneDrive\Desktop\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe'
}

if (-not (Test-Path $Godot)) {
    Write-Host "FAIL: Godot not found at $Godot" -ForegroundColor Red
    Write-Host "      Set GODOT_BIN or pass -Godot <path>."
    exit 2
}
if (-not (Test-Path (Join-Path $repoRoot "$projectDir\project.godot"))) {
    Write-Host "FAIL: no project.godot under $repoRoot\$projectDir" -ForegroundColor Red
    exit 2
}

$logDir = Join-Path $env:TEMP 'nice-little-earner-tests'
if (Test-Path $logDir) { Remove-Item $logDir -Recurse -Force }
New-Item -ItemType Directory -Path $logDir | Out-Null

$failures = New-Object System.Collections.Generic.List[string]
# The actual engine error/warning text, repeated in the verdict block so the
# cause is the last thing on screen rather than buried mid-run. See Test-CleanLog.
$engineErrorLines = New-Object System.Collections.Generic.List[string]
$sw = [System.Diagnostics.Stopwatch]::StartNew()

function Start-Godot {
    param([string[]]$GodotArgs, [string]$Name)
    $out = Join-Path $logDir "$Name.out.log"
    $err = Join-Path $logDir "$Name.err.log"
    New-Item -ItemType File -Path $out, $err -Force | Out-Null
    $p = Start-Process -FilePath $Godot -ArgumentList $GodotArgs `
        -WorkingDirectory $repoRoot -NoNewWindow -PassThru `
        -RedirectStandardOutput $out -RedirectStandardError $err
    return [pscustomobject]@{ Process = $p; Out = $out; Err = $err; Name = $Name }
}

function Get-LogText {
    param($Job)
    $text = ''
    foreach ($f in @($Job.Out, $Job.Err)) {
        # UTF8 explicitly: Godot writes UTF-8, and reading it as the ANSI codepage
        # turns any non-ASCII character into mojibake in the report.
        if (Test-Path $f) { $text += (Get-Content $f -Raw -Encoding UTF8 -ErrorAction SilentlyContinue) }
    }
    if ($null -eq $text) { return '' }
    return $text
}

function Get-ExitCode {
    param($Job)
    # Start-Process -PassThru hands back a Process whose ExitCode is not populated
    # until the handle is waited on. Without this it reads as $null, and
    # "$null -ne 0" then fails every single run regardless of the real result.
    try { $Job.Process.WaitForExit() } catch {}
    try { $Job.Process.Refresh() } catch {}
    try {
        $code = $Job.Process.ExitCode
        if ($null -eq $code) { return -1 }
        return [int]$code
    } catch {
        return -1
    }
}

function Test-Marker {
    param($Job, [string]$Pattern, [string]$What)
    if ((Get-LogText $Job) -match $Pattern) { return $true }
    $failures.Add("$($Job.Name): never reported $What")
    return $false
}

function Wait-ForExit {
    param($Job, [int]$TimeoutSeconds)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while (-not $Job.Process.HasExited) {
        if ((Get-Date) -gt $deadline) {
            try { Stop-Process -Id $Job.Process.Id -Force -ErrorAction Stop } catch {}
            return $false
        }
        Start-Sleep -Milliseconds 150
    }
    return $true
}

function Test-CleanLog {
    param($Job)
    $text = Get-LogText $Job
    # Engine complaints only. The test's own "FAIL" lines are reported separately,
    # via exit codes, so they are not double-counted here.
    $hits = [regex]::Matches($text, '(?im)^\s*(ERROR|WARNING|SCRIPT ERROR):')
    if ($hits.Count -gt 0) {
        $failures.Add("$($Job.Name): $($hits.Count) engine error/warning line(s)")
        foreach ($line in ($text -split "`r?`n" | Where-Object { $_ -match '(?i)^\s*(ERROR|WARNING|SCRIPT ERROR):' } | Select-Object -First 6)) {
            Write-Host "      $line" -ForegroundColor DarkYellow
            # Also kept for the verdict block. Printing them here alone was not
            # enough: they land mid-run under hundreds of [test] ok lines, and
            # the verdict - the part anyone actually reads - showed only a
            # count. That cost about ninety minutes on 02-06, where a dropped
            # RPC surfaced as a 20 s TIMEOUT in an unrelated assertion while
            # the real cause ("unknown peer ID: -1") sat in the .err log
            # nobody was tailing. Say the cause where the reader is looking.
            $engineErrorLines.Add("$($Job.Name): $($line.Trim())")
        }
        return $false
    }
    return $true
}

function Show-TestLines {
    param($Job)
    $text = Get-LogText $Job
    foreach ($line in ($text -split "`r?`n" | Where-Object { $_ -match '^\[(test|smoke)\]' })) {
        $colour = 'Gray'
        if ($line -match 'FAIL')  { $colour = 'Red' }
        if ($line -match 'RESULT=PASS') { $colour = 'Green' }
        if ($line -match '^\[test\] state') { $colour = 'Yellow' }
        Write-Host "      $line" -ForegroundColor $colour
    }
}

Write-Host ''
Write-Host '=== Nice Little Earner - test suite ===' -ForegroundColor Cyan
Write-Host "godot: $Godot"
Write-Host "logs:  $logDir"
Write-Host ''

# ---------------------------------------------------------------- smoke

Write-Host '[1/4] api - engine assumptions and decided invariants' -ForegroundColor Cyan
$api = Start-Godot -Name 'api' -GodotArgs @(
    '--headless', '--path', $projectDir, '--script', 'res://test/api/engine_assumptions.gd'
)
$apiExited = Wait-ForExit -Job $api -TimeoutSeconds $StartupTimeoutSeconds

if (-not $apiExited) {
    $failures.Add('api: timed out and was killed')
} else {
    $code = Get-ExitCode $api
    if ($code -gt 0) { $failures.Add("api: exit code $code") }
    Test-Marker $api '\[api\] PASS' 'an api PASS' | Out-Null
}
# Only the failures are worth printing here; 70-odd passing lines is noise.
foreach ($line in ((Get-LogText $api) -split "`r?`n" | Where-Object { $_ -match '^\[api\] (FAIL|PASS)' })) {
    $colour = 'Gray'
    if ($line -match 'FAIL') { $colour = 'Red' }
    if ($line -match 'PASS') { $colour = 'Green' }
    Write-Host "      $line" -ForegroundColor $colour
}
Test-CleanLog $api | Out-Null

Write-Host ''
Write-Host '[2/4] unit - the condition model, the dilemma maths, and the cell arithmetic' -ForegroundColor Cyan

# Enumerated rather than hardcoded: the next pure module (there will be one)
# should cost nothing to add here, and a loop that only checked the last
# file's marker would let earlier files fail silently - exactly the class of
# bug the zero-tolerance scan exists to prevent. Every file must earn its own
# [unit] PASS.
$unitDir = Join-Path $repoRoot "$projectDir\test\unit"
$unitScripts = Get-ChildItem -Path $unitDir -Filter '*.gd' | Sort-Object Name

foreach ($script in $unitScripts) {
    # Distinguishable per-file job name, so a Test-CleanLog or Test-Marker
    # failure below names the file rather than just saying "unit".
    $unitJob = Start-Godot -Name "unit-$($script.BaseName)" -GodotArgs @(
        '--headless', '--path', $projectDir, '--script', "res://test/unit/$($script.Name)"
    )
    $unitExited = Wait-ForExit -Job $unitJob -TimeoutSeconds $StartupTimeoutSeconds

    if (-not $unitExited) {
        $failures.Add("$($unitJob.Name): timed out and was killed")
    } else {
        $code = Get-ExitCode $unitJob
        if ($code -gt 0) { $failures.Add("$($unitJob.Name): exit code $code") }
        Test-Marker $unitJob '\[unit\] PASS' "a unit PASS ($($script.Name))" | Out-Null
    }
    # Same as the api layer: the passing lines are numerous and uninteresting,
    # and each file's own summary line is worth seeing on a green run.
    foreach ($line in ((Get-LogText $unitJob) -split "`r?`n" | Where-Object { $_ -match '^\[unit\] (FAIL|PASS|     )' })) {
        $colour = 'Gray'
        if ($line -match 'FAIL') { $colour = 'Red' }
        if ($line -match 'PASS') { $colour = 'Green' }
        Write-Host "      $line" -ForegroundColor $colour
    }
    Test-CleanLog $unitJob | Out-Null
}

Write-Host ''
Write-Host '[3/4] smoke - every scene loads and instances' -ForegroundColor Cyan
$smoke = Start-Godot -Name 'smoke' -GodotArgs @(
    '--headless', '--path', $projectDir, '--script', 'res://test/smoke/load_all_scenes.gd'
)
$smokeExited = Wait-ForExit -Job $smoke -TimeoutSeconds $StartupTimeoutSeconds

if (-not $smokeExited) {
    $failures.Add('smoke: timed out and was killed')
} else {
    $code = Get-ExitCode $smoke
    if ($code -gt 0) { $failures.Add("smoke: exit code $code") }
    Test-Marker $smoke '\[smoke\] PASS' 'a smoke PASS' | Out-Null
}
Show-TestLines $smoke

$smokeText = Get-LogText $smoke
if ($smokeText -match 'Could not find type') {
    Write-Host ''
    Write-Host '      HINT: a new class_name is not in the script class cache yet.' -ForegroundColor Yellow
    Write-Host '            Only the editor writes it. Rescan, then re-run:' -ForegroundColor Yellow
    Write-Host '            EditorInterface.get_resource_filesystem().scan()' -ForegroundColor Yellow
}
Test-CleanLog $smoke | Out-Null

if ($SmokeOnly) {
    Write-Host ''
    if ($failures.Count -eq 0) {
        Write-Host "PASS (smoke only) in $([int]$sw.Elapsed.TotalSeconds)s" -ForegroundColor Green
        exit 0
    }
    Write-Host 'FAIL' -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}

# ---------------------------------------------------------- integration

# Runs one two-process scenario (host + client, told apart by --role=) and
# folds its failures into the shared $failures list. Factored out because the
# integration block now runs twice — carry_session, then storage_session —
# and duplicating the READY-TO-ACCEPT wait, the per-role exit codes and the
# RESULT=PASS markers for a second scenario is exactly the kind of drift that
# lets one copy quietly stop being checked as strictly as the other.
function Invoke-IntegrationScenario {
    param([string]$Scene, [string]$Label)

    Write-Host ''
    Write-Host "      -- $Label --" -ForegroundColor Cyan

    $hostJob = Start-Godot -Name "$Label-host" -GodotArgs @(
        '--headless', '--path', $projectDir, $Scene, '--', '--role=host'
    )

    # Wait for the host to actually be listening before starting the client,
    # rather than sleeping and hoping. This is what stops the suite being flaky.
    $ready = $false
    $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if ((Get-LogText $hostJob) -match 'READY-TO-ACCEPT') { $ready = $true; break }
        if ($hostJob.Process.HasExited) { break }
        Start-Sleep -Milliseconds 150
    }

    if (-not $ready) {
        $failures.Add("$Label integration: host never reported READY-TO-ACCEPT")
        if (-not $hostJob.Process.HasExited) {
            try { Stop-Process -Id $hostJob.Process.Id -Force -ErrorAction Stop } catch {}
        }
        Show-TestLines $hostJob
        return
    }

    Write-Host '      host is listening, starting client' -ForegroundColor DarkGray
    $clientJob = Start-Godot -Name "$Label-client" -GodotArgs @(
        '--headless', '--path', $projectDir, $Scene, '--', '--role=client'
    )

    $hostExited = Wait-ForExit -Job $hostJob -TimeoutSeconds $RunTimeoutSeconds
    $clientExited = Wait-ForExit -Job $clientJob -TimeoutSeconds 30

    if (-not $hostExited) {
        $failures.Add("$Label integration: host hung and was killed")
    } else {
        $hostCode = Get-ExitCode $hostJob
        if ($hostCode -gt 0) { $failures.Add("$Label integration host: exit code $hostCode") }
        Test-Marker $hostJob 'RESULT=PASS' "a $Label host RESULT=PASS" | Out-Null
    }

    if (-not $clientExited) {
        $failures.Add("$Label integration: client hung and was killed")
    } else {
        $clientCode = Get-ExitCode $clientJob
        if ($clientCode -gt 0) { $failures.Add("$Label integration client: exit code $clientCode") }
        Test-Marker $clientJob 'RESULT=PASS' "a $Label client RESULT=PASS" | Out-Null
    }

    Write-Host "      --- $Label host ---" -ForegroundColor DarkGray
    Show-TestLines $hostJob
    Write-Host "      --- $Label client ---" -ForegroundColor DarkGray
    Show-TestLines $clientJob

    Test-CleanLog $hostJob | Out-Null
    Test-CleanLog $clientJob | Out-Null
}

Write-Host ''
Write-Host '[4/4] integration - 2 processes, carry / handoff / solo drag, storage, then a day' -ForegroundColor Cyan

Invoke-IntegrationScenario -Scene 'res://test/integration/carry_session.tscn' -Label 'carry'
Invoke-IntegrationScenario -Scene 'res://test/integration/storage_session.tscn' -Label 'storage'
Invoke-IntegrationScenario -Scene 'res://test/integration/goods_session.tscn' -Label 'goods'

# ---------------------------------------------------------------- verdict

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host "PASS - all layers green in $([int]$sw.Elapsed.TotalSeconds)s" -ForegroundColor Green
    if ($KeepLogs) { Write-Host "logs kept: $logDir" }
    exit 0
}

Write-Host "FAIL - $($failures.Count) problem(s) in $([int]$sw.Elapsed.TotalSeconds)s" -ForegroundColor Red
foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }

# The engine's own words, not just the tally. An engine error is very often the
# CAUSE of a test failure reported elsewhere in this same list - a dropped RPC
# shows up as a timeout in whichever assertion was waiting on it, many steps
# away from the line that actually broke. Read this block first.
if ($engineErrorLines.Count -gt 0) {
    Write-Host ''
    Write-Host '  engine said:' -ForegroundColor Yellow
    foreach ($line in $engineErrorLines) { Write-Host "    $line" -ForegroundColor DarkYellow }
    Write-Host '  (an engine error is usually the cause of any timeout above, not a separate problem)' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host "full logs: $logDir" -ForegroundColor Yellow
Write-Host '  read BOTH streams - assertions go to *.out.log, engine errors to *.err.log' -ForegroundColor DarkGray
exit 1
