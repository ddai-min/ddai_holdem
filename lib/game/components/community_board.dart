import 'package:flame/components.dart';

import '../../engine/card.dart';
import '../table_layout.dart';
import 'card_component.dart';

/// 가운데 깔리는 커뮤니티 카드 다섯 장.
class CommunityBoard extends PositionComponent {
  CommunityBoard({required this.layout}) : super(priority: 5);

  TableLayout layout;

  final List<CardComponent> _slots = <CardComponent>[];

  // 슬롯이 만들어지기 전에 들어온 카드. onLoad가 끝나면 그대로 얹는다.
  List<PlayingCard> _requested = const <PlayingCard>[];
  Set<PlayingCard> _requestedHighlight = const <PlayingCard>{};

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < 5; i++) {
      _slots.add(CardComponent(size: Vector2.zero()));
    }
    // onLoad 안에서 add를 기다리면 마운트를 기다리다 그대로 멈춘다.
    addAll(_slots);
    applyLayout(layout);
    show(_requested, highlighted: _requestedHighlight);
  }

  void applyLayout(TableLayout next) {
    layout = next;
    for (var i = 0; i < _slots.length; i++) {
      _slots[i]
        ..size = Vector2(layout.boardCardWidth, layout.cardHeight)
        ..position = layout.communityPosition(i);
    }
  }

  /// 지금까지 깔린 카드를 보여 준다.
  ///
  /// [highlighted]에 든 카드는 테를 둘러 이긴 패를 이루는 다섯 장을 짚어 준다.
  void show(
    List<PlayingCard> community, {
    Set<PlayingCard> highlighted = const <PlayingCard>{},
  }) {
    _requested = community;
    _requestedHighlight = highlighted;
    for (var i = 0; i < _slots.length; i++) {
      final card = i < community.length ? community[i] : null;
      final slot = _slots[i];
      final arriving = card != null && !slot.present;
      slot
        ..highlighted = highlighted.contains(card)
        ..show(card, present: card != null, faceUp: true);
      if (arriving) {
        slot.dealFrom(layout.dealerPosition);
      }
    }
  }
}
