import 'card.dart';
import 'hand_rank.dart';

/// 카드 뭉치에서 가장 센 다섯 장을 골라 족보를 매긴다.
abstract final class HandEvaluator {
  /// 홀 카드와 커뮤니티 카드를 합쳐 만들 수 있는 가장 센 패.
  ///
  /// 7장이면 다섯 장을 고르는 21가지 조합을 전부 매겨 보고 제일 센 것을 남긴다.
  /// "플러시가 있는데 스트레이트도 있다", "슈트가 6장이라 어느 다섯 장을
  /// 남길까" 같은 예외를 따로 다루지 않아도 되는 게 이 방식의 장점이다.
  static HandRank best(List<PlayingCard> cards) {
    if (cards.length < 5) {
      throw ArgumentError.value(cards.length, 'cards', '최소 5장이 필요합니다');
    }
    if (cards.length == 5) {
      return evaluate5(cards);
    }

    HandRank? winner;
    final chosen = List<PlayingCard>.filled(5, cards.first);

    void pick(int start, int depth) {
      if (depth == 5) {
        final rank = evaluate5(chosen);
        if (winner == null || rank > winner!) {
          winner = rank;
        }
        return;
      }
      // 남은 자리를 채울 만큼 카드가 남아 있는 지점까지만 훑는다.
      for (var i = start; i <= cards.length - (5 - depth); i++) {
        chosen[depth] = cards[i];
        pick(i + 1, depth + 1);
      }
    }

    pick(0, 0);
    return winner!;
  }

  /// 딱 다섯 장짜리 패의 순위.
  static HandRank evaluate5(List<PlayingCard> cards) {
    if (cards.length != 5) {
      throw ArgumentError.value(cards.length, 'cards', '5장이어야 합니다');
    }

    final sorted = cards.toList()..sort((a, b) => b.value.compareTo(a.value));
    final isFlush = sorted.every((card) => card.suit == sorted.first.suit);
    final straightHigh = _straightHigh(sorted);

    // 같은 숫자끼리 묶는다. 장수가 많은 쪽 → 숫자가 큰 쪽 순서다.
    // 이렇게 정렬해 두면 어느 족보든 앞에서부터 꺼내 쓰기만 하면 된다.
    final counts = <int, int>{};
    for (final card in sorted) {
      counts[card.value] = (counts[card.value] ?? 0) + 1;
    }
    final groups = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : b.key.compareTo(a.key);
      });
    final keys = groups.map((group) => group.key).toList(growable: false);

    if (isFlush && straightHigh != null) {
      return HandRank(
        category: HandCategory.straightFlush,
        tiebreakers: <int>[straightHigh],
        cards: _orderStraight(sorted, straightHigh),
      );
    }
    if (groups.first.value == 4) {
      return HandRank(
        category: HandCategory.fourOfAKind,
        tiebreakers: keys,
        cards: _orderGroups(sorted, keys),
      );
    }
    if (groups.first.value == 3 && groups[1].value == 2) {
      return HandRank(
        category: HandCategory.fullHouse,
        tiebreakers: keys,
        cards: _orderGroups(sorted, keys),
      );
    }
    if (isFlush) {
      return HandRank(
        category: HandCategory.flush,
        tiebreakers: _values(sorted),
        cards: sorted,
      );
    }
    if (straightHigh != null) {
      return HandRank(
        category: HandCategory.straight,
        tiebreakers: <int>[straightHigh],
        cards: _orderStraight(sorted, straightHigh),
      );
    }
    if (groups.first.value == 3) {
      return HandRank(
        category: HandCategory.threeOfAKind,
        tiebreakers: keys,
        cards: _orderGroups(sorted, keys),
      );
    }
    if (groups.first.value == 2) {
      return HandRank(
        category: groups[1].value == 2
            ? HandCategory.twoPair
            : HandCategory.onePair,
        tiebreakers: keys,
        cards: _orderGroups(sorted, keys),
      );
    }
    return HandRank(
      category: HandCategory.highCard,
      tiebreakers: _values(sorted),
      cards: sorted,
    );
  }

  /// 스트레이트면 가장 높은 숫자를, 아니면 null을 준다.
  static int? _straightHigh(List<PlayingCard> sortedDesc) {
    final values = sortedDesc.map((card) => card.value).toSet();
    if (values.length != 5) {
      return null;
    }
    if (sortedDesc.first.value - sortedDesc.last.value == 4) {
      return sortedDesc.first.value;
    }
    // A-2-3-4-5에서만 에이스를 1로 친다. 이때 제일 높은 숫자는 5다.
    if (values.containsAll(const <int>{14, 5, 4, 3, 2})) {
      return 5;
    }
    return null;
  }

  /// 스트레이트를 높은 숫자부터 늘어놓는다. A-2-3-4-5면 에이스가 맨 뒤로 간다.
  static List<PlayingCard> _orderStraight(
    List<PlayingCard> sortedDesc,
    int high,
  ) {
    if (high != 5) {
      return sortedDesc;
    }
    return <PlayingCard>[
      ...sortedDesc.where((card) => card.value != Rank.ace.value),
      sortedDesc.firstWhere((card) => card.value == Rank.ace.value),
    ];
  }

  /// 족보를 이루는 카드가 먼저 오도록 늘어놓는다. 예: 트리플 3장 → 키커 2장.
  static List<PlayingCard> _orderGroups(
    List<PlayingCard> sortedDesc,
    List<int> keys,
  ) => <PlayingCard>[
    for (final key in keys) ...sortedDesc.where((card) => card.value == key),
  ];

  static List<int> _values(List<PlayingCard> cards) =>
      cards.map((card) => card.value).toList(growable: false);
}
