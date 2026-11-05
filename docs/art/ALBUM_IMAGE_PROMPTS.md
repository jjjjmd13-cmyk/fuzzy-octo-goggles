# 사진첩 UI 생성 프롬프트 기록

방식: 내장 `image_gen` 도구, `transparent_background=true`. 생성 후 프로젝트 PNG로 복사·크기 정리. 3D 미리보기는 이미지 생성이 아니라 납품 GLB의 Blender 렌더다.

모든 2D 프롬프트의 공통 조건: soft rounded pastel toy game UI, simple color areas, warm cute tone, true alpha transparency, no letters/numbers/logos/watermarks, full asset inside canvas with transparent margins, straight-on view, no perspective.

## album_page.png

Create one production-ready 1024x1280 portrait UI sprite: a single thick cream #FFF1C9 paper album page with softly rounded corners and a transparent outer margin. Four very subtle empty square photo placeholders in an exact spacious 2x2 grid, pale cream outlines only, no actual photos. Tiny pink #FF9EC4 and mint #B8E3D3 paw prints at page corners. No writing or binding rings. Restrained edge shading, actual alpha outside the page.

## photo_frame_grey/white/pink/gold.png

Exactly one straight-on flat Polaroid picture frame, portrait 512x600 proportions, true transparent outer margin and central square aperture. Thin top/side bands and a much wider bottom band. No picture, no solid fill or checker pattern inside the hole. Clean pastel toy edge. No names, writing, logos, numbers or extra objects.

- grey: light gray #D1D4DC, simple calm subdued frame, no ornaments.
- white: clean warm white #FFFEFA, pristine simple paper frame, no ornaments.
- pink: strawberry milk #FF9EC4 frame, exactly two tiny cherry-pink hearts on the upper-left and lower-right border, leaving aperture empty.
- gold: warm pastel gold #EBC56A, small gold star on lower-left border and a four-point golden sparkle on upper-right border, restrained gleaming highlights.

Packaging normalizes all four to the same outer rectangle (24,24)-(488,576) and exact alpha-zero square aperture (64,64)-(448,448) using their generated border/ornament pixels.

## photo_unknown.png

One 512x512 transparent game UI icon. Two overlapping solid light-gray #C9CDD6 silhouettes only: sitting friendly floppy-eared dog slightly left/front, upright round-triangle-eared cat slightly right/back. Ears and curled cat tail distinguish the animals. No faces, eyes, nose, mouth, fur marks, outlines, question mark, symbols, text, ground or shadow. Rounded simple pastel toy shapes and a transparent margin.

## fav_spot_chin.png

One tiny 128x128 transparent UI icon. A single solid sky blue #8FD3F4 silhouette of a cute sitting dog in exact right-facing side profile, tail left, round floppy ear, short muzzle, straight front leg and round haunch. No eyes/nose/mouth/outlines. Exactly one small strawberry pink #FF9EC4 heart under the chin at the throat just behind the muzzle. No other pink shapes or text.

## fav_spot_ear_back/back/rump.png

Edit the chin reference, preserving the exact dog pose/proportions/colors/position and transparent background. Remove the old heart completely. Put exactly one small pink heart at:

- ear_back: the rear edge of the floppy ear, behind the ear rather than the throat/back. Refinement: the whole heart, both rounded lobes and pointed bottom, must remain visible in front of the silhouette; do not let the dog hide part of it.
- back: the middle of the upper sloping torso outline between neck and rump, not the head/chest/hip.
- rump: the rounded hip near the tail root, not the head/chest.

No facial details, text, labels, numbers, logos or additional hearts. All three edits use the same original blue dog reference.

## new_photo_badge.png

One 128x128 transparent UI sticker: one chubby rounded five-point butter-yellow #FFD86F star with restrained gold #EDBB51 edge and a tiny cream glint on the upper-left arm. Simple warm pastel toy shapes. No face, eyes, mouth, text, numbers, exclamation mark, logos, secondary stars, ground or cast shadow.
