from pathlib import Path

ROOT = Path("cemu-source/src/Cafe/OS/libs/snd_core")

AX_MIX = ROOT / "ax_mix.cpp"
AX_OUT = ROOT / "ax_out.cpp"


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly 1 match, found {count}")
    path.write_text(text.replace(old, new), encoding="utf-8")


# ---------------------------------------------------------------------------
# 1) AX per-voice low-pass correctness fix.
#    Patch 001 is applied separately by the workflow and owns AUX fallback.
# ---------------------------------------------------------------------------
text = AX_MIX.read_text(encoding="utf-8")
include_anchor = '#include "Cafe/OS/libs/snd_core/ax.h"'
if "#include <algorithm>" not in text:
    if include_anchor not in text:
        raise RuntimeError("ax_mix.cpp: include anchor not found")
    text = text.replace(include_anchor, "#include <algorithm>\n" + include_anchor, 1)
    AX_MIX.write_text(text, encoding="utf-8")

old_lpf = """\t\tfloat a0 = (float)_swapEndianS16(internalShadowCopy->lpf.a0) / 32767.0f;
\t\tfloat b0 = (float)_swapEndianS16(internalShadowCopy->lpf.b0) / 32767.0f;
\t\tfloat prevSample = (float)_swapEndianS16((sint16)internalShadowCopy->lpf.yn1) * 256.0f / 32767.0f;
\t\tfor (sint32 i = 0; i < sampleCount; i++)
\t\t{
\t\t\tsampleData[i] = a0 * sampleData[i] - b0 * prevSample;
\t\t\tprevSample = sampleData[i];
\t\t}
\t\tinternalShadowCopy->lpf.yn1 = (uint16)_swapEndianS16((sint16)(prevSample / 256.0f * 32767.0f));"""

new_lpf = """\t\tfloat a0 = (float)_swapEndianS16(internalShadowCopy->lpf.a0) / 32767.0f;
\t\tfloat b0 = (float)_swapEndianS16(internalShadowCopy->lpf.b0) / 32767.0f;
\t\tfloat prevSample = (float)_swapEndianS16((sint16)internalShadowCopy->lpf.yn1) * 256.0f;
\t\tfor (sint32 i = 0; i < sampleCount; i++)
\t\t{
\t\t\tsampleData[i] = a0 * sampleData[i] + b0 * prevSample;
\t\t\tprevSample = sampleData[i];
\t\t}
\t\tfloat yn1f = prevSample / 256.0f;
\t\tyn1f = std::min(std::max(yn1f, -32768.0f), 32767.0f);
\t\tinternalShadowCopy->lpf.yn1 = (uint16)_swapEndianS16((sint16)yn1f);"""
replace_once(AX_MIX, old_lpf, new_lpf, "AX per-voice LPF fix")


# ---------------------------------------------------------------------------
# 2) TV stereo fold-down.
#    Default = full fold-down. CEMU_LEGO_TV_FC_DIAG=1 = center-only.
# ---------------------------------------------------------------------------
text = AX_OUT.read_text(encoding="utf-8")
include_anchor = '#include "Cafe/OS/libs/snd_core/ax.h"'
if "#include <cstdlib>" not in text:
    if include_anchor not in text:
        raise RuntimeError("ax_out.cpp: include anchor not found")
    text = text.replace(
        include_anchor,
        "#include <cstdlib>\n#include <cstring>\n" + include_anchor,
        1,
    )
    AX_OUT.write_text(text, encoding="utf-8")

old_stereo = """\t\telse if (__AXMode[AX_DEV_TV] == AX_MODE_STEREO)
\t\t{
\t\t\tsint32* inputChannel0 = __AXTVBuffer48.GetPtr() + numSamples * 0;
\t\t\tsint32* inputChannel1 = __AXTVBuffer48.GetPtr() + numSamples * 1;
\t\t\tsint16* dmaOutputBuffer = __AXTVDMABuffers[frameIndex];
\t\t\tfor (sint32 i = 0; i < numSamples; i++)
\t\t\t{
\t\t\t\tdmaOutputBuffer[0] = _swapEndianS16((sint16)std::min(std::max(_swapEndianS32(*inputChannel0), -32768), 32767));
\t\t\t\tdmaOutputBuffer[1] = _swapEndianS16((sint16)std::min(std::max(_swapEndianS32(*inputChannel1), -32768), 32767));
\t\t\t\tdmaOutputBuffer += 2;
\t\t\t\t// next sample
\t\t\t\tinputChannel0++;
\t\t\t\tinputChannel1++;
\t\t\t}
\t\t\tAIInitDMA(__AXTVDMABuffers[frameIndex], numSamples * 2 * sizeof(sint16)); // 2ch output
\t\t}"""

new_stereo = """\t\telse if (__AXMode[AX_DEV_TV] == AX_MODE_STEREO)
\t\t{
\t\t\tsint32* ch0 = __AXTVBuffer48.GetPtr() + numSamples * 0;  // L
\t\t\tsint32* ch1 = __AXTVBuffer48.GetPtr() + numSamples * 1;  // R
\t\t\tsint32* ch2 = __AXTVBuffer48.GetPtr() + numSamples * 2;  // SL
\t\t\tsint32* ch3 = __AXTVBuffer48.GetPtr() + numSamples * 3;  // SR
\t\t\tsint32* ch4 = __AXTVBuffer48.GetPtr() + numSamples * 4;  // FC
\t\t\tsint16* dmaOutputBuffer = __AXTVDMABuffers[frameIndex];
\t\t\tstatic const bool centerOnlyDiag = []()
\t\t\t{
\t\t\t\tconst char* diag = std::getenv("CEMU_LEGO_TV_FC_DIAG");
\t\t\t\treturn diag && std::strcmp(diag, "1") == 0;
\t\t\t}();
\t\t\tfor (sint32 i = 0; i < numSamples; i++)
\t\t\t{
\t\t\t\tsint64 c = (sint64)_swapEndianS32(*ch4);
\t\t\t\tsint64 l;
\t\t\t\tsint64 r;
\t\t\t\tif (centerOnlyDiag)
\t\t\t\t{
\t\t\t\t\tl = c;
\t\t\t\t\tr = c;
\t\t\t\t}
\t\t\t\telse
\t\t\t\t{
\t\t\t\t\t// Equal-power (-3 dB) fold-down of center and matching surround.
\t\t\t\t\tsint64 cFold = (c * 181) >> 8;
\t\t\t\t\tsint64 slFold = ((sint64)_swapEndianS32(*ch2) * 181) >> 8;
\t\t\t\t\tsint64 srFold = ((sint64)_swapEndianS32(*ch3) * 181) >> 8;
\t\t\t\t\tl = (sint64)_swapEndianS32(*ch0) + cFold + slFold;
\t\t\t\t\tr = (sint64)_swapEndianS32(*ch1) + cFold + srFold;
\t\t\t\t}
\t\t\t\tdmaOutputBuffer[0] = _swapEndianS16((sint16)std::min<sint64>(std::max<sint64>(l, -32768), 32767));
\t\t\t\tdmaOutputBuffer[1] = _swapEndianS16((sint16)std::min<sint64>(std::max<sint64>(r, -32768), 32767));
\t\t\t\tdmaOutputBuffer += 2;
\t\t\t\tch0++; ch1++; ch2++; ch3++; ch4++;
\t\t\t}
\t\t\tAIInitDMA(__AXTVDMABuffers[frameIndex], numSamples * 2 * sizeof(sint16)); // 2ch output
\t\t}"""
replace_once(AX_OUT, old_stereo, new_stereo, "TV stereo fold-down")

print("Applied source-level LEGO audio fixes: LPF + TV stereo fold-down")
