import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../ui/game_theme.dart';
import '../table_layout.dart';

/// 초록 펠트와 나무 레일로 된 테이블.
///
/// 화면 크기에 따라 타원이 늘어나므로 그림 파일 대신 매번 그린다. 어떤 비율의
/// 화면에서도 테이블이 잘리지 않는다.
class TableFelt extends PositionComponent {
  TableFelt({required this.layout}) : super(priority: -10);

  TableLayout layout;

  @override
  void render(Canvas canvas) {
    final center = Offset(layout.center.x, layout.center.y);
    final rail = Rect.fromCenter(
      center: center,
      width: (layout.feltRadiusX + layout.railWidth) * 2,
      height: (layout.feltRadiusY + layout.railWidth) * 2,
    );
    final felt = Rect.fromCenter(
      center: center,
      width: layout.feltRadiusX * 2,
      height: layout.feltRadiusY * 2,
    );

    // 테이블이 바닥에서 조금 떠 보이도록 아래로 깔리는 그림자를 먼저 그린다.
    canvas.drawOval(
      rail.translate(0, layout.railWidth * 0.6),
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, layout.railWidth),
    );

    canvas.drawOval(
      rail,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            GamePalette.railHighlight,
            GamePalette.railInner,
            GamePalette.railOuter,
          ],
          stops: <double>[0, 0.45, 1],
        ).createShader(rail),
    );

    canvas.drawOval(
      felt,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[GamePalette.feltCenter, GamePalette.feltEdge],
          stops: <double>[0.15, 1],
        ).createShader(felt),
    );

    // 베팅 라인. 실제 테이블에 그려진 선을 흉내 낸 것으로, 가운데가 어디인지
    // 눈에 잡아 준다.
    canvas.drawOval(
      felt.deflate(layout.railWidth * 0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = GamePalette.feltLine.withValues(alpha: 0.55),
    );
  }
}
