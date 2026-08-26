# Cemu 2.6 Remote Toypad AudioFix

Private engineering repository for a Windows-first Cemu 2.6 LEGO Dimensions audio investigation, based on Harry's `Cemu-2.6-Remote-Toypad-Build`.

## Current experiment

Patch 001 is an **opt-in AX AUX return experiment**. It does not change master/music/voice gain globally. The build workflow fetches Harry's public Toypad source at build time, applies the pinned patch, and produces a Windows x64 Cemu executable as a GitHub Actions artifact.

### Test switch

Set:

`CEMU_LEGO_AUDIO_AUX_FALLBACK=1`

before launching the experimental build. Without that variable the experimental path is inactive.

## Source of truth

Upstream base: `harrysof/Cemu-2.6-Remote-Toypad-Build` (`main`).

This repository intentionally stores the patch and build automation rather than duplicating the entire upstream source tree.

## Engineering rule

Do not call an audio experiment a confirmed fix until it has been tested in LEGO Dimensions and the result is compared against the unmodified Harry 2.6 Toypad build.
