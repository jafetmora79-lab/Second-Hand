"""Makes the wind-up sounds (assets/audio/*.wav), all synthesised here so they are ours:

  wind.wav        a key being wound: ratchet clicks against a spring
  wind_slip.wav   the same key on a broken spring: it turns freely, the clicks loose and hollow
  tune.wav        the music box's tune on a sound steel comb, slowing a little as the spring runs down
  tune_gap.wav    the same tune with two teeth missing from the comb: two notes never sound
  tune_tin.wav    the tune on a cheap stamped-tin movement: thin, buzzy, a little out of tune (a modern copy)
  car_run.wav     a tin car's clockwork running down: a buzzing whirr that slows

The tune is an original little waltz. Run: python tools/make_sounds.py  (needs numpy)
"""
import os, wave
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "audio")
SR = 22050
rng = np.random.default_rng(7)


def save(name, x):
    x = x / max(1e-6, np.max(np.abs(x))) * 0.8
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print(name, "%.2fs" % (len(x) / SR))


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def tine(f, dur, kind="steel"):
    """One plucked comb tooth: a fast attack and a ringing decay, with the comb's slightly inharmonic overtones."""
    t = np.arange(int(dur * SR)) / SR
    if kind == "steel":
        parts = [(1.0, 1.0, 1.6), (2.76, 0.35, 4.0), (5.4, 0.12, 7.0)]
        decay = 2.2
    else:                                                    ## tin: brighter, buzzier, short
        parts = [(1.0, 1.0, 5.0), (2.0, 0.6, 7.0), (3.0, 0.45, 9.0), (4.1, 0.3, 12.0), (6.3, 0.2, 14.0)]
        decay = 6.0
    x = np.zeros_like(t)
    for mult, amp, d in parts:
        x += amp * np.sin(2 * np.pi * f * mult * t) * np.exp(-t * d * (decay / 2.2))
    x *= np.minimum(1.0, t / 0.002)
    return x


# an original waltz in C: (beat, midi note); a melody note on most beats, a low note on each bar's first beat
MELODY = [
    (0, 76), (1, 79), (2, 84), (3, 83), (4, 79), (5, 76),
    (6, 77), (7, 81), (8, 84), (9, 83), (10, 81), (11, 79),
    (12, 76), (13, 79), (14, 84), (15, 86), (16, 84), (17, 79),
    (18, 81), (19, 79), (20, 77), (21, 74), (22, 76), (23, 72),
]
BASS = [(0, 60), (3, 55), (6, 62), (9, 55), (12, 60), (15, 57), (18, 53), (21, 55), (23, 48)]
GAP = {81, 84}                                               ## the two missing teeth: the tune's high notes drop out


def tune(kind="steel", gap=False):
    beat = 0.33 if kind == "steel" else 0.27
    notes = sorted(MELODY + BASS)
    # the spring runs down: each beat a touch longer than the last
    times, t = [], 0.0
    for b in range(25):
        times.append(t)
        t += beat * (1.0 + 0.022 * b)
    total = times[-1] + 2.5
    x = np.zeros(int(total * SR))
    for b, n in notes:
        if gap and n in GAP:
            continue
        f = midi(n)
        if kind != "steel":
            f *= 2 ** (rng.uniform(-0.35, 0.35) / 12)        ## stamped tin is never quite in tune
        s = tine(f, 2.3 if kind == "steel" else 0.6, kind)
        i = int(times[b] * SR)
        amp = 0.55 if n < 64 else 1.0
        x[i:i + len(s)] += s[:len(x) - i] * amp
    if kind != "steel":
        x = np.tanh(x * 2.5)                                  ## the rattle of a thin tin comb
    return x


def clicks(n, dur, loose=False):
    """A ratchet: `n` clicks over `dur` seconds against a spring (or, loose, turning freely)."""
    x = np.zeros(int((dur + 0.2) * SR))
    for k in range(n):
        tt = dur * (k / n) ** (0.9 if not loose else 1.0) + (rng.uniform(-0.02, 0.02) if loose else 0.0)
        i = int(max(0.0, tt) * SR)
        L = int(0.03 * SR)
        t = np.arange(L) / SR
        body = rng.normal(0, 1, L) * np.exp(-t * 300)
        ring = np.sin(2 * np.pi * (2400 if not loose else 1300) * t) * np.exp(-t * (140 if not loose else 260))
        c = body * 0.6 + ring * (0.5 if not loose else 0.2)
        c *= 1.0 if not loose else 0.45
        x[i:i + L] += c[:len(x) - i]
    if not loose:                                            ## the spring tightening: a faint rising creak under the clicks
        t = np.arange(len(x)) / SR
        x += 0.06 * np.sin(2 * np.pi * (180 + 120 * t / dur) * t) * np.minimum(1, t / dur)
    return x


def car_run(dur=3.6):
    t = np.arange(int(dur * SR)) / SR
    left = 1.0 - t / dur
    rate = 38 * np.sqrt(np.maximum(left, 0.0)) + 4            ## gear teeth a second, slowing as it runs down
    phase = np.cumsum(rate) / SR
    tick = (np.sin(2 * np.pi * phase) > 0.92).astype(float)
    tick = np.convolve(tick, np.exp(-np.arange(60) / 8.0), mode="same")
    whirr = np.sin(2 * np.pi * np.cumsum(rate * 9) / SR) * 0.35
    noise = rng.normal(0, 1, len(t))
    noise = np.convolve(noise, np.ones(6) / 6, mode="same") * 0.25
    x = (tick * 0.8 + whirr + noise) * np.sqrt(np.maximum(left, 0.0))
    return x * np.minimum(1, t / 0.03)


save("wind.wav", clicks(20, 1.35))
save("wind_slip.wav", clicks(9, 1.35, loose=True))
save("tune.wav", tune("steel"))
save("tune_gap.wav", tune("steel", gap=True))
save("tune_tin.wav", tune("tin"))
save("car_run.wav", car_run())
