#!/usr/bin/env python3
"""도구 소리를 코드로 만든다 (대표 요청 2026-11-11 ⑦, 사람 대표 의견 "삑삑 기계음 같고 시끄럽고 다 비슷하다").

- 사인·사각파 '삑' 없이 **잡음(노이즈)을 거른 소리**로: 물 쏴아 / 거품 뽀글 / 수건 문지름 / 드라이기 낮은 웅 / 빗 슥슥 / 가위 싹둑.
- 음량은 안내음(딩·딸랑·짤랑)보다 작게: 도구 소리 꼭대기 PEAK_DB 이하 (tests/game/test_tool_sfx.gd 가 확인).
- 시작·끝은 부드럽게 (한 번 소리는 감싸기, 이어지는 소리는 끝과 처음을 겹쳐 이음매 없이).
- 외부 소리 파일·유료 음원 없음 (우리가 만든 것). numpy 만 씀 (개발 도구, 게임에는 안 들어감).

python3 tools/make_tool_sfx.py  → assets/sfx/<이름>.wav (44100 Hz, 16비트 모노). 같은 씨앗이라 늘 같은 소리.
"""
import math
import os
import struct
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
rng = np.random.default_rng(20261111)


# --- 기본 재료

def white(seconds):
    return rng.uniform(-1.0, 1.0, int(seconds * RATE))


def wn(n):
    return rng.uniform(-1.0, 1.0, n)


def brown(seconds):
    x = np.cumsum(white(seconds) * 0.02)
    x -= np.convolve(x, np.ones(2001) / 2001, mode="same")  # 천천히 떠도는 것 빼기
    return x / (np.max(np.abs(x)) + 1e-9)


def biquad(x, kind, freq, q=0.707):
    """RBJ 쌍2차 거르개 (lowpass / highpass / bandpass)."""
    w = 2 * math.pi * freq / RATE
    alpha = math.sin(w) / (2 * q)
    cos = math.cos(w)
    if kind == "lowpass":
        b = [(1 - cos) / 2, 1 - cos, (1 - cos) / 2]
    elif kind == "highpass":
        b = [(1 + cos) / 2, -(1 + cos), (1 + cos) / 2]
    else:
        b = [alpha, 0.0, -alpha]
    a = [1 + alpha, -2 * cos, 1 - alpha]
    b = [v / a[0] for v in b]
    a1, a2 = a[1] / a[0], a[2] / a[0]
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        xi = x[i]
        yi = b[0] * xi + b[1] * x1 + b[2] * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, xi
        y2, y1 = y1, yi
        y[i] = yi
    return y


def band(x, low, high):
    return biquad(biquad(x, "highpass", low), "lowpass", high)


def envelope(n, attack, release, curve=1.0):
    t = np.arange(n) / RATE
    dur = n / RATE
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    r = np.clip((dur - t) / max(release, 1e-4), 0, 1)
    return (a * r) ** curve


def decay(n, seconds):
    return np.exp(-np.arange(n) / RATE / seconds)


def place(dest, sound, at):
    i = int(at * RATE)
    if i >= len(dest):
        return
    j = min(len(dest), i + len(sound))
    dest[i:j] += sound[: j - i]


def seamless(x, overlap=0.15):
    """이어지는 소리: 끝 overlap 초를 처음에 겹쳐 이음매 없이 (길이는 overlap 만큼 짧아짐)."""
    k = int(overlap * RATE)
    fade = np.linspace(0, 1, k)
    head = x[:k] * fade + x[-k:] * (1 - fade)
    return np.concatenate([head, x[k:-k]])


def normalize(x, peak_db):
    return x / (np.max(np.abs(x)) + 1e-9) * (10 ** (peak_db / 20))


def save(name, x):
    os.makedirs(OUT, exist_ok=True)
    data = np.clip(x, -1, 1)
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in data))


# --- 도구 소리 (꼭대기 dBFS: 안내음보다 작게, 이어지는 소리는 더 작게)
PEAK_DB = {"shower": -20, "scrub": -18, "foam": -17, "dryer": -21, "brush": -19, "towel": -18, "press": -18, "snip": -16, "squirt": -18, "bubble_pop": -20, "pour": -18}


def shower():
    """쏴아: 넓은 물 잡음 + 물방울이 톡톡 (2초, 이음매 없음)."""
    seconds = 2.15
    base = band(white(seconds), 350, 6500) + 0.5 * band(white(seconds), 2500, 9000)
    flutter = 1.0 + 0.12 * np.sin(2 * math.pi * 3.3 * np.arange(len(base)) / RATE + rng.uniform(0, 6))
    x = base * flutter
    for _ in range(int(seconds * 45)):
        n = int(rng.uniform(0.003, 0.008) * RATE)
        drop = band(wn(n), 1800, 5500) * decay(n, 0.002) * rng.uniform(0.4, 1.2)
        place(x, drop, rng.uniform(0, seconds))
    return seamless(x)


def foam(rate=55.0):
    """뽀글뽀글: 아주 작은 거품이 톡톡 터짐 (거품마다 높이가 달라 '삑' 이 아님) + 아래 깔리는 부드러운 잡음."""
    seconds = 2.15
    x = 0.15 * band(white(seconds), 200, 1500)
    for _ in range(int(seconds * rate)):
        n = int(rng.uniform(0.006, 0.02) * RATE)
        t = np.arange(n) / RATE
        f0 = rng.uniform(900, 3200)
        chirp = np.sin(2 * math.pi * f0 * t * (1 + 6 * t))  # 터지며 위로 미끄러짐 (아주 짧음)
        pop = chirp * decay(n, rng.uniform(0.002, 0.005)) * rng.uniform(0.2, 1.0)
        pop += band(wn(n), 1500, 6000) * decay(n, 0.0015) * 0.4
        place(x, pop, rng.uniform(0, seconds))
    return seamless(x)


def dryer():
    """웅: 낮게 울리는 바람 (잡음을 낮은 곳만 남김, 순수 음 없음) + 공기 쉬익."""
    seconds = 2.15
    hum = biquad(white(seconds), "bandpass", 115, 6.0) * 2.2 + biquad(white(seconds), "bandpass", 230, 5.0) * 0.9
    air = band(white(seconds), 300, 3500) * 0.45
    x = hum + air
    x *= 1.0 + 0.05 * np.sin(2 * math.pi * 1.7 * np.arange(len(x)) / RATE)
    return seamless(x)


def brush():
    """슥슥: 빗살이 털을 스치는 높은 잡음, 1.2초에 두 번 쓸기."""
    seconds = 1.35
    x = np.zeros(int(seconds * RATE))
    for start in (0.06, 0.66):
        n = int(0.42 * RATE)
        grain = 0.6 + 0.4 * rng.uniform(0, 1, n)  # 빗살이 걸리는 까슬함
        stroke = band(wn(n), 2200, 9000) * envelope(n, 0.06, 0.22, 1.5) * grain
        stroke += band(wn(n), 600, 1800) * envelope(n, 0.05, 0.25, 1.5) * 0.25
        place(x, stroke, start)
    return seamless(x, 0.1)


def towel():
    """수건 톡·문지름: 천이 스치는 둔한 쓱 (짧게)."""
    n = int(0.26 * RATE)
    x = band(white(0.26), 500, 2800) * envelope(n, 0.03, 0.18, 1.6)
    x += biquad(white(0.26), "lowpass", 250) * envelope(n, 0.005, 0.12) * 0.8
    return x


def press():
    """수건 꾹: 천을 눌러 짜는 쓱 + 물방울 두어 개."""
    n = int(0.45 * RATE)
    x = band(white(0.45), 300, 1800) * envelope(n, 0.04, 0.3, 1.4)
    for at in (0.22, 0.3, 0.37):
        m = int(0.01 * RATE)
        place(x, band(white(0.01), 1500, 4500) * decay(m, 0.003) * 0.6, at)
    return x


def snip():
    """싹둑: 날이 스치는 높은 '싹' + 날이 닫히는 짧은 '둑' (쇳소리는 좁게 거른 잡음)."""
    a = int(0.06 * RATE)
    shh = band(white(0.06), 3500, 11000) * envelope(a, 0.004, 0.05, 1.2)
    b = int(0.12 * RATE)
    click = band(white(0.12), 1500, 5000) * decay(b, 0.006)
    ring = biquad(white(0.12), "bandpass", 3300, 12.0) * decay(b, 0.025) * 1.2
    x = np.zeros(int(0.22 * RATE))
    place(x, shh, 0.0)
    place(x, click + ring, 0.055)
    return x


def squirt():
    """샴푸 짜기: 병이 눌리는 푹 + 거품이 뿌직."""
    n = int(0.35 * RATE)
    x = biquad(white(0.35), "lowpass", 900) * envelope(n, 0.01, 0.25, 1.5)
    for _ in range(8):
        m = int(rng.uniform(0.008, 0.02) * RATE)
        place(x, band(wn(m), 800, 3000) * decay(m, 0.004) * 0.5, rng.uniform(0.05, 0.25))
    return x


def bubble_pop():
    """뽁: 거품 하나 (아주 짧게 위로 미끄러지는 톡 + 잡음)."""
    n = int(0.05 * RATE)
    t = np.arange(n) / RATE
    x = np.sin(2 * math.pi * 1500 * t * (1 + 8 * t)) * decay(n, 0.006)
    x += band(white(0.05), 2000, 7000) * decay(n, 0.002) * 0.6
    return x


def pour():
    """바가지 물 쏟기: 콸콸 (잡음이 커졌다 작아짐 + 꿀렁)."""
    n = int(0.9 * RATE)
    x = band(white(0.9), 250, 3500) * envelope(n, 0.08, 0.5, 1.2)
    x *= 1.0 + 0.35 * np.sin(2 * math.pi * 9 * np.arange(n) / RATE)
    return x


SOUNDS = {
    "shower": shower, "scrub": lambda: foam(40.0), "foam": foam, "dryer": dryer, "brush": brush,
    "towel": towel, "press": press, "snip": snip, "squirt": squirt, "bubble_pop": bubble_pop, "pour": pour,
}

if __name__ == "__main__":
    for name, make in SOUNDS.items():
        save(name, normalize(make(), PEAK_DB[name]))
    print("만듦:", ", ".join(SOUNDS))
