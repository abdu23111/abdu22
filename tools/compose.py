"""Procedurally composes Vesperdeep's original soundtrack.

Every track is synthesised from scratch (additive piano, music box, harp, choir pads,
bowed strings, drums) and rendered as a seamless loop into assets/music/*.ogg.

    pip install numpy scipy soundfile
    python tools/compose.py

Upload the resulting files to Roblox (Creator Hub or Studio's Asset Manager) and paste
the asset ids into src/shared/Config.luau -> Config.MUSIC.
"""

from __future__ import annotations

import os

import numpy as np
import soundfile as sf
from scipy.signal import butter, fftconvolve, lfilter

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "music")

NOTE_INDEX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
              "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def midi(name: str) -> int:
    """'D4' -> 62"""
    pitch, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + NOTE_INDEX[pitch]


def hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def chord(root: str, quality: str) -> list[int]:
    r = midi(root)
    shapes = {"min": [0, 3, 7], "maj": [0, 4, 7], "sus": [0, 5, 7], "min7": [0, 3, 7, 10],
              "maj7": [0, 4, 7, 11], "7": [0, 4, 7, 10], "add9": [0, 4, 7, 14], "madd9": [0, 3, 7, 14]}
    return [r + i for i in shapes[quality]]


def env(n: int, attack: float, release: float, sustain_curve: float = 0.0) -> np.ndarray:
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    r = np.clip((n / SR - t) / max(release, 1e-4), 0, 1)
    s = np.exp(-t * sustain_curve) if sustain_curve else 1.0
    return a * r * s


def lowpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    b, a = butter(order, cutoff / (SR / 2), btype="low")
    return lfilter(b, a, x)


# ---------------------------------------------------------------- instruments

def piano(f: float, dur: float, vel: float = 0.6) -> np.ndarray:
    n = int(SR * (dur + 1.8))
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k in range(1, 9):
        fk = f * k * np.sqrt(1 + 0.0004 * k * k)  # slight string inharmonicity
        if fk > SR / 2.2:
            break
        decay = 1.2 + k * 0.9 + f / 900
        out += np.sin(2 * np.pi * fk * t) * np.exp(-t * decay) / (k ** 1.35)
    hammer = np.random.default_rng(int(f)).normal(0, 1, n) * np.exp(-t * 90) * 0.02
    out = (out + hammer) * env(n, 0.004, 0.25)
    damp = np.clip((dur + 0.4 - t) / 0.4, 0, 1) * 0.85 + 0.15  # key release softens the tail
    return out * damp * vel * 0.35


def music_box(f: float, dur: float, vel: float = 0.5) -> np.ndarray:
    n = int(SR * (dur + 1.5))
    t = np.arange(n) / SR
    out = np.sin(2 * np.pi * f * t) * np.exp(-t * 2.2)
    out += 0.4 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 5)
    out += 0.15 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 9)
    return out * env(n, 0.002, 0.3) * vel * 0.3


def harp(f: float, dur: float, vel: float = 0.5) -> np.ndarray:
    # Karplus-Strong plucked string.
    n = int(SR * (dur + 2.0))
    period = max(2, int(SR / f))
    rng = np.random.default_rng(int(f * 10))
    buf = rng.uniform(-1, 1, period)
    buf = lowpass(buf, 5000, 1)
    blocks = []
    for _ in range(n // period + 1):
        blocks.append(buf)
        buf = 0.996 * 0.5 * (buf + np.roll(buf, -1))
    out = np.concatenate(blocks)[:n]
    return out * env(n, 0.002, 0.4) * vel * 0.35


def pad(freqs: list[float], dur: float, vel: float = 0.4, bright: float = 1500, vibrato: float = 0.0) -> np.ndarray:
    n = int(SR * (dur + 2.5))
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in freqs:
        for detune in (-0.12, 0.0, 0.11):
            fm = f * 2 ** (detune / 12)
            phase_mod = vibrato * np.sin(2 * np.pi * 5.1 * t) if vibrato else 0
            for k in range(1, 6):
                out += np.sin(2 * np.pi * fm * k * t + phase_mod * k) / (k ** 1.6)
    out = lowpass(out, bright, 2)
    out *= env(n, min(1.6, dur * 0.4), 2.0)
    return out * vel * 0.06 / max(1, len(freqs) ** 0.5)


def choir(freqs: list[float], dur: float, vel: float = 0.4) -> np.ndarray:
    # Airy "ooh" voices: pads with vibrato, a formant-ish lowpass and breath noise.
    n = int(SR * (dur + 2.5))
    base = pad(freqs, dur, vel, bright=1100, vibrato=0.35)
    breath = lowpass(np.random.default_rng(7).normal(0, 1, n), 900, 2) * env(n, 1.0, 2.0) * 0.004 * vel
    return base[:n] + breath


def strings(f: float, dur: float, vel: float = 0.5, bright: float = 2200) -> np.ndarray:
    n = int(SR * (dur + 0.8))
    t = np.arange(n) / SR
    vib = 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.4, 0, 1)
    phase = 2 * np.pi * np.cumsum(f * (1 + vib)) / SR
    saw = np.zeros(n)
    for k in range(1, 14):
        if f * k > SR / 2.2:
            break
        saw += np.sin(k * phase) / k
    out = lowpass(saw, bright, 2) * env(n, 0.08, 0.5)
    return out * vel * 0.18


def drum(kind: str, vel: float = 0.7) -> np.ndarray:
    rng = np.random.default_rng({"low": 1, "hit": 2, "tick": 3}[kind])
    if kind == "low":
        n = int(SR * 1.2)
        t = np.arange(n) / SR
        f = 55 * np.exp(-t * 3) + 38
        out = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 4)
        out += lowpass(rng.normal(0, 1, n), 400) * np.exp(-t * 20) * 0.3
    elif kind == "hit":
        n = int(SR * 0.6)
        t = np.arange(n) / SR
        out = lowpass(rng.normal(0, 1, n), 2500) * np.exp(-t * 14) * 0.6
        out += np.sin(2 * np.pi * 180 * t) * np.exp(-t * 20) * 0.5
    else:
        n = int(SR * 0.15)
        t = np.arange(n) / SR
        out = rng.normal(0, 1, n) * np.exp(-t * 60) * 0.25
    return out * vel * 0.5


# ---------------------------------------------------------------- mixing

class Track:
    def __init__(self, bpm: float, beats: int):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.length = int(SR * beats * self.beat)
        self.buf = np.zeros(self.length + SR * 6)

    def add(self, sound: np.ndarray, beat_pos: float, gain: float = 1.0):
        start = int(beat_pos * self.beat * SR)
        end = min(len(self.buf), start + len(sound))
        self.buf[start:end] += sound[: end - start] * gain

    def render(self, name: str, reverb_seconds: float = 3.0, wet: float = 0.35):
        dry = self.buf
        rng = np.random.default_rng(42)
        ir_n = int(SR * reverb_seconds)
        t = np.arange(ir_n) / SR
        ir = rng.normal(0, 1, ir_n) * np.exp(-t * 6.9 / reverb_seconds)
        ir = lowpass(ir, 6000, 1)
        ir /= np.sqrt(np.sum(ir ** 2))
        verb = fftconvolve(dry, ir)[: len(dry)]
        mix = dry * (1 - wet) + verb * wet * 1.6
        # Fold everything past the loop point back onto the start for a seamless loop.
        loop = mix[: self.length].copy()
        tail = mix[self.length:]
        loop[: len(tail)] += tail[: len(loop)]
        loop /= max(1e-6, np.max(np.abs(loop))) / 0.85
        os.makedirs(OUT, exist_ok=True)
        path = os.path.join(OUT, f"{name}.ogg")
        # libsndfile's Vorbis encoder can crash on one huge write, so stream it in blocks.
        with sf.SoundFile(path, "w", SR, 1, format="OGG", subtype="VORBIS") as f:
            data = loop.astype(np.float32)
            for i in range(0, len(data), SR):
                f.write(data[i:i + SR])
        print(f"wrote {path}  ({self.length / SR:.1f}s)")


def melody_line(rng, scale: list[int], chords: list[list[int]], beats_per_chord: int, start: int,
                rhythm: list[list[float]]):
    """Stepwise melody that leans on chord tones on strong beats."""
    notes = []
    current = start
    for bar, ch in enumerate(chords):
        pattern = rhythm[bar % len(rhythm)]
        pos = 0.0
        for i, length in enumerate(pattern):
            if length < 0:  # rest
                pos += -length
                continue
            candidates = [m for m in scale if abs(m - current) <= 4]
            if i == 0:
                tones = [m for m in candidates if (m - ch[0]) % 12 in [(c - ch[0]) % 12 for c in ch]]
                candidates = tones or candidates
            current = int(rng.choice(candidates)) if candidates else current
            notes.append((bar * beats_per_chord + pos, current, length))
            pos += length
    return notes


def scale_notes(root: str, intervals: list[int], lo: int, hi: int) -> list[int]:
    r = NOTE_INDEX[root]
    return [m for m in range(lo, hi + 1) if (m - r) % 12 in intervals]


MINOR = [0, 2, 3, 5, 7, 8, 10]
DORIAN = [0, 2, 3, 5, 7, 9, 10]
MAJOR = [0, 2, 4, 5, 7, 9, 11]


# ---------------------------------------------------------------- the pieces

def ashen_burrows():
    """Lonely, sparse piano over a low drone. D minor, 60 bpm."""
    rng = np.random.default_rng(11)
    prog = [("D3", "min"), ("Bb2", "maj7"), ("F3", "maj"), ("A2", "sus"),
            ("D3", "min"), ("G2", "min7"), ("Bb2", "maj"), ("A2", "maj")] * 2
    tr = Track(60, 4 * len(prog))
    chords = [chord(r, q) for r, q in prog]
    for i, ch in enumerate(chords):
        tr.add(pad([hz(m) for m in ch], 4.2, 0.5, bright=900), i * 4)
        tr.add(piano(hz(ch[0] - 12), 3.5, 0.5), i * 4)
        for j, m in enumerate(ch[:3]):
            tr.add(piano(hz(m + 12), 1.2, 0.25), i * 4 + 1 + j * 0.5)
    tr.add(pad([hz(midi("D2"))], len(prog) * 4 - 2, 0.6, bright=300), 0)
    scale = scale_notes("D", MINOR, midi("A4"), midi("F5") + 5)
    rhythm = [[2, 1, -1], [-1, 1, 2], [3, -1], [1, 1, 2]]
    for pos, m, length in melody_line(rng, scale, chords[8:], 4, midi("D5"), rhythm):
        tr.add(piano(hz(m), length, 0.55), 32 + pos)
    tr.render("burrows", 3.5, 0.42)


def mothlight_ruins():
    """A faded waltz: music box and cello. C minor, 3/4 at 84 bpm."""
    rng = np.random.default_rng(23)
    prog = [("C3", "min"), ("Ab2", "maj"), ("Eb3", "maj"), ("G2", "7"),
            ("F2", "min"), ("C3", "min"), ("D3", "sus"), ("G2", "maj")] * 2
    tr = Track(84, 3 * len(prog))
    chords = [chord(r, q) for r, q in prog]
    for i, ch in enumerate(chords):
        b = i * 3
        tr.add(strings(hz(ch[0] - 12), 2.8, 0.55, bright=900), b)
        tr.add(music_box(hz(ch[1] + 12), 0.8, 0.25), b + 1)
        tr.add(music_box(hz(ch[2] + 12), 0.8, 0.25), b + 2)
    scale = scale_notes("C", MINOR, midi("G4"), midi("C6"))
    rhythm = [[1.5, 0.5, 1], [3], [1, 1, 1], [2, -1]]
    for pos, m, length in melody_line(rng, scale, chords, 3, midi("Eb5"), rhythm):
        tr.add(music_box(hz(m + 12), length, 0.45), pos)
    for pos, m, length in melody_line(np.random.default_rng(5), scale_notes("C", MINOR, midi("C4"), midi("G4")),
                                      chords[8:], 3, midi("Eb4"), [[3], [2, 1]]):
        tr.add(strings(hz(m), length, 0.35, bright=1400), 24 + pos)
    tr.render("ruins", 3.0, 0.4)


def verdant_hush():
    """Gentle harp arpeggios and a breathy lead. E dorian, 72 bpm."""
    rng = np.random.default_rng(37)
    prog = [("E3", "min7"), ("A2", "maj"), ("E3", "min"), ("D3", "maj"),
            ("C3", "maj7"), ("D3", "maj"), ("E3", "min"), ("B2", "sus")] * 2
    tr = Track(72, 4 * len(prog))
    chords = [chord(r, q) for r, q in prog]
    for i, ch in enumerate(chords):
        tr.add(pad([hz(m) for m in ch], 4.2, 0.35, bright=1200), i * 4)
        arp = ch[:3] + [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[0] + 24, ch[2] + 12]
        for j, m in enumerate(arp):
            tr.add(harp(hz(m), 0.9, 0.3), i * 4 + j * 0.5)
    scale = scale_notes("E", DORIAN, midi("B4"), midi("A5"))
    rhythm = [[3, 1], [2, 2], [4], [1, 1, 2]]
    for pos, m, length in melody_line(rng, scale, chords[4:12], 4, midi("E5"), rhythm):
        tr.add(choir([hz(m)], length * 60 / 72, 0.9), 16 + pos)
    tr.render("forest", 3.2, 0.45)


def sanctum():
    """Distant choir and temple bells. A minor, 54 bpm."""
    rng = np.random.default_rng(41)
    prog = [("A2", "min"), ("F2", "maj"), ("C3", "maj"), ("G2", "maj"),
            ("A2", "min"), ("D3", "min"), ("F2", "maj7"), ("E2", "maj")] * 2
    tr = Track(54, 4 * len(prog))
    chords = [chord(r, q) for r, q in prog]
    for i, ch in enumerate(chords):
        tr.add(choir([hz(m + 12) for m in ch], 4.6, 0.8), i * 4)
        tr.add(strings(hz(ch[0] - 12), 4.2, 0.4, bright=600), i * 4)
        if i % 2 == 0:
            tr.add(music_box(hz(ch[0] + 24), 3, 0.35), i * 4)
    scale = scale_notes("A", MINOR, midi("E5"), midi("E6"))
    rhythm = [[4], [2, 2], [3, 1], [-2, 2]]
    for pos, m, length in melody_line(rng, scale, chords[8:], 4, midi("A5"), rhythm):
        tr.add(music_box(hz(m), length, 0.35), 32 + pos)
        tr.add(choir([hz(m - 12)], length * 60 / 54, 0.5), 32 + pos)
    tr.render("temple", 4.5, 0.5)


def boss_theme():
    """Driving strings and drums. D minor, 132 bpm."""
    prog = [("D2", "min"), ("D2", "min"), ("Bb1", "maj"), ("C2", "maj"),
            ("D2", "min"), ("F2", "maj"), ("G2", "min"), ("A1", "maj")] * 2
    tr = Track(132, 4 * len(prog))
    chords = [chord(r, q) for r, q in prog]
    for i, ch in enumerate(chords):
        b = i * 4
        for s in range(8):
            accent = 0.8 if s % 4 == 0 else 0.5
            tr.add(strings(hz(ch[0]), 0.2, accent, bright=1800), b + s * 0.5)
            tr.add(strings(hz(ch[0] + 12), 0.2, accent * 0.5, bright=2400), b + s * 0.5)
        tr.add(drum("low", 0.9), b)
        tr.add(drum("low", 0.6), b + 2.5)
        tr.add(drum("hit", 0.7), b + 1)
        tr.add(drum("hit", 0.7), b + 3)
        for s in range(8):
            tr.add(drum("tick", 0.4 + 0.2 * (s % 2 == 0)), b + s * 0.5)
        tr.add(pad([hz(m + 12) for m in ch], 1.8, 0.5, bright=2200), b)
        if i >= 8:
            top = ch[2] + 24 if i % 2 else ch[1] + 24
            tr.add(strings(hz(top), 1.6, 0.5, bright=3000), b)
            tr.add(strings(hz(top - 2 if i % 2 else top + 1), 1.6, 0.45, bright=3000), b + 2)
    tr.render("boss", 1.6, 0.25)


def ending_theme():
    """Warm resolution: piano and strings in D major, 66 bpm."""
    rng = np.random.default_rng(99)
    prog = [("D3", "maj"), ("A2", "maj"), ("B2", "min"), ("G2", "maj"),
            ("D3", "maj"), ("A2", "sus"), ("G2", "add9"), ("A2", "maj"),
            ("B2", "min"), ("G2", "maj7"), ("E2", "min"), ("A2", "7"),
            ("D3", "add9"), ("G2", "maj"), ("A2", "sus"), ("D3", "maj")]
    tr = Track(66, 4 * len(prog))
    chords = [chord(r, q) for r, q in prog]
    for i, ch in enumerate(chords):
        tr.add(strings(hz(ch[0] - 12), 4.2, 0.45, bright=800), i * 4)
        tr.add(pad([hz(m) for m in ch], 4.2, 0.35, bright=1400), i * 4)
        for j, m in enumerate([ch[0], ch[2], ch[1] + 12, ch[2]]):
            tr.add(piano(hz(m), 1.0, 0.3), i * 4 + j)
    scale = scale_notes("D", MAJOR, midi("F#4"), midi("A5"))
    rhythm = [[2, 2], [3, 1], [1, 1, 2], [4]]
    for pos, m, length in melody_line(rng, scale, chords, 4, midi("F#5"), rhythm):
        tr.add(piano(hz(m), length, 0.6), pos)
    tr.render("ending", 3.5, 0.45)


if __name__ == "__main__":
    ashen_burrows()
    mothlight_ruins()
    verdant_hush()
    sanctum()
    boss_theme()
    ending_theme()
