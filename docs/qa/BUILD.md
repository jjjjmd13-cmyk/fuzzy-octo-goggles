# Windows 실행 파일 받기 (Godot 필요 없음)

`main` 에 새 코드가 들어갈 때마다 GitHub Actions 가 Windows 실행 파일을 자동으로 만든다 (`.github/workflows/build.yml`).
만든 파일은 14일 동안 받을 수 있다.

1. GitHub 저장소 → 위쪽 **Actions** 탭 → 왼쪽 **Windows 빌드** → 맨 위(가장 최근) 초록 체크 표시 실행을 누른다.
2. 아래 **Artifacts** 에서 `PawsAndBubbles-windows-<커밋>` 을 눌러 zip 을 받고(GitHub 로그인 필요), 압축을 풀어 `PawsAndBubbles.exe` 를 실행한다.
3. "Windows의 PC 보호" 창이 뜨면 **추가 정보 → 실행** 을 누른다 (서명하지 않은 개발 빌드라서 뜬다).

- 이 빌드에는 스팀 애드온이 없어서 **혼자 하기와 IP 접속만** 된다. 같은 PC 에서 2인은 실행 파일을 두 번 켜서 한쪽은 "호스트 열기", 다른 쪽은 "접속".
- 최신 빌드가 없거나 지금 바로 만들고 싶으면: Actions → Windows 빌드 → **Run workflow** (main).

## 자동 Windows 실행 확인 ("Windows 실행 확인" 작업)

빌드가 끝나면 GitHub 의 깨끗한 Windows 러너(저장 파일 없음)에서 그 실행 파일을 켜 본다.

- **판정**: 화면 없이(`--headless`) 1800 프레임 동안 켜 두고, 튕기지 않고(종료 코드 0) 스크립트 오류가 없으면 통과.
- **참고용**: 화면을 그리며(`--rendering-driver d3d12`, 러너에 그래픽 카드가 없어 소프트웨어) 300 프레임. 실패해도 빨간불로 만들지 않는다.
- 로그는 `windows-smoke-logs-<실행 번호>` 로 올린다.
- 실제 PC 의 글꼴·해상도·드라이버 차이는 이 확인으로 대신할 수 없다 → 사람 대표 플레이에서 확인.
