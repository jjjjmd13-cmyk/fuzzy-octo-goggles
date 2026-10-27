# 3D 아트 재현·검수

모든 작업은 저장소 루트에서 실행한다. Blender 4.5.3 LTS, Python 3 (`numpy`, `Pillow`, `shapely`), Node.js 및 검사용 `gltf-validator`가 필요하다. 에셋을 만드는 데 유료 서비스·API·다운로드 모델은 필요하지 않다. Blender와 검사용 라이브러리는 작업 도구이며 GLB 안에 포함하지 않는다.

```bash
blender -b --factory-startup --python tools/art/build_slots.py -- dog owner tub turntable chair tiles
python tools/art/validate_slots.py
blender -b --factory-startup --python tools/art/render_slots.py -- all
python tools/art/compose_previews.py
blender -b --factory-startup --python tools/art/render_station.py
```

렌더 중간 파일은 `art/render_work/`에 생긴다. 납품 PNG는 슬롯 폴더에 한 장씩 저장한다. 중간 파일은 커밋할 필요가 없다.

형식 검수 도구는 공식 Khronos 패키지 `gltf-validator`를 별도 작업 디렉터리에 설치한 후 해당 모듈 경로를 `NODE_PATH`로 지정한다. 예:

```bash
npm install --prefix /tmp/paws-validator gltf-validator
NODE_PATH=/tmp/paws-validator/node_modules node tools/art/validate_gltf.cjs \
  art/incoming/dog/dog.glb art/incoming/owner/owner.glb \
  art/incoming/tub/tub.glb art/incoming/turntable/turntable.glb \
  art/incoming/chair/chair.glb art/incoming/tiles/floor.glb art/incoming/tiles/wall.glb
```

게임 연결 파일을 변경하지 않고 실제 GLB 파싱과 현재 스크립트의 호환성을 확인한다:

```bash
godot --headless --path . --script tools/art/verify_godot.gd
GODOT=godot bash tests/run_tests.sh
```

`art/incoming/.gdignore`는 유지한다. `GLTFDocument`로 파일을 직접 읽는 검수이며, 프로덕션 씬에 최종 연결하는 작업은 개발팀 범위다. 저장소의 Godot 고정 버전은 **4.4.1**이다.

출처: `docs/art/ASSET_PROVENANCE.md`. 납품 수치와 검수 기록: `docs/art/DELIVERY_SLOTS.md`.
