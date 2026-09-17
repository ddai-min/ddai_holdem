import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:meta/meta.dart';

/// 화면 크기에 맞춰 테이블과 자리의 좌표를 계산한다.
///
/// 세로로 긴 휴대폰과 가로로 넓은 데스크탑을 한 벌의 코드로 감당해야 해서,
/// 고정 해상도를 쓰지 않고 매번 화면 비율을 보고 타원을 새로 그린다. 내 자리는
/// 언제나 화면 아래 가운데로 오도록 자리 번호를 돌려서 쓴다.
///
/// 지름을 정하는 순서가 중요하다. 먼저 이름표가 화면 밖으로 밀리지 않을 만큼
/// 여백을 떼어 내고, 그다음 테이블이 지나치게 길쭉해지지 않도록 가로세로 비를
/// 잡는다. 이 두 단계를 거치면 어떤 비율의 화면에서도 자리가 잘리지 않으면서
/// 테이블 모양이 유지된다.
@immutable
class TableLayout {
  const TableLayout._({
    required this.size,
    required this.seatCount,
    required this.viewerSeat,
    required this.cardWidth,
    required this.boardCardWidth,
    required this.railWidth,
    required this.feltRadiusX,
    required this.feltRadiusY,
    required this.center,
  });

  factory TableLayout({
    required Vector2 size,
    required int seatCount,
    required int viewerSeat,
  }) {
    final cardWidth = _clamp(
      math.min(size.x * 0.10, size.y * 0.095),
      26,
      68,
    );
    final railWidth = _clamp(math.min(size.x, size.y) * 0.030, 8, 26);

    // 자리 하나가 차지하는 크기의 절반.
    final seatHalfWidth = cardWidth * 1.48;

    // 위아래로 필요한 여백은 다르다. 위쪽 자리들은 이름표 위로 카드가 고개를
    // 내밀어 자리를 많이 먹지만, 아래쪽 내 자리는 카드가 테이블 안쪽(위)으로
    // 뻗으므로 이름표와 행동 알약만큼만 있으면 된다.
    final topInset = cardWidth * 1.72;
    final bottomInset = cardWidth * 0.95;
    final usableHeight = math.max(140.0, size.y - topInset - bottomInset);
    final centerY = topInset + usableHeight / 2;

    var radiusX = math.max(
      70.0,
      size.x / 2 - seatHalfWidth - railWidth * 1.15 - 4,
    );
    var radiusY = math.max(
      60.0,
      usableHeight / 2 - railWidth * 1.15 - 4,
    );
    // 세로로 긴 화면에서 타원이 국수 가락처럼 늘어나는 것을 막는다.
    radiusY = math.min(radiusY, radiusX * 2.05);
    radiusX = math.min(radiusX, radiusY * 2.2);

    // 커뮤니티 다섯 장이 펠트 안에 들어와야 한다. 좁으면 그만큼 줄인다.
    final boardCardWidth = math.min(cardWidth, radiusX * 1.72 / (5 * 1.12));

    return TableLayout._(
      size: size,
      seatCount: seatCount,
      viewerSeat: viewerSeat,
      cardWidth: cardWidth,
      boardCardWidth: boardCardWidth,
      railWidth: railWidth,
      feltRadiusX: radiusX,
      feltRadiusY: radiusY,
      center: Vector2(size.x / 2, centerY),
    );
  }

  final Vector2 size;
  final int seatCount;

  /// 화면 아래 가운데에 놓을 자리 번호. 관전 중이면 0.
  final int viewerSeat;

  /// 자리에 놓이는 카드의 기준 폭.
  final double cardWidth;

  /// 가운데 깔리는 커뮤니티 카드의 폭.
  final double boardCardWidth;

  final double railWidth;
  final double feltRadiusX;
  final double feltRadiusY;

  /// 테이블의 한가운데. 위아래 여백이 다르므로 화면 정중앙은 아니다.
  final Vector2 center;

  bool get isPortrait => size.y > size.x;

  double get cardHeight => boardCardWidth * 1.42;

  /// 남의 자리에 놓이는 홀 카드는 조금 작게.
  double get holeCardWidth => cardWidth * 0.78;

  double get holeCardHeight => holeCardWidth * 1.42;

  /// 내 자리에 놓이는 홀 카드.
  double get ownCardWidth => cardWidth;

  double get ownCardHeight => cardWidth * 1.42;

  /// 내 자리를 아래 가운데로 옮긴 뒤의 보기 순번.
  int viewIndexOf(int seatIndex) =>
      (seatIndex - viewerSeat + seatCount * 2) % seatCount;

  /// 타원 위에서 자리가 놓이는 각도. 화면 아래(+y)가 0번이다.
  double _angleOf(int seatIndex) =>
      math.pi / 2 + 2 * math.pi * viewIndexOf(seatIndex) / seatCount;

  /// 자리(이름표)의 중심. 레일에 살짝 걸터앉은 자리가 된다.
  Vector2 seatPosition(int seatIndex) {
    final angle = _angleOf(seatIndex);
    return center +
        Vector2(
          math.cos(angle) * (feltRadiusX + railWidth * 1.15),
          math.sin(angle) * (feltRadiusY + railWidth * 1.15),
        );
  }

  /// 자리 앞에 내놓은 칩이 놓이는 자리. 자리와 테이블 가운데 사이다.
  Vector2 betPosition(int seatIndex) {
    final angle = _angleOf(seatIndex);
    return center +
        Vector2(
          math.cos(angle) * feltRadiusX * 0.62,
          math.sin(angle) * feltRadiusY * 0.60,
        );
  }

  /// 커뮤니티 카드 다섯 장이 놓이는 자리.
  Vector2 communityPosition(int index) {
    final gap = boardCardWidth * 1.12;
    return Vector2(center.x + (index - 2) * gap, center.y - cardHeight * 0.10);
  }

  /// 팟 표시가 놓이는 자리.
  ///
  /// 보드 위쪽이다. 아래는 내 홀 카드가 테이블 안쪽으로 뻗어 오는 자리라
  /// 팟을 두면 가려진다.
  Vector2 get potPosition => Vector2(center.x, center.y - cardHeight * 0.98);

  /// 딜러 버튼이 놓이는 자리.
  Vector2 dealerButtonPosition(int seatIndex) {
    final angle = _angleOf(seatIndex);
    return center +
        Vector2(
          math.cos(angle - 0.36) * feltRadiusX * 0.70,
          math.sin(angle - 0.36) * feltRadiusY * 0.70,
        );
  }

  /// 카드를 나눠 줄 때 출발하는 자리.
  Vector2 get dealerPosition => Vector2(center.x, center.y - feltRadiusY * 0.66);

  static double _clamp(double value, double low, double high) =>
      value < low ? low : (value > high ? high : value);
}
