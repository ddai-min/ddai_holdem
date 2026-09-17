import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../engine/card.dart';
import '../../engine/seat.dart';
import '../../ui/game_theme.dart';
import '../table_layout.dart';
import 'card_component.dart';

/// 자리 하나. 이름표와 스택, 홀 카드 두 장, 남은 시간을 보여 준다.
///
/// 이름표는 늘 화면 안쪽에 있고, 카드는 이름표 뒤에서 위로 살짝 고개만 내민다.
/// 좁은 화면에서도 자리가 잘리지 않게 하려는 배치다.
class SeatComponent extends PositionComponent {
  SeatComponent({required this.seatIndex, required this.layout})
    : super(anchor: Anchor.center, priority: 10);

  final int seatIndex;

  /// 지금 화면 크기에 맞춰 계산된 배치. 화면이 바뀌면 [applyLayout]이 갈아 낀다.
  TableLayout layout;

  PlayerSeat? data;
  bool isViewer = false;
  bool isActing = false;
  bool isWinner = false;
  int? deadlineMs;
  int actionSeconds = 30;

  late final CardComponent _left = CardComponent(size: Vector2.zero());
  late final CardComponent _right = CardComponent(size: Vector2.zero());

  double _builtForWidth = -1;
  late TextPaint _namePaint;
  late TextPaint _chipsPaint;
  late TextPaint _actionPaint;

  @override
  Future<void> onLoad() async {
    _left.priority = -1;
    _right.priority = -1;
    // onLoad 안에서 add를 기다리면 마운트를 기다리다 그대로 멈춘다.
    addAll(<Component>[_left, _right]);
    applyLayout(layout);
  }

  /// 화면 크기가 바뀌었다. 자리와 카드를 다시 앉힌다.
  void applyLayout(TableLayout next) {
    layout = next;
    position = layout.seatPosition(seatIndex);
    size = Vector2(layout.cardWidth * 2.85, layout.cardWidth * 1.34);

    final cardSize = isViewer
        ? Vector2(layout.ownCardWidth, layout.ownCardHeight)
        : Vector2(layout.holeCardWidth, layout.holeCardHeight);
    // 이름표 위로 카드가 얼마나 고개를 내밀지. 내 카드는 통째로 보여 준다.
    final peek = isViewer ? cardSize.y * 0.62 : cardSize.y * 0.42;
    final spread = cardSize.x * 0.56;

    for (final (index, card) in <CardComponent>[_left, _right].indexed) {
      card
        ..size = cardSize
        ..position = Vector2(
          size.x / 2 + (index == 0 ? -spread : spread),
          size.y / 2 - size.y * 0.5 - peek,
        )
        ..angle = (index == 0 ? -1 : 1) * 0.06;
    }
  }

  /// 이번 프레임에 보여 줄 값들을 한 번에 넣는다.
  void apply({
    required PlayerSeat? seat,
    required bool viewer,
    required bool acting,
    required bool winner,
    required int? deadline,
    required int seconds,
    required Set<PlayingCard> highlight,
  }) {
    final layoutChanged = viewer != isViewer;
    data = seat;
    isViewer = viewer;
    isActing = acting;
    isWinner = winner;
    deadlineMs = deadline;
    actionSeconds = seconds;
    if (layoutChanged) {
      applyLayout(layout);
    }

    final cards = seat?.holeCards ?? const [];
    final inHand = seat != null && seat.inHand;
    final dim = seat != null && seat.hasFolded ? 1.0 : 0.0;

    final reveal = viewer || (seat?.revealed ?? false);
    for (final (index, slot) in <CardComponent>[_left, _right].indexed) {
      final card = index < cards.length ? cards[index] : null;
      slot
        ..dim = dim
        ..highlighted = card != null && highlight.contains(card)
        // 카드를 받지 않은 자리에는 아무것도 놓지 않는다. 받았지만 정체를
        // 모르는 남의 카드는 뒷면으로 놓는다.
        ..show(card, present: inHand, faceUp: reveal);
    }
  }

  @override
  void render(Canvas canvas) {
    final seat = data;
    if (seat == null || !seat.isOccupied) {
      _renderEmpty(canvas);
      return;
    }
    _ensureTextPaints();

    final folded = seat.hasFolded;
    final radius = Radius.circular(size.y * 0.30);
    final plate = RRect.fromRectAndRadius(size.toRect(), radius);

    canvas.drawRRect(
      plate,
      Paint()
        ..color = folded
            ? GamePalette.seatFolded.withValues(alpha: 0.85)
            : GamePalette.seatIdle,
    );
    canvas.drawRRect(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActing || isWinner ? 2.2 : 1
        ..color = isWinner
            ? GamePalette.seatWinner
            : isActing
            ? GamePalette.seatActive
            : GamePalette.border,
    );

    final alpha = folded ? 0.45 : 1.0;
    _namePaint.render(
      canvas,
      seat.connected ? seat.name : '${seat.name} (끊김)',
      Vector2(size.x / 2, size.y * 0.32),
      anchor: Anchor.center,
    );
    _chipsPaint.render(
      canvas,
      seat.sittingOut && seat.chips <= 0 ? '칩 없음' : formatChips(seat.chips),
      Vector2(size.x / 2, size.y * 0.68),
      anchor: Anchor.center,
    );
    if (alpha < 1) {
      canvas.drawRRect(
        plate,
        Paint()..color = GamePalette.background.withValues(alpha: 0.45),
      );
    }

    if (isActing) {
      _renderTimer(canvas);
    }
    final label = seat.lastActionLabel;
    if (label != null && label.isNotEmpty) {
      _renderActionPill(canvas, label);
    }
  }

  void _renderEmpty(Canvas canvas) {
    _ensureTextPaints();
    final plate = RRect.fromRectAndRadius(
      size.toRect().deflate(size.y * 0.16),
      Radius.circular(size.y * 0.24),
    );
    canvas.drawRRect(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = GamePalette.border.withValues(alpha: 0.55),
    );
    _namePaint.render(
      canvas,
      '빈자리',
      Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
    );
  }

  /// 이름표 아래쪽에 남은 시간을 띠로 그린다.
  void _renderTimer(Canvas canvas) {
    final deadline = deadlineMs;
    if (deadline == null) {
      return;
    }
    final remaining = deadline - DateTime.now().millisecondsSinceEpoch;
    final ratio = (remaining / (actionSeconds * 1000)).clamp(0.0, 1.0);
    final inset = size.x * 0.10;
    final width = (size.x - inset * 2) * ratio;
    final top = size.y - size.y * 0.16;
    final height = size.y * 0.075;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inset, top, size.x - inset * 2, height),
        Radius.circular(height),
      ),
      Paint()..color = GamePalette.background.withValues(alpha: 0.6),
    );
    if (width <= 0) {
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inset, top, width, height),
        Radius.circular(height),
      ),
      Paint()
        ..color = ratio < 0.25 ? GamePalette.danger : GamePalette.seatActive,
    );
  }

  /// 마지막 행동을 이름표 아래 테두리에 걸치는 알약으로 띄운다.
  void _renderActionPill(Canvas canvas, String label) {
    final height = size.y * 0.40;
    final width = math.max(size.x * 0.44, label.length * height * 0.44);
    final rect = Rect.fromCenter(
      center: Offset(size.x / 2, size.y),
      width: width,
      height: height,
    );
    final pill = RRect.fromRectAndRadius(rect, Radius.circular(height / 2));
    canvas.drawRRect(pill, Paint()..color = GamePalette.surfaceHigh);
    canvas.drawRRect(
      pill,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = GamePalette.border,
    );
    _actionPaint.render(
      canvas,
      label,
      Vector2(rect.center.dx, rect.center.dy),
      anchor: Anchor.center,
    );
  }

  void _ensureTextPaints() {
    if (_builtForWidth == size.x) {
      return;
    }
    _builtForWidth = size.x;
    final unit = size.y;
    _namePaint = TextPaint(
      style: TextStyle(
        fontFamily: kFontFamily,
        color: GamePalette.textSecondary,
        fontSize: unit * 0.24,
        height: 1,
        fontWeight: FontWeight.w600,
      ),
    );
    _chipsPaint = TextPaint(
      style: TextStyle(
        fontFamily: kFontFamily,
        color: GamePalette.textPrimary,
        fontSize: unit * 0.32,
        height: 1,
        fontWeight: FontWeight.w800,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
    _actionPaint = TextPaint(
      style: TextStyle(
        fontFamily: kFontFamily,
        color: GamePalette.accent,
        fontSize: unit * 0.24,
        height: 1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
