# 배포

[← README](../README.md)

## 웹

Firebase Hosting에 올라가 있다. **<https://ddai-holdem.web.app>**

```sh
fvm flutter build web --release
firebase deploy --only hosting
```

`firebase.json`의 `hosting` 설정이 두 가지를 맡는다.

- **SPA 리라이트** — 어떤 경로로 들어와도 `index.html`을 준다.
- **진입점 캐시 금지** — `/`, `index.html`, `flutter_bootstrap.js`,
  `flutter_service_worker.js`, `main.dart.js`, `version.json`에
  `Cache-Control: no-cache`를 붙인다. 이게 없으면 기본값 `max-age=3600`이 걸려서,
  새 버전을 올려도 최대 한 시간 동안 옛 페이지를 보게 된다. 헤더는 리라이트
  *전*의 경로로 매칭되므로 `/`와 `/index.html`을 둘 다 적어야 한다.

나머지 파일(canvaskit 등)은 기본 한 시간 캐시에 맡긴다. 그 뒤로는 ETag로
확인만 하므로 다시 내려받지 않는다.

콜드 로딩은 brotli 압축 기준 약 3.7MB다(`main.dart.js` 0.6MB +
`canvaskit.wasm` 2.8MB + 한글 글꼴 두 벌 0.34MB). Firebase 무료 요금제의 하루
전송량이 360MB이니 하루 100번 남짓의 첫 방문까지는 넉넉하다. 한 번 받은 사람은
캐시를 쓴다.

내리려면:

```sh
firebase hosting:disable
```

웹에서는 키체인을 쓰지 않으므로 macOS 같은 코드 서명 절차가 필요 없다. 친구에게
주소만 알려 주면 바로 들어온다.

## 보안 규칙 배포와 검증

규칙(`firestore.rules`)이 하는 일은 한 가지로 요약된다. **남의 홀 카드는 어떤
경로로도 읽히지 않는다.** 공개 문서에는 애초에 실리지 않고, 각자의 카드는 본인
uid로만 읽을 수 있는 문서에 따로 들어간다.

규칙을 고쳤다면 배포한 뒤 실제로 막히는지 확인한다. 검증 스크립트는 익명 사용자
둘을 만들어 «남의 홀 카드 읽기» · «방장 비밀 문서 읽기» · «남의 uid 사칭» 을
포함한 열한 가지를 실제로 시도하고, 만든 문서와 계정을 정리까지 한다.

```sh
firebase deploy --only firestore:rules
python3 tool/verify_rules.py
```

문서 구조와 각 경로를 누가 읽는지는 [설계](architecture.md#홀-카드를-지키는-방법)에
정리해 두었다.

## 모바일

Android는 추가 설정 없이 빌드된다. iOS는 배포 타깃 15.0으로 맞춰 두었고, 실기기에
올리려면 `ios/Runner.xcodeproj`의 개발팀 설정이 필요하다. macOS는 온라인 대전에
한해 코드 서명 설정이 한 번 더 필요하다 —
[개발 환경](development.md#macos에서-온라인-대전-쓰기)에 이유와 절차가 있다.
