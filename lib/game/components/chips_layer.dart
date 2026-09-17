import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../engine/table_state.dart';
import '../../ui/game_theme.dart';
import '../table_layout.dart';
import 'chips.dart';

/// 테이블 위의 칩 전부. 가운데 팟과 자리 앞에 나와 있는 베팅을 그린다.
///
/// 자리마다 컴포넌트를 두지 않고 한 겹에서 몰아 그린다. 칩은 서로 겹쳐 보여야
/// 자연스럽고, 그리는 순서를 한곳에서 정하는 편이 간단하다.
class ChipsLayer extends PositionComponent {
  ChipsLayer({required this.layout}) : super(priority: 3);

  TableLayout layout;

  TableState? state;

  double _builtForWidth = -1;
  late TextPaint _potPaint;
  late TextPaint _betPaint;

  @override
  void render(Canvas canvas) {
    final table = state;
    if (table == null) {
      return;
    }
    _ensureTextPaints();
    final unit = layout.cardWidth * 0.30;

    for (final seat in table.seats) {
      if (seat.roundBet <= 0) {
        continue;
      }
      final at = layout.betPosition(seat.index);
      renderChipStack(
        canvas,
        Offset(at.x, at.y),
        seat.roundBet,
        radius: unit,
      );
      _betPaint.render(
        canvas,
        formatChips(seat.roundBet),
        Vector2(at.x, at.y + unit * 1.1),
        anchor: Anchor.topCenter,
      );
    }

    final pot = table.pot;
    if (pot <= 0) {
      return;
    }
    // 칩 더미와 금액을 한 줄로 나란히 둔다. 세로로 쌓으면 그만큼 위아래를
    // 더 먹어서 보드나 홀 카드와 부딪힌다.
    final at = layout.potPosition;
    final radius = unit * 1.25;
    final label = '팟 ${formatChips(pot)}';
    final labelWidth = _potPaint.getLineMetrics(label).width;
    final gap = unit * 0.7;
    final left = at.x - (radius * 2 + gap + labelWidth) / 2;

    renderChipStack(canvas, Offset(left + radius, at.y), pot, radius: radius);
    _potPaint.render(
      canvas,
      label,
      Vector2(left + radius * 2 + gap, at.y),
      anchor: Anchor.centerLeft,
    );
  }

  void _ensureTextPaints() {
    if (_builtForWidth == layout.boardCardWidth) {
      return;
    }
    _builtForWidth = layout.boardCardWidth;
    _potPaint = TextPaint(
      style: TextStyle(
        fontFamily: kFontFamily,
        color: GamePalette.textPrimary,
        fontSize: layout.boardCardWidth * 0.34,
        height: 1,
        fontWeight: FontWeight.w800,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        shadows: const <Shadow>[
          Shadow(color: Color(0xCC000000), blurRadius: 4),
        ],
      ),
    );
    _betPaint = TextPaint(
      style: TextStyle(
        fontFamily: kFontFamily,
        color: GamePalette.textSecondary,
        fontSize: layout.boardCardWidth * 0.26,
        height: 1,
        fontWeight: FontWeight.w700,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        shadows: const <Shadow>[
          Shadow(color: Color(0xCC000000), blurRadius: 3),
        ],
      ),
    );
  }
}
