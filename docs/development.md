# 개발 환경

[← README](../README.md)

## 내려받아 돌려 보기

이 저장소는 [fvm](https://fvm.app)으로 Flutter 3.44.9에 고정되어 있다.

```sh
fvm flutter pub get
fvm flutter test          # 규칙 엔진 · 통신 계층 · 화면
fvm flutter run -d macos  # 또는 -d chrome, 연결된 기기
```

Firebase 설정이 없어도 앱은 뜬다. 그때는 홈 화면의 온라인 버튼이 잠기고
**혼자 연습하기**만 열린다. 게임 자체는 그 상태로도 전부 돌아간다.

## Firebase 설정

`ddai-holdem` 프로젝트에 이미 연결되어 있다. Android · iOS · macOS · 웹 네 플랫폼이
등록됐고, `lib/firebase_options.dart`와 각 플랫폼 설정 파일이 생성되어 있으며
`firestore.rules`도 배포된 상태다. 앱 ID는 네 플랫폼 모두 `com.ddai.holdem`이다.

익명 로그인은 켜져 있다. 이 앱은 익명 로그인만 쓴다 — 이메일도 비밀번호도 받지
않고, 닉네임은 기기에만 저장한다. 꺼져 있으면 방을 만들거나 참가할 때
`operation-not-allowed` 오류가 나고, 콘솔의
[Authentication → Sign-in method](https://console.firebase.google.com/project/ddai-holdem/authentication/providers)
에서 **익명(Anonymous)** 을 켜면 된다.

생성된 설정 파일(`firebase_options.dart`, `google-services.json`,
`GoogleService-Info.plist`)에 들어 있는 API 키는 비밀이 아니다. 클라이언트를
가리키는 공개 식별자일 뿐이고, 실제 접근 통제는 `firestore.rules`가 한다. 그래서
저장소에 함께 두는 것이 정상이다.

## 플랫폼별 준비 상태

| 플랫폼 | 온라인 대전 | 비고 |
|---|---|---|
| Android | 바로 됨 | 추가 설정 없음 |
| iOS (시뮬레이터 · 실기기) | 바로 됨 | 배포 타깃 15.0 |
| 웹 | 바로 됨 | 키체인을 쓰지 않는다 |
| macOS | **코드 서명 설정 1회 필요** | 아래 참고. 그 전에도 연습 모드는 열린다 |

플랫폼 쪽 준비는 이미 되어 있다. macOS 샌드박스의 네트워크 권한
(`com.apple.security.network.client`), Android의 `INTERNET` 권한, macOS 배포
타깃(12.0)과 iOS 배포 타깃(15.0)을 모두 맞춰 두었다. 앞의 둘이 빠지면 앱은 뜨지만
연결만 조용히 실패하고, 뒤의 둘은 Flutter 3.44.9 템플릿 기본값이 Xcode 27의
최소치보다 낮아 빌드 자체가 막힌다.

## macOS에서 온라인 대전 쓰기

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

## 다른 Firebase 프로젝트로 옮기려면

```sh
flutterfire configure --project=<프로젝트ID> --platforms=android,ios,macos,web
firebase deploy --only firestore:rules --project <프로젝트ID>
```

`flutterfire`는 `dart`를 PATH에서 찾는다. fvm으로 SDK를 고정해 두면 전역 `dart`가
없어 `dart: command not found`가 나므로, 이 저장소의 SDK를 먼저 얹고 실행한다.

```sh
export PATH="$PWD/.fvm/flutter_sdk/bin/cache/dart-sdk/bin:$PATH"
```
