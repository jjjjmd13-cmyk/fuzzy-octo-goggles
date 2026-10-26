# Windows 실행 파일 받기 (Godot 필요 없음)

`main` 에 새 코드가 들어갈 때마다 GitHub Actions 가 Windows 실행 파일을 자동으로 만든다 (`.github/workflows/build.yml`).
만든 파일은 14일 동안 받을 수 있다.

1. GitHub 저장소 → 위쪽 **Actions** 탭 → 왼쪽 **Windows 빌드** → 맨 위(가장 최근) 초록 체크 표시 실행을 누른다.
2. 아래 **Artifacts** 에서 `PawsAndBubbles-windows-<커밋>` 을 눌러 zip 을 받고(GitHub 로그인 필요), 압축을 풀어 `PawsAndBubbles.exe` 를 실행한다.
3. "Windows의 PC 보호" 창이 뜨면 **추가 정보 → 실행** 을 누른다 (서명하지 않은 개발 빌드라서 뜬다).

- 이 빌드에는 스팀 애드온이 없어서 **혼자 하기와 IP 접속만** 된다. 같은 PC 에서 2인은 실행 파일을 두 번 켜서 한쪽은 "호스트 열기", 다른 쪽은 "접속".
- 최신 빌드가 없거나 지금 바로 만들고 싶으면: Actions → Windows 빌드 → **Run workflow** (main).
