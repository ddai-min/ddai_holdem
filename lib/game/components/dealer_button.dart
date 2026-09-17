import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../ui/game_theme.dart';
import '../table_layout.dart';

/// 딜러 버튼. 누구부터 블라인드를 내는지 한눈에 보여 준다.
class DealerButton extends PositionComponent {
  // 자리 이름표(우선순위 10)보다 위에 그린다. 버튼이 이름표 뒤로 숨으면
  // 누가 딜러인지 알 수 없다.
  DealerButton({required this.layout}) : super(priority: 12);

  TableLayout layout;

  /// 버튼이 놓인 자리. 핸드가 돌지 않을 때는 null이다.
  int? seatIndex;

  double _builtForRadius = -1;
  late TextPaint _labelPaint;

  double get _radius => layout.cardWidth * 0.30;

  @override
  void render(Canvas canvas) {
    final index = seatIndex;
    if (index == null) {
      return;
    }
    _ensureTextPaint();

    final at = layout.dealerButtonPosition(index);
    final center = Offset(at.x, at.y);
    canvas.drawCircle(
      center.translate(0, _radius * 0.22),
      _radius,
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.35),
    );
    canvas.drawCircle(center, _radius, Paint()..color = GamePalette.cardFace);
    canvas.drawCircle(
      center,
      _radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = GamePalette.cardEdge,
    );
    _labelPaint.render(
      canvas,
      'D',
      Vector2(center.dx, center.dy),
      anchor: Anchor.center,
    );
  }

  void _ensureTextPaint() {
    if (_builtForRadius == _radius) {
      return;
    }
    _builtForRadius = _radius;
    _labelPaint = TextPaint(
      style: TextStyle(
        color: GamePalette.suitBlack,
        fontSize: _radius * 1.1,
        height: 1,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
