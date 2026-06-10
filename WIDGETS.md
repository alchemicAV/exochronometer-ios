# Exochronometer — The Instrument Panel

Every widget, what it shows, and the math underneath. All of them read the
same state: the set of currently sounding tones, each a pure function of
the timestamp (see [THEORY.md](THEORY.md)). Unless noted, analytical
widgets exclude fundamentals by default and use the 2²³ octave lift.

---

## Time Circles (year · moon · ¼ moon · day · hour · minute)

The primary display. A dot sweeps each circle once per cycle:

```
θ(t) = 360° · (t − t₀) / P        t₀ anchored to the epoch (UTC)
```

Inscribed {n/k} polygons fade in as the dot approaches a vertex the
winding path visits this rotation — cosine envelope, full opacity on the
vertex, gone beyond ±10.8°. Star polygons traverse their n vertices over
k rotations, so a heptagram {7/3} lights on one of every three passes of
a given vertex. Journal notes appear as markers snapped to their phase.

## Spectrum

The current chord as a vertical log-frequency rack. Each sounding tone:

```
f = (2ˢ / P) · (n / k)      bar length = amplitude
```

Per-timeframe lifts (HR 2²³ · DY 2²⁶ · QM 2²⁸ · MN/YR 2²⁹) put every
cycle in audible range without changing any pitch class. Labels show
timeframe × harmonic ("DY×7", "MN×7/3"), frequency, and whether the tone
is waxing, peaking, or waning (sign of the amplitude's derivative).

## Oscilloscope

The waveform you would hear: 30 ms of the composite signal

```
s(t) = Σᵢ Aᵢ sin(2π fᵢ t)
```

summed over all sounding tones at their current amplitudes.

## Phase Portrait

The signal plotted against its own derivative, (s, ds/dt), with the
derivative computed analytically (Σ Aᵢ ωᵢ cos ωᵢt). The topology is the
diagnostic: a **closed loop** means the active frequencies are in
small-integer ratios (a periodic chord); a **dense filled region** means
incommensurate content (quasi-periodic). Consonance becomes geometry.

## Cents Wheel

Pitch class as position on a circle:

```
angle = (1200 · log₂(f / 432)) mod 1200
```

The 12 labels sit at their just-intonation cents (not equal-tempered 30°
steps). Active tones appear as dots with a countdown to when each leaves
its fade window. Intervals between any two dots can be read directly as
arc length — this is the pure music-theory view.

## Dissonance Meters (Tenney + Entropy)

Two numbers grading all sounding pairs, amplitude-weighted:

```
Tenney:   HD = log₂(n·d) per pair, Gaussian-matched (σ = 30¢)
          to the 13-ratio JI lattice — interval complexity.
Entropy:  Shannon entropy of the lattice-identification
          distribution — interval ambiguity.
```

Meter full-scale is calibrated to the 99th percentile of a year-long
simulation; values beyond it show as spillover. Low Tenney + low entropy
together mark the clear, simple moments.

## Dissonance Graph

The same two totals as a time series over a selectable range — the
harmonic weather chart. Convergences appear as valleys (clarity), dense
clusters as ridges.

## Color Mapping

Pitch class as hue: `hue = log₂(f) mod 1` on a closed wheel
(R → Y → G → C → B → M → R). Visible light spans almost exactly one
octave, which makes the mapping unusually honest. One swatch per
timeframe (amplitude-weighted blend of its tones) plus the composite of
everything sounding.

## Harmonics Table

The static reference: every (timeframe × shape) tone with its period,
lifted frequency, nearest JI note at A = 432, and cents deviation. No date
dependency — this is the instrument's tuning chart.

## Chladni

The current tone set rendered as a vibrating plate. Each tone contributes
a standing-wave mode — m indexed by timeframe, n by harmonic number:

```
u(x, y) = Σᵢ Aᵢ sin(mᵢ π x) sin(nᵢ π y)
```

The drawn figure is the interference pattern (nodal structure) of the
whole moment — one emergent shape instead of a stack of components.

## Lissajous

Within each timeframe, every pair of sounding tones drawn as

```
x = sin(m θ),  y = sin(n θ)      m : n = the pair's frequency ratio
                                  in lowest terms (winding-aware)
```

Simple ratios give simple closed figures; the figure *is* the interval.

## Spectrogram

Harmonic activity scrolling into the past — which tones were sounding,
how strongly, over the trailing window. The system's recent history at a
glance.

## Convergence

The chord report. **NOW**: every recognized chord currently sounding —
patterns matched within ±25¢ per interval, all tones above amplitude 0.3,
at least three distinct pitch classes, with root named against A = 432
and time remaining. **UPCOMING**: the deterministic forecast — future
chord events with start, peak, and duration, computed by scanning the
schedule forward.

## Convergence Selector

The (harmonic × angle) alignment grid: background dots mark every
possible node position; cells light where geometry is currently active.
Per-timeframe or merged — the structural view of "what is lit right now"
that the chord report interprets musically.

## Calibration Result

A frozen statistical summary of a dissonance simulation run (percentiles
used to scale the meters). Multiple instances can pin different runs for
side-by-side comparison.

## Snapshot Timeline

The journal as a horizontal card strip. In Snapshot mode, clicking a card
pins **every** widget to that instant — the whole panel re-renders any
captured moment, because every view is a pure function of its timestamp.
This is the time-travel control.
