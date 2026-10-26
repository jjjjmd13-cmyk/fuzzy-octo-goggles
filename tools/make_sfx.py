#!/usr/bin/env python3
"""임시 효과음을 코드로 만든다 (외부 소리 파일을 쓰지 않으므로 라이선스 문제 없음, 우리가 만든 것).

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

# --- V3 (가게 시뮬레이터) 손맛 소리. shower·scrub·dryer 는 이어서 틀 수 있게 끝이 매끄러운 반복용.
def loop(samples):
    fade = int(0.02 * RATE)
    for i in range(fade):
        k = i / fade
        samples[i] *= k
        samples[-1 - i] *= k
    return samples


# 쏴아: 샤워기 (밝은 잡음, 반복)
save("shower", loop(tone(1.0, 3000, 3000, vol=0.35, noise=1.0, attack=0, release=0)))
# 뽀글뽀글: 문지르기 (작은 방울이 이어짐, 반복)
scrub = []
for k in range(10):
    scrub += tone(0.05, 700 + (k % 4) * 130, 1100 + (k % 3) * 120, vol=0.3, release=0.02) + silence(0.05)
save("scrub", loop(scrub))
# 뽀득: 헹구기 끝
save("squeak", tone(0.18, 1800, 2600, vol=0.35, wave_fn=square, release=0.08))
# 북북: 수건
save("towel", tone(0.25, 200, 160, vol=0.4, noise=0.85, release=0.1) + silence(0.05) + tone(0.25, 200, 160, vol=0.4, noise=0.85, release=0.1))
# 위잉: 드라이어 (낮은 웅웅 + 바람, 반복)
save("dryer", loop(mix(tone(1.0, 140, 140, vol=0.3, wave_fn=square, attack=0, release=0), tone(1.0, 2000, 2000, vol=0.15, noise=1.0, attack=0, release=0))))
# 짤랑: 동전
save("coin", mix(tone(0.25, 2400, vol=0.35, release=0.2), tone(0.3, 3200, vol=0.25, release=0.25)))
# 깨갱/펄쩍: 차가운 물 (높게 튀는 소리)
save("yelp", tone(0.2, 900, 1500, vol=0.45, release=0.1) + tone(0.15, 1400, 700, vol=0.4, release=0.1))
# 부르르: 몸 털기
save("shake", tone(0.6, 90, 70, vol=0.45, wave_fn=square, noise=0.4, release=0.2))

# --- V3 두 번째 반복: 단계마다 다른 손동작, 주인 손님
# 뿌직: 샴푸 병 짜기 (질척한 잡음이 올라감)
save("squirt", tone(0.35, 160, 420, vol=0.45, noise=0.55, attack=0.03, release=0.12))
# 촤아악: 바가지 물 쏟기 (밝은 잡음이 길게 줄어듦)
save("pour", tone(0.9, 1800, 700, vol=0.5, noise=0.95, attack=0.01, release=0.6))
# 꾹: 수건 누르기 (짧고 낮은 퍽)
save("press", tone(0.12, 140, 90, vol=0.55, noise=0.5, release=0.08))
# 짝짝: 주인 박수
clap = []
for k in range(3):
    clap += tone(0.05, 2500, 1500, vol=0.6, noise=0.9, release=0.04) + silence(0.13)
save("clap", clap)
# 휴: 주인 한숨 (숨소리가 내려감)
save("sigh", tone(0.7, 500, 220, vol=0.3, noise=0.85, attack=0.1, release=0.4))
# 낑낑: 강아지가 주인을 보며
whine = tone(0.18, 1100, 1500, vol=0.3, release=0.08)
save("whine", whine + silence(0.08) + tone(0.22, 1200, 900, vol=0.28, release=0.1))
# 멍!: 주인에게 달려감
save("bark", tone(0.16, 520, 380, vol=0.55, wave_fn=square, noise=0.3, attack=0.005, release=0.08))
print("만듦:", sorted(os.listdir(OUT)))
