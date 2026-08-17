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
                   path: grab, two-player carry, handoff, release. This is the
                   layer that matters, because host authority and held-item
                   handoff are exactly what unit tests cannot reach.

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
    [int]$RunTimeoutSeconds = 120
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

Write-Host '[1/2] smoke - every scene loads and instances' -ForegroundColor Cyan
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

Write-Host ''
Write-Host '[2/2] integration - 2 processes, grab / two-player carry / handoff' -ForegroundColor Cyan

$scene = 'res://test/integration/carry_session.tscn'
$host_ = Start-Godot -Name 'host' -GodotArgs @(
    '--headless', '--path', $projectDir, $scene, '--', '--role=host'
)

# Wait for the host to actually be listening before starting the client, rather
# than sleeping and hoping. This is what stops the suite being flaky.
$ready = $false
$deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
while ((Get-Date) -lt $deadline) {
    if ((Get-LogText $host_) -match 'READY-TO-ACCEPT') { $ready = $true; break }
    if ($host_.Process.HasExited) { break }
    Start-Sleep -Milliseconds 150
}

if (-not $ready) {
    $failures.Add('integration: host never reported READY-TO-ACCEPT')
    if (-not $host_.Process.HasExited) {
        try { Stop-Process -Id $host_.Process.Id -Force -ErrorAction Stop } catch {}
    }
    Show-TestLines $host_
} else {
    Write-Host '      host is listening, starting client' -ForegroundColor DarkGray
    $client = Start-Godot -Name 'client' -GodotArgs @(
        '--headless', '--path', $projectDir, $scene, '--', '--role=client'
    )

    $hostExited = Wait-ForExit -Job $host_ -TimeoutSeconds $RunTimeoutSeconds
    $clientExited = Wait-ForExit -Job $client -TimeoutSeconds 30

    if (-not $hostExited) {
        $failures.Add('integration: host hung and was killed')
    } else {
        $hostCode = Get-ExitCode $host_
        if ($hostCode -gt 0) { $failures.Add("integration host: exit code $hostCode") }
        Test-Marker $host_ 'RESULT=PASS' 'a host RESULT=PASS' | Out-Null
    }

    if (-not $clientExited) {
        $failures.Add('integration: client hung and was killed')
    } else {
        $clientCode = Get-ExitCode $client
        if ($clientCode -gt 0) { $failures.Add("integration client: exit code $clientCode") }
        Test-Marker $client 'RESULT=PASS' 'a client RESULT=PASS' | Out-Null
    }

    Write-Host '      --- host ---' -ForegroundColor DarkGray
    Show-TestLines $host_
    Write-Host '      --- client ---' -ForegroundColor DarkGray
    Show-TestLines $client

    Test-CleanLog $host_ | Out-Null
    Test-CleanLog $client | Out-Null
}

# ---------------------------------------------------------------- verdict

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host "PASS - all layers green in $([int]$sw.Elapsed.TotalSeconds)s" -ForegroundColor Green
    if ($KeepLogs) { Write-Host "logs kept: $logDir" }
    exit 0
}

Write-Host "FAIL - $($failures.Count) problem(s) in $([int]$sw.Elapsed.TotalSeconds)s" -ForegroundColor Red
foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
Write-Host ''
Write-Host "full logs: $logDir" -ForegroundColor Yellow
exit 1
