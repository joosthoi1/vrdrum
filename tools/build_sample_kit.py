#!/usr/bin/env python3
"""Builds assets/kits/rusty from Karoryfer's CC0 "Big Rusty Drums".

Source: https://github.com/sfzinstruments/karoryfer.big-rusty-drums (CC0 1.0)

For each articulation the game uses, this script:
  - mixes the multi-mic recordings down to mono using the kit author's
    default mic balance from Programs/default/01-full.sfz,
  - keeps an even spread of velocity layers and a few round-robin takes,
  - trims leading silence (it would add latency) and fades long tails,
  - peak-normalises each piece as a whole, so relative levels between
    velocity layers and between zones (ride bow vs edge, closed vs open
    hi-hat) are preserved,
  - balances pieces against each other by the short-term loudness of their
    main articulation's loudest layer,
  - writes 16-bit mono WAVs plus kit.json, which maps articulations to
    layers and gives each piece's articulations a loudness trim.

Usage:
  git clone --depth 1 https://github.com/sfzinstruments/karoryfer.big-rusty-drums
  pip install soundfile numpy
  python3 tools/build_sample_kit.py path/to/karoryfer.big-rusty-drums
"""

import json
import re
import shutil
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

OUT = Path(__file__).resolve().parent.parent / "assets" / "kits" / "rusty"

# articulation -> (sample folder, {mic: gain}, layers kept, round robins kept, max seconds)
# Mic gains are the sfz default CC levels / 127.
KICK = {"kick": 100 / 127, "oh": 30 / 127}
SNARE = {"btm": 100 / 127, "top": 40 / 127, "oh": 60 / 127}
TOM = {"cl": 100 / 127, "oh": 70 / 127}
HAT = {"cl": 70 / 127, "oh": 70 / 127}
CYMBAL = {"cl": 40 / 127, "oh": 100 / 127}

ARTICULATIONS = {
    "kick/head": ("kick_24/kick", KICK, 6, 3, 1.2),
    "snare/head": ("snare_14/center", SNARE, 6, 3, 1.2),
    "snare/rim": ("snare_14/rimshot", SNARE, 4, 3, 1.2),
    "tom1/head": ("tom_14/center", TOM, 5, 3, 1.5),
    "tom2/head": ("tom_15/center", TOM, 5, 3, 1.6),
    "tom3/head": ("tom_18/center", TOM, 5, 3, 1.8),
    "hihat/closed": ("hihat_14/cl", HAT, 5, 3, 0.8),
    "hihat/half": ("hihat_14/ho", HAT, 4, 2, 1.8),
    "hihat/open": ("hihat_14/open", HAT, 4, 2, 2.5),
    "hihat/pedal": ("hihat_14/chik", HAT, 3, 3, 0.8),
    "crash/bow": ("crash_17/cr", CYMBAL, 4, 2, 3.5),
    # crash/edge reuses the crash/bow files, see ALIASES.
    "ride/bow": ("ride_22/rd", CYMBAL, 5, 2, 3.0),
    "ride/bell": ("ride_22/bl", CYMBAL, 4, 2, 3.5),
    "ride/edge": ("ride_22/ed", CYMBAL, 4, 2, 3.5),
}

# Articulations that share another's samples (the kit has one crash articulation).
ALIASES = {"crash/edge": "crash/bow"}

# The articulation each piece is balanced by.
MAIN = {"kick": "kick/head", "snare": "snare/head", "tom1": "tom1/head", "tom2": "tom2/head",
        "tom3": "tom3/head", "hihat": "hihat/closed", "crash": "crash/bow", "ride": "ride/bow"}

# Loudness targets relative to the drums (dB): cymbals sit a little lower in
# a natural kit balance.
LOUDNESS_OFFSET = {"hihat": -3.0, "crash": -4.0, "ride": -5.0}

TAIL_FLOOR_DB = -70.0   # trim tails below this, relative to the piece's peak
ONSET_DB = -45.0        # onset: first sample above this, relative to the take's own peak
PRE_ROLL = 0.0005       # seconds kept before the onset
FADE_CAPPED = 0.4       # fade-out when a tail is cut at the length cap
FADE_NATURAL = 0.03     # fade-out when a sound has already decayed to the floor


def layer_files(folder: Path, mic: str) -> dict:
    """{velocity layer: {round robin: path}} for one mic."""
    out = {}
    for f in (folder / mic).glob("*.flac"):
        m = re.search(r"vl(\d+)_rr(\d+)", f.name)
        out.setdefault(int(m.group(1)), {})[int(m.group(2))] = f
    return out


def to_mono(x: np.ndarray) -> np.ndarray:
    return x if x.ndim == 1 else x.mean(axis=1)


def mix_take(folder: Path, mics: dict, layer: int, rr: int) -> tuple:
    mixed = None
    rate = None
    for mic, gain in mics.items():
        data, rate = sf.read(layer_files(folder, mic)[layer][rr], dtype="float64")
        data = to_mono(data) * gain
        if mixed is None:
            mixed = data
        else:
            n = max(len(mixed), len(data))
            mixed = np.pad(mixed, (0, n - len(mixed))) + np.pad(data, (0, n - len(data)))
    return mixed, rate


def envelope(x: np.ndarray, rate: int) -> np.ndarray:
    win = max(1, int(0.01 * rate))
    return np.sqrt(np.convolve(x * x, np.ones(win) / win, mode="same"))


def trim(x: np.ndarray, rate: int, floor: float, max_seconds: float) -> np.ndarray:
    peak = np.max(np.abs(x))
    onset = np.argmax(np.abs(x) > peak * 10 ** (ONSET_DB / 20))
    x = x[max(0, onset - int(PRE_ROLL * rate)):]
    env = envelope(x, rate)
    above = np.nonzero(env > floor)[0]
    natural_end = min(len(x), (above[-1] + 1) if len(above) else len(x))
    cap = int(max_seconds * rate)
    capped = cap < natural_end
    end = cap if capped else natural_end
    x = x[:end].copy()
    fade = min(int((FADE_CAPPED if capped else FADE_NATURAL) * rate), end // 3)
    if fade > 0:
        x[-fade:] *= 0.5 * (1 + np.cos(np.linspace(0, np.pi, fade)))
    return x


def pick(values: list, count: int) -> list:
    """An even spread of `count` items from sorted `values`, always keeping both ends."""
    if count >= len(values):
        return values
    idx = np.round(np.linspace(0, len(values) - 1, count)).astype(int)
    return [values[i] for i in idx]


def short_term_rms(x: np.ndarray, rate: int) -> float:
    seg = x[: int(0.3 * rate)]
    return float(np.sqrt(np.mean(seg * seg)))


def main(source: Path) -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    manifest = {"source": "Karoryfer Samples - Big Rusty Drums (CC0 1.0)",
                "url": "https://github.com/sfzinstruments/karoryfer.big-rusty-drums",
                "articulations": {}}
    rendered = {}
    takes_by_piece = {}
    for articulation, (folder, mics, n_layers, n_rr, max_s) in ARTICULATIONS.items():
        folder = source / "Samples" / folder
        files = layer_files(folder, next(iter(mics)))
        layers = pick(sorted(files), n_layers)
        takes = {}
        for layer in layers:
            for rr in pick(sorted(files[layer]), n_rr):
                takes[(layer, rr)] = mix_take(folder, mics, layer, rr)
        rendered[articulation] = (layers, takes, max_s)
        takes_by_piece.setdefault(articulation.split("/")[0], []).extend(x for x, _ in takes.values())

    # One scale per piece: its loudest take across all articulations at -1 dBFS.
    piece_peak = {p: max(np.max(np.abs(x)) for x in xs) for p, xs in takes_by_piece.items()}
    loudness = {}
    for articulation, (layers, takes, max_s) in rendered.items():
        piece = articulation.split("/")[0]
        rate = next(iter(takes.values()))[1]
        floor = piece_peak[piece] * 10 ** (TAIL_FLOOR_DB / 20)
        scale = 10 ** (-1 / 20) / piece_peak[piece]
        out = {key: trim(x, rate, floor, max_s) * scale for key, (x, _) in takes.items()}
        rendered[articulation] = (layers, out, rate)
        if MAIN[piece] == articulation:
            loudest = [x for (layer, _), x in out.items() if layer == layers[-1]]
            loudness[piece] = np.mean([short_term_rms(x, rate) for x in loudest])

    drums = [v for p, v in loudness.items() if p not in LOUDNESS_OFFSET]
    reference = 20 * np.log10(min(drums))
    piece_gain = {p: min(0.0, reference + LOUDNESS_OFFSET.get(p, 0.0) - 20 * np.log10(v))
                  for p, v in loudness.items()}
    total = 0
    for articulation, (layers, out, rate) in rendered.items():
        gain_db = piece_gain[articulation.split("/")[0]]
        entry = {"gain_db": round(gain_db, 2), "layers": []}
        for i, layer in enumerate(layers):
            paths = []
            for (lay, rr), x in sorted(out.items()):
                if lay != layer:
                    continue
                rel = f"{articulation.replace('/', '_')}_v{i + 1}_rr{rr}.wav"
                sf.write(OUT / rel, x, rate, subtype="PCM_16")
                total += (OUT / rel).stat().st_size
                paths.append(rel)
            entry["layers"].append(paths)
        manifest["articulations"][articulation] = entry
        print(f"{articulation:14} layers={layers} gain={gain_db:+.1f} dB")
    for alias, original in ALIASES.items():
        manifest["articulations"][alias] = manifest["articulations"][original]
    (OUT / "kit.json").write_text(json.dumps(manifest, indent=1) + "\n")
    shutil.copy(source / "LICENSE", OUT / "LICENSE")
    print(f"total {total / 1e6:.1f} MB")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
