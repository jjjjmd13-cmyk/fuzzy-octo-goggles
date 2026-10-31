# 1인칭 도구 및 장갑

- 제작: 기존 build_slots.py의 파스텔 팔레트와 무광 재질을 재사용한 자체 제작 메시.
- 단위: 1 unit = 1 m, Y-up, 전방 -Z. 텍스처 없음.
- 도구 원점: 손잡이/병 중앙, 수건은 가까운 가장자리의 쥐는 위치.
- hands.glb: Hand_L, Hand_R 메시의 원점은 각각 손목. 장면에서 손목은 X=-0.105/+0.105 m. 손가락은 -Z 방향. 정적 메시이며 리깅/애니메이션은 포함하지 않음.
- 재생성: Blender 4.5에서 tools/art/build_first_person.py 실행.
- 미리보기와 삼각형 집계: art/incoming/first_person/.
- 게임 씬 연결 및 잡기 애니메이션은 개발팀에서 적용.

검증: GLB 인덱스 기준 샤워기 2108, 샴푸 1392, 수건 876, 드라이어 1224, 양손 합계 2392 삼각형. 렌더 5장 확인. Godot 4.4.1 임포트 시 알려진 dummy texture 썸네일 오류 발생; 기존 test_retail_art 실행은 엔진 signal 11 충돌로 완료하지 못함.
