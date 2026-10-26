#!/usr/bin/env python3
"""받은 2D 그림(art/incoming/*.png)을 잘라 assets/ui/<이름>.png 로 만든다.

python3 tools/cut_ui_art.py   (Pillow 필요: pip install pillow)
- 한 장에 여러 개 그려진 그림을 아래 BOXES 의 대략적인 상자로 자르고, 투명한 가장자리를 깎는다.
- 흰 배경으로 온 그림은 가장자리부터 이어진 흰색을 투명으로 바꾼다 (지금 받은 그림은 이미 투명 배경).
- 가장 긴 변을 MAX_SIZE 로 줄인다. 새 그림을 받으면 BOXES 만 고치면 된다.
"""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "art", "incoming")
OUT = os.path.join(ROOT, "assets", "ui")
MAX_SIZE = 512

# 이름: (원본 파일, (왼쪽, 위, 오른쪽, 아래) 원본 픽셀 좌표의 대략적인 상자, None = 전체)
BOXES = {
    "tool_shower": ("10_tool_icons_revised.png", (0, 0, 627, 627)),
    "tool_bottle": ("10_tool_icons_revised.png", (627, 0, 1254, 627)),
    "tool_towel": ("10_tool_icons_revised.png", (0, 627, 627, 1254)),
    "tool_dryer": ("10_tool_icons_revised.png", (627, 627, 1254, 1254)),
    # 09 의 가로 카드(빈칸 4개)는 세로 6줄 요청 카드와 모양이 달라 쓰지 않는다 (ART_SLOTS 에 세로 카드 요청)
    "icon_bath": ("09_request_card_icons_check.png", (20, 449, 268, 699)),
    "icon_peach": ("09_request_card_icons_check.png", (767, 449, 1013, 699)),
    "icon_drop": ("09_request_card_icons_check.png", (1014, 449, 1260, 699)),
    "check": ("09_request_card_icons_check.png", (1210, 700, 1536, 1024)),
    "face_happy": ("11_puppy_face_icons_coin.png", (100, 10, 760, 500)),
    "face_neutral": ("11_puppy_face_icons_coin.png", (780, 10, 1440, 500)),
    "face_unhappy": ("11_puppy_face_icons_coin.png", (100, 510, 760, 1000)),
    "coin": ("11_puppy_face_icons_coin.png", (860, 500, 1360, 1010)),
    "sign": ("12_shop_sign.png", None),
}


def clear_white_border(im: Image.Image) -> Image.Image:
    """가장자리와 이어진 거의 흰 픽셀을 투명하게 (흰 배경으로 온 그림용)."""
    px = im.load()
    w, h = im.size
    seen = set()
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        r, g, b, a = px[x, y]
        if a > 0 and min(r, g, b) < 235:
            continue
        px[x, y] = (r, g, b, 0)
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return im


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, (source, box) in BOXES.items():
        im = Image.open(os.path.join(SRC, source)).convert("RGBA")
        if box:
            im = im.crop(box)
        if im.getpixel((0, 0))[3] > 0:
            im = clear_white_border(im)
        # 거의 투명한 가장자리(빛 번짐)는 깎는다
        bbox = im.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
        if bbox:
            im = im.crop(bbox)
        im.thumbnail((MAX_SIZE, MAX_SIZE), Image.LANCZOS)
        im.save(os.path.join(OUT, name + ".png"))
        print(name, im.size)


if __name__ == "__main__":
    main()
