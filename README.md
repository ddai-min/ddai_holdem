# DDAI 홀덤

친구들과 방 코드 하나로 즐기는 노 리밋 텍사스 홀덤. Flutter + [Flame] 게임
엔진으로 테이블을 그리고, Firebase(Firestore + 익명 인증)로 서로를 잇는다.

[Flame]: https://docs.flame-engine.org

- 모바일과 데스크탑을 한 벌의 코드로 지원한다. 화면 비율을 보고 좌석 타원을
  매번 새로 계산하기 때문에, 세로로 긴 휴대폰에서도 가로로 넓은 데스크탑에서도
  테이블이 잘리지 않는다.
- **연습 모드**가 따로 있다. Firebase 설정을 하지 않아도 봇을 상대로 바로
  돌려 볼 수 있다.

## 실행

이 저장소는 [fvm]으로 Flutter 3.44.9에 고정되어 있다.

```sh
fvm flutter pub get
fvm flutter test          # 규칙 엔진과 통신 계층 테스트
fvm flutter run -d macos  # 또는 -d chrome, 연결된 기기
```

`flutterfire configure`를 아직 돌리지 않았다면 홈 화면의 온라인 버튼이 잠기고
**혼자 연습하기**만 열린다. 게임 자체는 그 상태로도 전부 돌아간다.

[fvm]: https://fvm.app

## Firebase 설정

`ddai-holdem` 프로젝트에 이미 연결되어 있다. Android·iOS·macOS·웹 네 플랫폼이
등록됐고, `lib/firebase_options.dart`와 각 플랫폼 설정 파일이 생성되어 있으며
`firestore.rules`도 배포된 상태다. 앱 ID는 네 플랫폼 모두 `com.ddai.holdem`이다.

**남은 한 가지: 익명 로그인 켜기.** 콘솔에서 한 번만 누르면 된다.

> [Authentication → Sign-in method](https://console.firebase.google.com/project/ddai-holdem/authentication/providers)
> → **익명(Anonymous)** → 사용 설정

이 앱은 익명 로그인만 쓴다. 이메일도 비밀번호도 받지 않고, 닉네임은 기기에만
저장한다. 이 토글을 켜지 않으면 방을 만들거나 참가할 때
`operation-not-allowed` 오류가 난다.

생성된 설정 파일(`firebase_options.dart`, `google-services.json`,
`GoogleService-Info.plist`)에 들어 있는 API 키는 비밀이 아니다. 클라이언트를
가리키는 공개 식별자일 뿐이고, 실제 접근 통제는 아래 보안 규칙이 한다. 그래서
저장소에 함께 두는 것이 정상이다.

### 플랫폼별 준비 상태

| 플랫폼 | 온라인 대전 | 비고 |
|---|---|---|
| Android | 바로 됨 | 추가 설정 없음 |
| iOS (시뮬레이터/실기기) | 바로 됨 | 배포 타겟 15.0 |
| 웹 | 바로 됨 | 키체인을 쓰지 않는다 |
| macOS | **코드 서명 설정 1회 필요** | 아래 참고. 그 전에도 연습 모드는 열린다 |

### macOS에서 온라인 대전 쓰기

macOS의 Firebase Auth는 로그인 상태를 **데이터 보호 키체인**에 넣는다. 거기에
접근하려면 프로비저닝 프로파일이 넣어 주는 `application-identifier` entitlement가
있어야 하는데, Flutter 기본값인 애드혹 서명(`CODE_SIGN_IDENTITY = "-"`)으로는
만들 수 없는 값이다. 샌드박스를 꺼도, 실제 개발 인증서로 서명해도 소용없다.
프로파일이 있어야 한다.

프로파일을 만들려면 이 Mac이 애플 개발자 계정에 기기로 등록되어 있어야 한다.
Xcode에서 한 번 열면 자동으로 처리된다.

1. Xcode로 연다.

   ```sh
   open macos/Runner.xcworkspace
   ```

   Runner 타깃 → **Signing & Capabilities** → *Automatically manage signing* 체크
   → Team 선택. Xcode가 이 Mac을 기기로 등록하고 프로파일을 만든다.
   포털에 직접 넣고 싶다면 이 Mac의 식별자는 이렇게 확인한다.

   ```sh
   system_profiler SPHardwareDataType | grep "Provisioning UDID"
   ```

2. 두 곳의 주석을 푼다. 무엇을 풀어야 하는지는 파일 안에 적어 두었다.

   - `macos/Runner/DebugProfile.entitlements` → `keychain-access-groups`
   - `macos/Runner/Configs/AppInfo.xcconfig` → `DEVELOPMENT_TEAM` 등 세 줄

3. 실행한다.

   ```sh
   fvm flutter run -d macos
   ```

설정 전까지 macOS에서 온라인 버튼을 누르면 무엇을 해야 하는지 안내가 뜬다.
연습 모드는 그대로 열린다.

### 다른 프로젝트로 옮기려면

```sh
flutterfire configure --project=<프로젝트ID> --platforms=android,ios,macos,web
firebase deploy --only firestore:rules --project <프로젝트ID>
```

`flutterfire`는 `dart`를 PATH에서 찾는다. fvm으로 SDK를 고정해 두면 전역 `dart`가
없어 `dart: command not found`가 나므로, 이 저장소의 SDK를 먼저 얹고 실행한다.

```sh
export PATH="$PWD/.fvm/flutter_sdk/bin/cache/dart-sdk/bin:$PATH"
```

플랫폼 쪽 준비는 이미 되어 있다. macOS 샌드박스의 네트워크 권한
(`com.apple.security.network.client`), Android의 `INTERNET` 권한, macOS 배포
타겟(12.0)을 모두 맞춰 두었다. 이것들이 빠지면 앱은 뜨지만 연결만 조용히
실패한다.

규칙(`firestore.rules`)이 하는 일은 한 가지로 요약된다. **남의 홀 카드는 어떤
경로로도 읽히지 않는다.** 공개 문서에는 애초에 실리지 않고, 각자의 카드는 본인
uid로만 읽을 수 있는 문서에 따로 들어간다.

규칙을 고쳤다면 배포한 뒤 실제로 막히는지 확인한다. 익명 사용자 둘을 만들어
"남의 홀 카드 읽기", "남의 uid 사칭" 같은 시도를 직접 해 보고 정리까지 한다.

```sh
firebase deploy --only firestore:rules
python3 tool/verify_rules.py
```

## 웹 배포

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

콜드 로딩은 brotli 압축 기준 약 3.6MB다(`main.dart.js` 0.8MB +
`canvaskit.wasm` 2.8MB). Firebase 무료 요금제의 하루 전송량이 360MB이니
하루 100번 남짓의 첫 방문까지는 넉넉하다. 한 번 받은 사람은 캐시를 쓴다.

내리려면:

```sh
firebase hosting:disable
```

웹에서는 키체인을 쓰지 않으므로 macOS 같은 코드 서명 절차가 필요 없다. 친구에게
주소만 알려 주면 바로 들어온다.

## 구조

```
lib/
  engine/     홀덤 규칙. Flutter도 Firebase도 모르는 순수 Dart.
  net/        방을 잇는 통신 계층. Firestore와 로컬 두 가지 구현.
  game/       Flame으로 테이블을 그리는 쪽.
  ui/         화면, 오버레이, 테마.
  data/       기기에 남기는 설정(닉네임).
```

### 진행을 누가 맡는가

방장 기기가 규칙 판정을 전담한다.

```
참가자                     Firestore                    방장
  │  commands/{id} 생성  →     │
  │                            │  → 스냅샷 →              │  HoldemEngine.apply()
  │                            │                          │  규칙 검사 후 반영
  │  ← rooms/{code} 스냅샷 ←   │  ← 한 번에 batch 쓰기 ←   │
  │  ← private/{내 uid} ←      │
```

참가자는 테이블 문서를 직접 고칠 수 없다. 요청만 남기고, 반영 여부는 방장의
엔진이 정한다. 문서를 직접 건드리거나 화면이 한발 늦은 상태에서 버튼을 눌러도
판이 어그러지지 않는다.

- 명령에는 보낼 때 보던 `handNumber`와 `actionCounter`가 함께 실린다. 둘이
  어긋나면 방장이 버린다. 연타하거나 통신이 늦어도 액션은 한 번만 반영된다.
- 남은 덱과 모두의 홀 카드는 방장만 읽는 `secret/host` 문서에 남는다. 방장
  기기가 잠깐 끊겼다 돌아와도 돌리던 판을 그대로 이어 간다.
- 제한 시간을 넘기거나 접속이 끊긴 사람은 방장이 대신 체크 또는 폴드한다.

### 규칙 엔진

`lib/engine/`은 화면도 네트워크도 모른다. `TableState` 하나를 받아 고쳐 나갈
뿐이라, 나중에 진행을 서버로 옮기고 싶으면 그대로 떼어 쓸 수 있다.

구현한 것:

- 2~9인 노 리밋 홀덤, 버튼·블라인드 이동 (2인 헤즈업 순서 포함)
- 프리플랍 빅 블라인드 옵션
- 최소 레이즈 폭, **부족한 올인은 베팅을 다시 열지 않는다**
- 아무도 받아 주지 않은 베팅 반환
- 메인 팟과 사이드 팟, 자격이 같은 층은 하나로 합침
- 무승부 분배, 나누어떨어지지 않는 칩은 버튼 왼쪽부터
- 7장 중 최고 5장 족보 판정 (A-2-3-4-5 포함)

테스트가 이 항목들을 하나씩 짚는다.

```sh
fvm flutter test
```

## 알려진 제약

- **방장이 나가면 판이 멈춘다.** 상태와 덱이 Firestore에 남아 있어 방장이 다시
  들어오면 이어지지만, 다른 사람에게 진행을 넘기는 기능은 아직 없다.
- 진행을 방장 기기가 맡으므로 **서버 권위 모델은 아니다.** 친구끼리 하는 판을
  전제로 한 설계다. 모르는 사람과 붙이려면 이 엔진을 Cloud Functions이나 별도
  Dart 서버로 옮기면 된다. 엔진이 순수 Dart인 것은 그 때문이다.
- 방 코드는 5자리라 코드를 아는 사람은 누구나 들어올 수 있다. 들어와도 남의
  홀 카드는 볼 수 없다.
- 오래된 방 문서는 저절로 지워지지 않는다. Firestore TTL 정책을 `updatedAtMs`
  기준으로 걸어 두면 깔끔하다.
