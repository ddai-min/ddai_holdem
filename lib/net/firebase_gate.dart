import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Firebase를 쓸 수 있는 상태인지 한 번만 확인해 두는 창구.
///
/// `flutterfire configure`를 아직 돌리지 않았거나 네트워크가 없으면 온라인
/// 대전만 잠그고 앱 자체는 그대로 뜬다. 설정이 끝나기 전에도 연습 모드로
/// 게임을 확인할 수 있어야 하기 때문이다.
abstract final class FirebaseGate {
  static bool _ready = false;
  static String? _problem;

  static bool get isReady => _ready;

  /// 준비되지 않은 이유. 화면에 그대로 띄운다.
  static String? get problem => _problem;

  static String? get uid => _ready ? FirebaseAuth.instance.currentUser?.uid : null;

  static Future<bool> ensureReady() async {
    if (_ready) {
      return true;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      // 익명 로그인이면 충분하다. 기기에 남아 있는 계정이 있으면 그대로 쓴다.
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
      _ready = true;
      _problem = null;
    } on UnsupportedError {
      _problem = 'Firebase 설정이 아직 없습니다. `flutterfire configure`를 실행하세요.';
      _ready = false;
    } on FirebaseAuthException catch (error) {
      debugPrint('Firebase 로그인에 실패했습니다: $error');
      _problem = _describeAuthFailure(error);
      _ready = false;
    } catch (error) {
      debugPrint('Firebase를 준비하지 못했습니다: $error');
      _problem = '온라인에 연결하지 못했습니다: $error';
      _ready = false;
    }
    return _ready;
  }

  /// 로그인 실패를 "그래서 무엇을 하면 되는가"로 바꿔 준다.
  ///
  /// 원문 그대로 띄우면 키체인이 어떻고 하는 이야기만 나와서, 정작 해야 할
  /// 일을 알 수 없다.
  static String _describeAuthFailure(FirebaseAuthException error) {
    if (error.code == 'keychain-error' &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.macOS) {
      // macOS의 Firebase Auth는 데이터 보호 키체인을 쓰는데, 거기에 닿으려면
      // 프로비저닝 프로파일로 서명해야 한다. 기본 애드혹 서명으로는 안 된다.
      return 'macOS에서 온라인 대전을 쓰려면 코드 서명 설정이 한 번 필요합니다.\n'
          'README의 "macOS에서 온라인 대전 쓰기"를 보세요.\n'
          '연습 모드는 지금 그대로 쓸 수 있고, iOS·Android·웹에서는 설정 없이 됩니다.';
    }
    if (error.code == 'operation-not-allowed') {
      return 'Firebase 콘솔의 Authentication에서 익명 로그인을 켜 주세요.';
    }
    if (error.code == 'network-request-failed') {
      return '네트워크에 닿지 못했습니다. 연결을 확인해 주세요.';
    }
    return '로그인하지 못했습니다: ${error.message ?? error.code}';
  }
}
