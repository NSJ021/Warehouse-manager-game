#Requires -Version 5.1
<#
.SYNOPSIS
    Synthesises the placeholder rack-place sound from scratch.

.DESCRIPTION
    Writes warehouse-manager/assets/audio/rack_place.wav directly -- a RIFF
    header and raw 16-bit PCM samples, no external tooling and nothing
    downloaded. ~0.18 s, mono, 22050 Hz: a ~110 Hz sine with a 5 ms linear
    attack and an exponential decay, mixed with a short low-passed noise
    transient in the first ~25 ms. The aim is a cardboard-on-steel thud, not
    a click or a beep.

    Kept in tools/ rather than deleted after one use, on the same reasoning
    the api test layer already argues for (see engine_assumptions.gd's class
    doc): a throwaway probe that gets deleted has to be re-derived from
    scratch next time. It also makes the placeholder obviously *a*
    placeholder -- Phase 6's real audio pass replaces the file this writes,
    not the mechanism that plays it.

    The WAV still needs importing before Godot can use it (see 01-06-PLAN.md
    Task 2) -- run this, then let the editor import it once, then commit
    both rack_place.wav and the generated rack_place.wav.import.

.EXAMPLE
    ./tools/make-placeholder-audio.ps1
#>
[CmdletBinding()]
param(
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $OutFile = Join-Path $repoRoot 'warehouse-manager\assets\audio\rack_place.wav'
}

# ---------------------------------------------------------------- signal

$sampleRate = 22050
$duration = 0.18
$numSamples = [int][math]::Round($sampleRate * $duration)
$channels = 1
$bitsPerSample = 16
$blockAlign = $channels * ($bitsPerSample / 8)
$byteRate = $sampleRate * $blockAlign
$dataSize = $numSamples * $blockAlign

# Tone: ~110 Hz, 5 ms linear attack, then an exponential decay for the rest
# of the clip -- the "thud" itself.
$toneFreq = 110.0
$attackSeconds = 0.005
$toneDecayTau = 0.05

# Noise transient: the first ~25 ms only, one-pole low-passed so it reads as
# a soft impact rather than hiss, with its own much faster decay -- the
# "crack" of cardboard hitting the steel deck, layered under the tone.
$noiseSeconds = 0.025
$noiseDecayTau = 0.008
$noiseAlpha = 0.35

# Fixed seed: reproducible output, so re-running this script does not churn
# the committed .wav for no reason.
$rand = New-Object System.Random -ArgumentList 1

$samples = New-Object System.Double[] $numSamples
$noiseState = 0.0
$peak = 0.0

for ($i = 0; $i -lt $numSamples; $i++) {
    $t = $i / $sampleRate

    if ($t -lt $attackSeconds) {
        $toneEnv = $t / $attackSeconds
    } else {
        $toneEnv = [math]::Exp(-($t - $attackSeconds) / $toneDecayTau)
    }
    $tone = [math]::Sin(2.0 * [math]::PI * $toneFreq * $t) * $toneEnv

    $noise = 0.0
    if ($t -lt $noiseSeconds) {
        $whiteNoise = ($rand.NextDouble() * 2.0) - 1.0
        $noiseState = ($noiseAlpha * $whiteNoise) + ((1.0 - $noiseAlpha) * $noiseState)
        $noiseEnv = [math]::Exp(-$t / $noiseDecayTau)
        $noise = $noiseState * $noiseEnv
    }

    $sample = (0.75 * $tone) + (0.6 * $noise)
    $samples[$i] = $sample
    $abs = [math]::Abs($sample)
    if ($abs -gt $peak) { $peak = $abs }
}

# Normalise so the transient sits just under full scale rather than clipping.
$scale = 1.0
if ($peak -gt 0.0) { $scale = 0.85 / $peak }

# ---------------------------------------------------------------- write

$outDir = Split-Path -Parent $OutFile
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$ascii = [System.Text.Encoding]::ASCII

$stream = [System.IO.File]::Open($OutFile, [System.IO.FileMode]::Create)
try {
    $writer = New-Object System.IO.BinaryWriter($stream)

    # RIFF header
    $writer.Write($ascii.GetBytes('RIFF'))
    $writer.Write([int32](36 + $dataSize))
    $writer.Write($ascii.GetBytes('WAVE'))

    # fmt chunk
    $writer.Write($ascii.GetBytes('fmt '))
    $writer.Write([int32]16)             # chunk size
    $writer.Write([int16]1)              # PCM
    $writer.Write([int16]$channels)
    $writer.Write([int32]$sampleRate)
    $writer.Write([int32]$byteRate)
    $writer.Write([int16]$blockAlign)
    $writer.Write([int16]$bitsPerSample)

    # data chunk
    $writer.Write($ascii.GetBytes('data'))
    $writer.Write([int32]$dataSize)

    foreach ($s in $samples) {
        $clamped = [math]::Max(-1.0, [math]::Min(1.0, $s * $scale))
        $intSample = [int16]([math]::Round($clamped * 32767.0))
        $writer.Write($intSample)
    }

    $writer.Flush()
} finally {
    $stream.Close()
}

Write-Host "Wrote $OutFile ($numSamples samples, $dataSize bytes of PCM data, peak $([math]::Round($peak * $scale, 3)))"
