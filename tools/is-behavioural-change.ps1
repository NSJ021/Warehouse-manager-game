# Decides, mechanically, whether the pending change can possibly alter behaviour.
#
# WHY THIS EXISTS
#
# The suite's bar is three consecutive green runs. That bar is a FLAKE DETECTOR:
# repetition only catches failures that do not happen every time, which in this
# project means the integration layer - two processes, real sockets, physics,
# uncapped headless timing. Repetition detects nothing else.
#
# A comment cannot introduce a flake. The only way a comment breaks anything is
# by breaking the parse, and a broken parse fails loudly on the FIRST run. So
# re-running a full triple after a doc-comment tweak on already-green code is
# about five minutes of wall clock spent proving nothing.
#
# The trap is that any DISCRETIONARY exemption ("this looks low-risk, one run
# will do") gets rationalised into, and this project has already paid for that
# lesson once: an intermittent leak survived from Phase 1 to Phase 2 because
# agents kept deciding a red run was the known flake rather than reading it.
#
# So the exemption is mechanical. Either every changed line is a comment or
# blank, or it is not. There is nothing here to have an opinion about.
#
# USAGE
#   ./tools/is-behavioural-change.ps1            # working tree + staged
#   ./tools/is-behavioural-change.ps1 -Ref HEAD~1
#
# Exit 0 = BEHAVIOURAL      -> the full three-consecutive-green bar applies.
# Exit 1 = NON-BEHAVIOURAL  -> one green run is sufficient and complete.
#
# Being wrong in the safe direction is deliberate: anything it cannot prove is
# inert is reported as behavioural.

param(
    [string]$Ref = ''
)

$ErrorActionPreference = 'Stop'

$diffArgs = @('diff', '-U0')
if ($Ref) { $diffArgs += $Ref } else { $diffArgs += 'HEAD' }

$lines = & git @diffArgs 2>$null
if (-not $lines) { Write-Host 'NON-BEHAVIOURAL - no changes at all'; exit 1 }

$currentFile = ''
$behavioural = @()

foreach ($line in $lines) {
    if ($line -match '^\+\+\+ b/(.+)$') { $currentFile = $Matches[1]; continue }
    if ($line -match '^(---|diff |index |@@)') { continue }
    if ($line -notmatch '^[+-]') { continue }

    # Documentation-only file types cannot execute. Markdown, text, licences.
    if ($currentFile -match '\.(md|txt|LICENSE)$') { continue }

    $content = $line.Substring(1).Trim()

    # Blank lines change nothing.
    if ($content -eq '') { continue }

    # GDScript comments: '#' and the '##' doc form. A line that is ONLY a
    # comment is inert. A code line carrying a trailing comment does not match
    # this and is correctly treated as behavioural - if the code half of that
    # line changed, it changed.
    if ($currentFile -match '\.gd$' -and $content.StartsWith('#')) { continue }

    # Anything else - .tscn, .cfg, .ps1, .json, or actual GDScript - counts.
    # Scene files have no comment syntax worth trusting, so every scene change
    # is behavioural by definition.
    $behavioural += "$currentFile : $content"
}

if ($behavioural.Count -eq 0) {
    Write-Host 'NON-BEHAVIOURAL - every changed line is a comment, blank, or documentation.' -ForegroundColor Green
    Write-Host '  One green run is sufficient. Repetition would only detect flakes, and a' -ForegroundColor DarkGray
    Write-Host '  comment cannot introduce one - a broken parse fails on the first run.' -ForegroundColor DarkGray
    exit 1
}

Write-Host "BEHAVIOURAL - $($behavioural.Count) changed line(s) can affect behaviour." -ForegroundColor Yellow
Write-Host '  The three-consecutive-green bar applies in full.' -ForegroundColor DarkGray
foreach ($b in ($behavioural | Select-Object -First 8)) { Write-Host "    $b" -ForegroundColor DarkYellow }
if ($behavioural.Count -gt 8) { Write-Host "    ... and $($behavioural.Count - 8) more" -ForegroundColor DarkGray }
exit 0
