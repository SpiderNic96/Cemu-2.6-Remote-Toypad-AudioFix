# Live AX Audio Capture

This directory is for runtime forensics, not emulator compilation.

## Goal

Capture Cemu's existing `log.txt` while LEGO Dimensions is running and preserve a compact timeline of relevant AX/audio events plus human-labelled gameplay phases.

## Important limitation

GitHub Actions cannot see or control the Cemu process running on a local Windows PC. The local capture script therefore runs beside Cemu on Windows, reads the local Cemu log, and produces a small evidence bundle for analysis.

## Cemu logging

Cemu has a `SoundAPI` log category for audio-related APIs. Cemu writes a `log.txt`; portable installs keep data beside the executable, while current Windows installs use Cemu's user data location. The capture script auto-detects common locations and also accepts an explicit path.

## Capture sequence

1. Run the existing diagnostic Cemu build with SoundAPI logging enabled.
2. Start `tools/capture-ax-session.ps1` in another PowerShell window.
3. Reproduce one short sequence at a time:
   - gameplay dialogue that is quiet
   - gameplay SFX that is quiet
   - normal gameplay music
   - a cutscene dialogue sample that is normal
4. In the second PowerShell window, use `tools/mark-ax-phase.ps1` before each sample, for example:
   `powershell -ExecutionPolicy Bypass -File .\tools\mark-ax-phase.ps1 gameplay-dialogue`
5. Stop the capture with Ctrl+C.
6. Zip the generated `ax-session` folder and provide it for analysis.

The capture output is intended to let us correlate the human-labelled event with AX calls instead of guessing from an unlabelled log.
