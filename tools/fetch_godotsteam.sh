#!/usr/bin/env bash
# GodotSteam GDExtension 을 받아 addons/godotsteam/ 에 푼다 (저장소에는 넣지 않음).
#
#   tools/fetch_godotsteam.sh                    # Codeberg 릴리스에서 Godot 4.4 용 GDExtension 자동 선택
#   GODOTSTEAM_TAG=v4.16 tools/fetch_godotsteam.sh   # 특정 릴리스 태그
#   GODOTSTEAM_URL=https://.../x.zip tools/fetch_godotsteam.sh  # 받을 zip 직접 지정
#
# 받은 뒤 Godot 에디터를 한 번 열거나 `godot --headless --import` 로 임포트한다.
# 애드온이 없어도 게임은 ENet/혼자 하기로 동작한다 (scripts/net/steam_service.gd).
set -euo pipefail
cd "$(dirname "$0")/.."

API="https://codeberg.org/api/v1/repos/godotsteam/godotsteam/releases?limit=50"
GODOT_MINOR="${GODOT_MINOR:-4.4}"
URL="${GODOTSTEAM_URL:-}"

if [ -z "$URL" ]; then
	echo "릴리스 목록 확인: $API"
	URL=$(curl -fsSL "$API" | python3 -c '
import json, os, re, sys
tag = os.environ.get("GODOTSTEAM_TAG", "")
minor = os.environ.get("GODOT_MINOR", "4.4")
for release in json.load(sys.stdin):
    if tag and release["tag_name"] != tag:
        continue
    for asset in release.get("assets", []):
        name = asset["name"].lower()
        if "gdextension" in name and minor in name and name.endswith(".zip"):
            print(asset["browser_download_url"])
            sys.exit(0)
sys.exit("Godot %s 용 GodotSteam GDExtension zip 을 찾지 못함 (GODOTSTEAM_URL 로 직접 지정)" % minor)
')
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
echo "받는 중: $URL"
curl -fsSL -o "$TMP/godotsteam.zip" "$URL"
unzip -q "$TMP/godotsteam.zip" -d "$TMP/out"

SRC=$(find "$TMP/out" -type d -path "*addons/godotsteam" | head -n 1)
if [ -z "$SRC" ]; then
	echo "zip 안에 addons/godotsteam 폴더가 없음" >&2
	exit 1
fi
rm -rf addons/godotsteam
mkdir -p addons
cp -R "$SRC" addons/godotsteam
echo "$URL" > addons/godotsteam/.source_url
echo "완료: addons/godotsteam ($(du -sh addons/godotsteam | cut -f1))"
