import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../../engine/card.dart';
import '../../ui/game_theme.dart';

/// 카드 한 장을 그리는 컴포넌트.
///
/// 뒤집기는 가로 폭을 0까지 줄였다가 다시 펴면서 중간에 면을 바꾸는 방식이다.
/// 실제 3D 회전은 필요 없고, 이 정도로도 카드가 넘어가는 느낌이 난다.
class CardComponent extends PositionComponent {
  CardComponent({
    required Vector2 size,
    this.card,
    this.faceUp = false,
    super.position,
    super.priority,
  }) : _flip = faceUp ? 1 : 0,
       super(size: size, anchor: Anchor.center);

  static const double _flipSpeed = 4.2;

  /// 어떤 카드인지. 남의 뒷면 카드는 정체를 모르니 null로 둔다.
  PlayingCard? card;

  /// 앞면을 보여 줄지. 바꾸면 [update]가 알아서 뒤집는다.
  bool faceUp;

  /// 이 자리에 카드가 놓여 있는가. 거짓이면 아무것도 그리지 않는다.
  bool present = false;

  /// 지금 보이는 면. 0이 뒷면, 1이 앞면이다.
  double _flip;

  /// 폴드한 사람의 카드를 흐리게 만드는 정도.
  double dim = 0;

  /// 쇼다운에서 이긴 패를 이루는 카드인가.
  bool highlighted = false;

  double _builtForWidth = -1;
  late TextPaint _cornerPaint;
  late TextPaint _centerPaint;
  Color _inkColor = GamePalette.suitBlack;

  /// 어떤 카드를 어느 면으로 보여 줄지 정한다.
  ///
  /// [animate]가 거짓이면 뒤집는 모습 없이 그 상태로 바로 놓는다. 화면을 다시
  /// 그릴 때 이미 열려 있던 카드가 매번 다시 뒤집히면 산만하다.
  void show(
    PlayingCard? next, {
    required bool present,
    required bool faceUp,
    bool animate = true,
  }) {
    // 정체를 모르는 카드는 뒤집을 수 없다.
    final showFace = faceUp && next != null;
    final arriving = present && !this.present;
    card = next;
    this.present = present;

    if (arriving) {
      // 막 놓인 카드는 늘 뒷면에서 시작한다. 앞면이어야 하면 [update]가
      // 넘기면서 딜러가 까 주는 모습이 된다.
      _flip = 0;
      this.faceUp = showFace;
      return;
    }
    if (showFace == this.faceUp) {
      // 바뀐 것이 없다. 뒤집는 중이라면 건드리지 않고 그대로 두어야 한다.
      // 상태가 올 때마다 여기서 _flip을 덮어쓰면 애니메이션이 매번 끊긴다.
      return;
    }
    this.faceUp = showFace;
    if (!animate) {
      _flip = showFace ? 1 : 0;
    }
  }

  /// [from]에서 제자리까지 날아오게 한다. 플랍이 깔릴 때 쓴다.
  void dealFrom(Vector2 from) {
    final target = position.clone();
    position = from.clone();
    add(
      MoveToEffect(
        target,
        EffectController(duration: 0.26, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    final target = faceUp ? 1.0 : 0.0;
    if (_flip == target) {
      return;
    }
    final step = _flipSpeed * dt;
    _flip = (target - _flip).abs() <= step
        ? target
        : _flip + (target > _flip ? step : -step);
  }

  @override
  void render(Canvas canvas) {
    if (!present) {
      return;
    }
    final card = this.card;
    _ensureTextPaints(card);

    // 폭만 줄였다 펴면서 중간에 면을 바꾼다.
    final squeeze = math.max(((_flip * 2) - 1).abs(), 0.02);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(squeeze, 1);
    canvas.translate(-size.x / 2, -size.y / 2);

    if (_flip >= 0.5 && card != null) {
      _renderFace(canvas, card);
    } else {
      _renderBack(canvas);
    }

    if (dim > 0) {
      canvas.drawRRect(
        _rounded(0),
        Paint()..color = GamePalette.background.withValues(alpha: 0.62 * dim),
      );
    }
    canvas.restore();
  }

  RRect _rounded(double inset) => RRect.fromRectAndRadius(
    Rect.fromLTWH(inset, inset, size.x - inset * 2, size.y - inset * 2),
    Radius.circular(size.x * 0.14),
  );

  void _renderFace(Canvas canvas, PlayingCard card) {
    canvas.drawRRect(_rounded(0), Paint()..color = GamePalette.cardFace);
    canvas.drawRRect(
      _rounded(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = highlighted ? GamePalette.accent : GamePalette.cardEdge,
    );
    if (highlighted) {
      canvas.drawRRect(
        _rounded(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = GamePalette.accent.withValues(alpha: 0.85),
      );
    }

    final pad = size.x * 0.12;
    _cornerPaint.render(
      canvas,
      card.rank.label,
      Vector2(pad, pad * 0.7),
      anchor: Anchor.topLeft,
    );
    _centerPaint.render(
      canvas,
      card.suit.symbol,
      Vector2(size.x * 0.58, size.y * 0.62),
      anchor: Anchor.center,
    );
  }

  void _renderBack(Canvas canvas) {
    canvas.drawRRect(_rounded(0), Paint()..color = GamePalette.cardBack);
    canvas.drawRRect(
      _rounded(size.x * 0.1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, size.x * 0.035)
        ..color = GamePalette.cardBackPattern,
    );
    // 등 무늬 대신 얇은 사선 몇 줄. 작게 줄여도 뭉개지지 않는다.
    final linePaint = Paint()
      ..color = GamePalette.cardBackPattern.withValues(alpha: 0.7)
      ..strokeWidth = math.max(0.6, size.x * 0.02);
    canvas.save();
    canvas.clipRRect(_rounded(size.x * 0.18));
    for (var x = -size.y; x < size.x; x += size.x * 0.22) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.y, size.y), linePaint);
    }
    canvas.restore();
  }

  void _ensureTextPaints(PlayingCard? card) {
    final ink = card != null && card.suit.isRed
        ? GamePalette.suitRed
        : GamePalette.suitBlack;
    if (_builtForWidth == size.x && _inkColor == ink) {
      return;
    }
    _builtForWidth = size.x;
    _inkColor = ink;
    _cornerPaint = TextPaint(
      style: TextStyle(
        color: ink,
        fontSize: size.x * 0.42,
        height: 1,
        fontWeight: FontWeight.w800,
      ),
    );
    _centerPaint = TextPaint(
      style: TextStyle(
        color: ink,
        fontSize: size.x * 0.56,
        height: 1,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
