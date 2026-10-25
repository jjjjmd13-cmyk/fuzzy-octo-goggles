# 기획팀 상태

**지금 하는 일**: 시제품 지원 문서 PR 검토 대기 (`planning/prototype-support`)

**끝낸 일**:
- 게임 콘셉트 3개 제안 → **B. 등불 원정대 선택됨 (2026-10-25)**
- 상세 기획서 `docs/design/GDD.md` 0.1판, ChatGPT 그래픽 요청문 `docs/art/CHATGPT_PROMPTS.md`
- GDD 15장 결정 반영 (실패 패널티는 첫 테스트 후 결정, 일정은 단계 + 완료 조건)
- 글꼴 결정 `docs/design/FONT.md` — Pretendard (OFL 1.1) + Noto Sans CJK fallback
- 시제품 플레이 테스트지 `docs/design/PLAYTEST_PROTOTYPE.md` (질문 10개 + 답별 분기, 실패 패널티 결정표)
- 수치표 `docs/design/TUNING.md` (GDD 수치를 리소스 키·단위·초기값으로 정리, 시제품용 표시)

**막힌 것**: 없음

**다른 부서에 요청**:
- 개발팀:
  - GDD 13장 첫 시제품. 수치는 `docs/design/TUNING.md` 키 이름대로 리소스 한 곳에서 읽게 (제안 경로 `res://data/balance/balance.tres`)
  - 시제품에 디버그 키: 시작 기름 30으로 바꾸기 (플레이 테스트 2판째에 씀)
  - 글꼴 파일 추가 (`docs/design/FONT.md` "개발팀 요청" 5개). 원본 파일을 고치지 말 것 (OFL 예약 글꼴 이름)
- QA:
  - 절차 생성 결정성 테스트 (GDD 9.4) — 생성기가 생긴 뒤
  - `docs/qa/TEST_PLAN.md` 의 "늦게 들어오기"(JOIN, LANT-3x): GDD 3장에서 데모는 원정 도중 참가(난입) 없음, 로비에서만 참가. 데모 범위에 맞춰 우선순위 조정 부탁 (정식판 후보로 남겨 두는 건 좋음)
