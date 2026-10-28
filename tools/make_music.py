#!/usr/bin/env python3
"""멍냥 목욕탕 음악을 코드로 합성한다 (외부 파일·비용 없음, 우리가 만든 것이라 CC0 로 둠).

- assets/music/bgm_shop.wav     영업 중 배경음악 (16마디 · 112 BPM = 약 34.3초, 이어 붙여 반복되게 마디 단위로 끝남)
- assets/music/settle_jingle.wav 정산 화면 짧은 곡 (약 3초)

같은 시드로 늘 같은 소리가 나온다. 곡을 바꾸려면 아래 CHORDS·MELODY_SEED 를 고치고 다시 실행:
    python3 tools/make_music.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "music")
BPM = 112
BEAT = 60.0 / BPM
MELODY_SEED = 11

# 다장조, 한 마디에 화음 하나: C - Am - F - G (4번 되풀이 = 16마디)
CHORDS = [[48, 52, 55], [45, 48, 52], [41, 45, 48], [43, 47, 50]] * 4
# 멜로디는 펜타토닉 (C D E G A) 안에서만
PENTA = [60, 62, 64, 67, 69, 72, 74, 76]


def freq(note):
    return 440.0 * 2 ** ((note - 69) / 12.0)


def add_tone(buf, start, dur, note, vol, shape="tri", attack=0.01, release=0.08):
    f = freq(note)
    i0 = int(start * RATE)
    n = int(dur * RATE)
    for i in range(n):
        if i0 + i >= len(buf):
            break
        t = i / RATE
        phase = (f * t) % 1.0
        if shape == "tri":
            s = 4 * abs(phase - 0.5) - 1
        elif shape == "square":
            s = 0.6 if phase < 0.5 else -0.6
        else:
            s = math.sin(2 * math.pi * phase)
        env = min(1.0, t / attack) * min(1.0, (dur - t) / release) if dur > release else 1.0
        buf[i0 + i] += s * vol * max(env, 0.0)


def add_kick(buf, start, vol=0.5):
    i0 = int(start * RATE)
    n = int(0.15 * RATE)
    phase = 0.0
    for i in range(n):
        if i0 + i >= len(buf):
            break
        t = i / RATE
        f = 120 * (1 - t / 0.15) + 45
        phase += f / RATE
        buf[i0 + i] += math.sin(2 * math.pi * phase) * vol * (1 - t / 0.15)


def add_hat(buf, start, rng, vol=0.08):
    i0 = int(start * RATE)
    n = int(0.04 * RATE)
    for i in range(n):
        if i0 + i >= len(buf):
            break
        buf[i0 + i] += rng.uniform(-1, 1) * vol * (1 - i / n)


def save(name, buf):
    peak = max(1e-6, max(abs(x) for x in buf))
    gain = 0.7 / peak
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * gain)) * 32767)) for x in buf))


def bgm():
    rng = random.Random(MELODY_SEED)
    bar = BEAT * 4
    buf = [0.0] * int(bar * len(CHORDS) * RATE)
    step = 3  # 멜로디 위치 (PENTA 번호)
    for b, chord in enumerate(CHORDS):
        t0 = b * bar
        # 화음: 부드러운 사인 패드
        for note in chord:
            add_tone(buf, t0, bar, note + 12, 0.05, "sine", attack=0.05, release=0.1)
        # 베이스: 근음 / 5도 번갈아 4분음표
        for k in range(4):
            note = chord[0] - 12 if k % 2 == 0 else chord[2] - 12
            add_tone(buf, t0 + k * BEAT, BEAT * 0.9, note, 0.22, "tri")
        # 북: 1·3박 킥, 엇박 하이햇
        for k in range(4):
            if k % 2 == 0:
                add_kick(buf, t0 + k * BEAT)
            add_hat(buf, t0 + (k + 0.5) * BEAT, rng)
        # 멜로디: 8분음표, 가끔 쉼, 화음 음에 가까이
        for k in range(8):
            if rng.random() < 0.22:
                continue
            step = max(0, min(len(PENTA) - 1, step + rng.choice([-2, -1, -1, 0, 1, 1, 2])))
            length = BEAT * (1.0 if rng.random() < 0.25 else 0.5)
            add_tone(buf, t0 + k * BEAT * 0.5, length * 0.9, PENTA[step], 0.16, "square", release=0.05)
    return buf


def jingle():
    buf = [0.0] * int(3.2 * RATE)
    for i, note in enumerate([72, 76, 79, 84]):
        add_tone(buf, i * 0.16, 0.3, note, 0.25, "square")
    for note in [60, 64, 67, 72]:
        add_tone(buf, 0.7, 2.3, note, 0.12, "tri", release=1.2)
    add_tone(buf, 0.7, 2.3, 48, 0.2, "sine", release=1.2)
    return buf


if __name__ == "__main__":
    save("bgm_shop", bgm())
    save("settle_jingle", jingle())
    print("만듦:", sorted(os.listdir(OUT)))
