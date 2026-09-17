import 'dart:math' as math;

import 'card.dart';

/// 52장짜리 덱. 위에서부터 한 장씩 뽑아 쓴다.
///
/// 남은 카드를 [toCodes]로 통째로 저장했다가 [Deck.fromCodes]로 되살릴 수 있다.
/// 방장 기기가 잠깐 죽었다 돌아와도 진행 중이던 핸드를 이어 가기 위한 장치다.
class Deck {
  Deck._(this._cards);

  /// 잘 섞은 새 덱.
  factory Deck.shuffled({math.Random? random}) {
    final cards = <PlayingCard>[
      for (final suit in Suit.values)
        for (final rank in Rank.values) PlayingCard(rank, suit),
    ];
    _shuffle(cards, random ?? math.Random.secure());
    return Deck._(cards);
  }

  /// 저장해 둔 표기 목록에서 덱을 되살린다.
  factory Deck.fromCodes(Iterable<dynamic> codes) =>
      Deck._(decodeCards(codes).toList());

  /// 정해진 순서대로 나오는 덱. 테스트에서 특정 상황을 만들 때 쓴다.
  factory Deck.stacked(List<PlayingCard> cards) => Deck._(cards.toList());

  final List<PlayingCard> _cards;

  int get remaining => _cards.length;

  bool get isEmpty => _cards.isEmpty;

  /// 맨 위 카드 한 장.
  PlayingCard draw() {
    if (_cards.isEmpty) {
      throw StateError('덱이 비었습니다.');
    }
    return _cards.removeAt(0);
  }

  /// 맨 위에서 [count]장.
  List<PlayingCard> drawMany(int count) =>
      List<PlayingCard>.generate(count, (_) => draw(), growable: false);

  /// 딜러가 카드를 태우는 절차. 실제 승부에는 영향이 없지만, 관례대로 남긴다.
  void burn() {
    if (_cards.isNotEmpty) {
      _cards.removeAt(0);
    }
  }

  List<String> toCodes() => encodeCards(_cards);

  /// Fisher-Yates. [math.Random.secure]를 넘기면 예측할 수 없게 섞인다.
  static void _shuffle(List<PlayingCard> cards, math.Random random) {
    for (var i = cards.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = cards[i];
      cards[i] = cards[j];
      cards[j] = temp;
    }
  }
}
