import 'package:flutter/material.dart';

/// 앱에 넣어 둔 한글 글꼴.
///
/// Flutter 웹은 기본 글꼴조차 구글 CDN 에서 받아 온다. 그동안은 글자가 통째로
/// 비어 보이고, 연결이 막히면 끝내 안 나온다. 한글로만 된 화면이라 치명적이라
/// 글꼴을 앱에 함께 넣고 처음부터 이것만 쓴다.
///
/// Flame 의 [TextPaint] 는 위젯 테마를 타지 않으므로 테이블을 그리는 쪽에서도
/// 이 이름을 직접 얹어야 한다.
const String kFontFamily = 'NotoSansKR';

/// 화면과 Flame 컴포넌트가 함께 쓰는 색.
///
/// 어두운 방에 초록 테이블 하나를 놓은 그림으로 고정한다. 값을 바꾸면 UI와
/// 테이블이 같이 바뀐다.
abstract final class GamePalette {
  // 화면 전체
  static const Color background = Color(0xFF0B1210);
  static const Color surface = Color(0xFF14201B);
  static const Color surfaceHigh = Color(0xFF1B2C24);
  static const Color border = Color(0xFF263B31);

  // 테이블
  static const Color feltCenter = Color(0xFF1B6B47);
  static const Color feltEdge = Color(0xFF0F4430);
  static const Color feltLine = Color(0xFF2E8B63);
  static const Color railOuter = Color(0xFF1A2A23);
  static const Color railInner = Color(0xFF32271A);
  static const Color railHighlight = Color(0xFF5A4526);

  // 카드
  static const Color cardFace = Color(0xFFF7F5EF);
  static const Color cardEdge = Color(0xFFCFCABB);
  static const Color cardBack = Color(0xFF7A2230);
  static const Color cardBackPattern = Color(0xFF9C3040);
  static const Color suitRed = Color(0xFFC62B34);
  static const Color suitBlack = Color(0xFF1A1A1E);

  // 자리
  static const Color seatIdle = Color(0xFF16241E);
  static const Color seatActive = Color(0xFFD9A84E);
  static const Color seatWinner = Color(0xFF4ADE80);
  static const Color seatFolded = Color(0xFF0E1714);

  // 칩 액면가별 색. 낮은 것부터 높은 것 순이다.
  static const List<Color> chipColors = <Color>[
    Color(0xFFE5E7EB),
    Color(0xFFDC2626),
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFF1F2937),
    Color(0xFF9333EA),
  ];

  // 글자와 강조
  static const Color accent = Color(0xFFD9A84E);
  static const Color textPrimary = Color(0xFFEAF0EC);
  static const Color textSecondary = Color(0xFF8DA396);
  static const Color textMuted = Color(0xFF5B7065);

  // 액션 버튼
  static const Color foldColor = Color(0xFF9F3E3E);
  static const Color checkColor = Color(0xFF2F7D5B);
  static const Color raiseColor = Color(0xFFC08A2E);
  static const Color danger = Color(0xFFEF4444);
}

ThemeData buildGameTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: kFontFamily,
  );
  return base.copyWith(
    scaffoldBackgroundColor: GamePalette.background,
    colorScheme: base.colorScheme.copyWith(
      primary: GamePalette.accent,
      surface: GamePalette.surface,
      onPrimary: GamePalette.background,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: GamePalette.textPrimary,
      displayColor: GamePalette.textPrimary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: GamePalette.accent,
        foregroundColor: GamePalette.background,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: kFontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: GamePalette.textPrimary,
        side: const BorderSide(color: GamePalette.border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: GamePalette.textSecondary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GamePalette.surfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: GamePalette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: GamePalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: GamePalette.accent, width: 1.6),
      ),
      labelStyle: const TextStyle(
        fontFamily: kFontFamily,
        color: GamePalette.textSecondary,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: GamePalette.surfaceHigh,
      contentTextStyle: TextStyle(
        fontFamily: kFontFamily,
        color: GamePalette.textPrimary,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// 칩 개수를 "1,240"처럼 끊어 읽기 좋게 만든다.
String formatChips(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
