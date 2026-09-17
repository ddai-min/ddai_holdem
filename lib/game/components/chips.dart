import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../ui/game_theme.dart';

/// 금액만큼의 칩 더미를 [center]에 그린다.
///
/// 액면가를 정확히 맞추지는 않는다. 금액이 클수록 더미가 높고 색이 짙어지도록
/// 해서, 숫자를 읽기 전에도 판돈의 크기가 눈에 들어오게 하는 것이 목적이다.
void renderChipStack(
  Canvas canvas,
  Offset center,
  int amount, {
  required double radius,
}) {
  if (amount <= 0) {
    return;
  }
  final magnitude = math.log(amount) / math.ln10;
  final tier = magnitude.floor().clamp(0, GamePalette.chipColors.length - 1);
  final color = GamePalette.chipColors[tier];
  final count = (1 + magnitude).floor().clamp(1, 5);

  final lift = radius * 0.34;
  final height = radius * 0.52;

  for (var i = 0; i < count; i++) {
    final top = center.dy - i * lift;
    final rect = Rect.fromCenter(
      center: Offset(center.dx, top),
      width: radius * 2,
      height: height,
    );
    // 옆면을 먼저 깔아야 위에 얹히는 칩이 두툼해 보인다.
    canvas.drawOval(
      rect.translate(0, lift * 0.45),
      Paint()..color = _darken(color, 0.42),
    );
    canvas.drawOval(rect, Paint()..color = color);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, radius * 0.08)
        ..color = _darken(color, 0.25),
    );
  }

  // 맨 위 칩에만 흰 테를 둘러 초점을 준다.
  final topRect = Rect.fromCenter(
    center: Offset(center.dx, center.dy - (count - 1) * lift),
    width: radius * 1.15,
    height: height * 0.56,
  );
  canvas.drawOval(
    topRect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, radius * 0.07)
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55),
  );
}

Color _darken(Color color, double amount) => Color.lerp(
  color,
  const Color(0xFF000000),
  amount,
)!;
