import 'package:meta/meta.dart';

import 'card.dart';

/// 족보 종류. 선언 순서가 곧 강한 정도라서 [index]로 비교할 수 있다.
enum HandCategory {
  highCard('하이카드'),
  onePair('원페어'),
  twoPair('투페어'),
  threeOfAKind('트리플'),
  straight('스트레이트'),
  flush('플러시'),
  fullHouse('풀하우스'),
  fourOfAKind('포카드'),
  straightFlush('스트레이트 플러시');

  const HandCategory(this.label);

  final String label;
}

/// 5장으로 완성된 패의 순위.
///
/// [category]가 같으면 [tiebreakers]를 앞에서부터 비교한다. 종류마다 무엇을
/// 먼저 보는지가 달라서, 그 순서대로 미리 담아 둔 값이다. 예를 들어 투페어는
/// `[높은 페어, 낮은 페어, 키커]`, 스트레이트는 `[가장 높은 숫자]` 하나뿐이다.
@immutable
class HandRank implements Comparable<HandRank> {
  const HandRank({
    required this.category,
    required this.tiebreakers,
    required this.cards,
  });

  final HandCategory category;

  /// 같은 족보끼리 우열을 가르는 숫자들. 앞쪽이 더 중요하다.
  final List<int> tiebreakers;

  /// 실제로 쓰인 다섯 장. 쇼다운에서 어느 카드로 이겼는지 표시하는 데 쓴다.
  final List<PlayingCard> cards;

  @override
  int compareTo(HandRank other) {
    final byCategory = category.index.compareTo(other.category.index);
    if (byCategory != 0) {
      return byCategory;
    }
    for (var i = 0; i < tiebreakers.length; i++) {
      final mine = tiebreakers[i];
      final theirs = i < other.tiebreakers.length ? other.tiebreakers[i] : 0;
      if (mine != theirs) {
        return mine.compareTo(theirs);
      }
    }
    return 0;
  }

  bool operator >(HandRank other) => compareTo(other) > 0;

  bool operator <(HandRank other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) => other is HandRank && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(category, Object.hashAll(tiebreakers));

  /// "풀하우스 K over 7"처럼 사람이 읽는 한 줄 설명.
  String describe() {
    String name(int value) => Rank.fromValue(value).label;

    return switch (category) {
      HandCategory.highCard => '하이카드 ${name(tiebreakers[0])}',
      HandCategory.onePair => '${name(tiebreakers[0])} 원페어',
      HandCategory.twoPair =>
        '${name(tiebreakers[0])}·${name(tiebreakers[1])} 투페어',
      HandCategory.threeOfAKind => '${name(tiebreakers[0])} 트리플',
      HandCategory.straight => '${name(tiebreakers[0])} 하이 스트레이트',
      HandCategory.flush => '${name(tiebreakers[0])} 하이 플러시',
      HandCategory.fullHouse =>
        '${name(tiebreakers[0])} 풀하우스 (${name(tiebreakers[1])})',
      HandCategory.fourOfAKind => '${name(tiebreakers[0])} 포카드',
      HandCategory.straightFlush =>
        tiebreakers[0] == Rank.ace.value
            ? '로열 스트레이트 플러시'
            : '${name(tiebreakers[0])} 하이 스트레이트 플러시',
    };
  }

  @override
  String toString() => '${describe()} ${cards.map((c) => c.code).join(' ')}';
}

/// [HandRank]를 Firestore에 실을 수 있는 맵으로 바꾼다.
extension HandRankCodec on HandRank {
  Map<String, dynamic> toJson() => <String, dynamic>{
    'category': category.name,
    'tiebreakers': tiebreakers,
    'cards': encodeCards(cards),
  };

  static HandRank fromJson(Map<String, dynamic> json) => HandRank(
    category: HandCategory.values.byName('${json['category']}'),
    tiebreakers: <int>[
      for (final value in (json['tiebreakers'] as List<dynamic>? ?? const []))
        (value as num).toInt(),
    ],
    cards: decodeCards(json['cards'] as List<dynamic>? ?? const []),
  );
}
