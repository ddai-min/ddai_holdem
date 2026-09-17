import 'package:flutter/material.dart';

import 'app.dart';
import 'data/profile_store.dart';
import 'net/firebase_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final profile = await ProfileStore.open();

  // 온라인 준비는 여기서 한 번 해 두되, 실패해도 앱은 그대로 띄운다.
  // Firebase 설정 전에도 연습 모드로 게임을 확인할 수 있어야 한다.
  await FirebaseGate.ensureReady().timeout(
    const Duration(seconds: 8),
    onTimeout: () => false,
  );

  runApp(HoldemApp(profile: profile));
}
