# Chord Ghost

A [MuseScore 3](https://musescore.org/) plugin that turns the score editor into a chord-analysis and songwriting sidekick. It builds chords/voicings interactively, and — when pointed at a selection in an open score — reads the notes, labels each measure with a Roman-numeral chord, detects cadences, guesses the harmonic "mood," and suggests likely next chords.

## Language / Tech

- **QML** (Qt Modeling Language) with `QtQuick`, `QtQuick.Controls`, and `QtQuick.Layouts` — the UI/scripting language MuseScore 3 plugins are written in.
- Targets the **MuseScore 3 Plugin API** (`import MuseScore 3.0`). It is **not** compatible with MuseScore 4's plugin API without porting.
- Single-file plugin, no build step and no external dependencies — everything (UI, music theory logic, and staff rendering) lives in `ChordGhost.qml`.
- Custom `Canvas`-based staff renderer (treble + bass clef) draws note heads, ledger lines, and inversion voicings by hand — it doesn't rely on MuseScore's own engraving for the analysis panel.

## What it does

**Chord builder (left panel)**
- Pick a root note (C–B), accidental (♭/♮/♯), and quality — triads, 7ths, 6ths, 9ths, sus chords, altered dominants (b5/#5/b9/#9), 11ths, 13ths, and power chords.
- Choose a voicing: root position, 1st/2nd/3rd inversion, open, or close.
- The staff view (center) renders the chord across grand staff, plus a side-by-side comparison of all inversions with figured bass (6, 6/4, 7, 6/5, 4/3, 2).

**Key & scale context**
- Key signature selector (7 flats → 7 sharps) with major/minor toggle.
- A diatonic degree bar (I–VII / i–VII) for one-click access to every chord in the current key.

**Score analysis (right panel, via the "Analyze" button)**
- Reads the current selection from the open MuseScore score, detects the chord in each measure (best-fit match against ~25 chord qualities), and labels it with a Roman numeral.
- Auto-detects major vs. relative-minor mode from the chord roots present.
- **Cadence detection**: flags Authentic (V→I), Plagal (IV→I), Deceptive (V→vi), Half (→V), and full ii/IV→V→I progressions in the analyzed sequence.
- **Mood detection**: scores the sequence against 8 harmonic "mood" fingerprints (Luminoso, Melancólico, Tensión, Épico, Onírico, Oscuro, Nostálgico, Triunfante) based on major/minor/diminished chord density.
- **Next-chord suggestions**: given the last detected chord, ranks likely next scale-degree chords using a weighted common-practice transition table (e.g. V favors I strongly, ii favors V, etc.).
- **Reference panel**: a static cheat-sheet of 10 named cadence/progression patterns (Authentic, Plagal, Andalusian, Royal Road, Axis progression, etc.) for quick lookup.

## File

- `ChordGhost.qml` — the complete plugin (UI, music theory tables, chord-detection/scoring logic, and canvas rendering).

## Installation

1. Locate your MuseScore 3 plugins folder:
   - Windows: `Documents\MuseScore3\Plugins`
   - macOS: `~/Documents/MuseScore3/Plugins`
   - Linux: `~/Documents/MuseScore3/Plugins`
2. Copy `ChordGhost.qml` into that folder (subfolder is fine).
3. In MuseScore: **Plugins → Plugin Manager**, enable "Chord Ghost", then restart MuseScore if prompted.
4. Open a score, optionally select a range of measures, then run **Plugins → Chord Ghost**.
5. Click **ANALYZE** to read the current selection into the sequence/cadence/mood/suggestion panels.

## Status

Personal/experimental project (currently at internal version 5.4.2). Chord and cadence detection are heuristic (best-fit scoring), not a full music-theory engine — expect occasional misreads on ambiguous or chromatic passages.
