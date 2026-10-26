#!/usr/bin/env python3
"""임시 효과음 7개를 코드로 만든다 (외부 소리 파일을 쓰지 않으므로 라이선스 문제 없음, 우리가 만든 것).

python3 tools/make_sfx.py  → assets/sfx/*.wav (22050 Hz, 16비트 모노)
진짜 효과음을 받으면 같은 파일 이름으로 바꿔 넣으면 된다.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
random.seed(7)


def env(i, n, attack=0.01, release=0.3):
    t = i / RATE
    dur = n / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, (dur - t) / release) if release > 0 else 1.0
    return max(0.0, a * r)


def tone(dur, f0, f1=None, vol=0.5, wave_fn=math.sin, attack=0.005, release=0.1, noise=0.0):
    n = int(dur * RATE)
    f1 = f0 if f1 is None else f1
    out, phase = [], 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n)
        phase += 2 * math.pi * f / RATE
        s = wave_fn(phase) * (1 - noise) + (random.uniform(-1, 1) * noise)
        out.append(s * vol * env(i, n, attack, release))
    return out


def silence(dur):
    return [0.0] * int(dur * RATE)


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))


def square(p):
    return 1.0 if math.sin(p) >= 0 else -1.0


# 철퍽: 진흙 손님이 들어올 때 (낮은 잡음 퍽)
save("splat", tone(0.22, 180, 60, vol=0.7, noise=0.6, release=0.15))
# 뽀글 → 펑: 욕조 거품 (짧은 방울 여러 개 + 마지막 펑)
bubbles = []
for k in range(6):
    bubbles += tone(0.06, 500 + k * 90, 900 + k * 90, vol=0.35, release=0.03) + silence(0.03)
save("bubble_pop", bubbles + tone(0.12, 900, 120, vol=0.7, noise=0.5, release=0.08))
# 뚝뚝: 젖은 손님 물방울
drip = tone(0.08, 1400, 500, vol=0.45, release=0.05)
save("drip", drip + silence(0.12) + drip)
# 뽀옹: 털이 부풀 때 (올라가는 소리)
save("poof", tone(0.35, 220, 880, vol=0.5, release=0.12))
# 띵: 완료
save("ding", mix(tone(0.6, 1320, vol=0.45, release=0.5), tone(0.6, 1980, vol=0.18, release=0.45)))
# 흥: 화나서 나감 (내려가는 콧소리)
save("huff", tone(0.4, 420, 180, vol=0.45, wave_fn=square, noise=0.25, release=0.15))
# 미끄러짐: 휘익 (잡음 + 높이 변화)
save("slip", tone(0.45, 900, 300, vol=0.35, noise=0.7, attack=0.03, release=0.2))
print("만듦:", sorted(os.listdir(OUT)))
