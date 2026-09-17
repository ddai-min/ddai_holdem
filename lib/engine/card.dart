import 'package:meta/meta.dart';

/// 트럼프 무늬. 홀덤에서 무늬끼리는 우열이 없다.
///
/// [code]는 저장·전송용 한 글자다. 카드 한 장을 `"As"`, `"Td"` 같은 두 글자로
/// 줄여 두면 Firestore 문서와 로그가 그대로 읽힌다.
enum Suit {
  spades('s', '♠'),
  hearts('h', '♥'),
  diamonds('d', '♦'),
  clubs('c', '♣');

  const Suit(this.code, this.symbol);

  final String code;
  final String symbol;

  bool get isRed => this == Suit.hearts || this == Suit.diamonds;

  static Suit fromCode(String code) {
    for (final suit in values) {
      if (suit.code == code) {
        return suit;
      }
    }
    throw FormatException('알 수 없는 무늬입니다: $code');
  }
}

/// 카드 숫자. [value]가 클수록 강하고 에이스가 14로 가장 세다.
///
/// 에이스를 1로 치는 경우는 A-2-3-4-5 스트레이트뿐이고, 그 예외는
/// `HandEvaluator`가 따로 다룬다. 그래서 여기서는 항상 14로 둔다.
enum Rank {
  two(2, '2'),
  three(3, '3'),
  four(4, '4'),
  five(5, '5'),
  six(6, '6'),
  seven(7, '7'),
  eight(8, '8'),
  nine(9, '9'),
  ten(10, 'T'),
  jack(11, 'J'),
  queen(12, 'Q'),
  king(13, 'K'),
  ace(14, 'A');

  const Rank(this.value, this.code);

  /// 2~14. 높을수록 강하다.
  final int value;

  /// 저장·전송용 한 글자. 10만 `T`로 줄인다.
  final String code;

  /// 족보 설명에 쓰는 한국어 이름.
  String get label => switch (this) {
    Rank.jack => 'J',
    Rank.queen => 'Q',
    Rank.king => 'K',
    Rank.ace => 'A',
    _ => '$value',
  };

  static Rank fromValue(int value) {
    for (final rank in values) {
      if (rank.value == value) {
        return rank;
      }
    }
    throw ArgumentError.value(value, 'value', '카드 숫자는 2~14여야 합니다');
  }

  static Rank fromCode(String code) {
    for (final rank in values) {
      if (rank.code == code) {
        return rank;
      }
    }
    throw FormatException('알 수 없는 숫자입니다: $code');
  }
}

/// 카드 한 장.
@immutable
class PlayingCard implements Comparable<PlayingCard> {
  const PlayingCard(this.rank, this.suit);

  /// `"As"`, `"Td"` 같은 두 글자 표기를 카드로 되돌린다.
  factory PlayingCard.fromCode(String code) {
    if (code.length != 2) {
      throw FormatException('카드 표기는 두 글자여야 합니다: $code');
    }
    return PlayingCard(Rank.fromCode(code[0]), Suit.fromCode(code[1]));
  }

  final Rank rank;
  final Suit suit;

  int get value => rank.value;

  /// 저장·전송용 두 글자 표기.
  String get code => '${rank.code}${suit.code}';

  /// 화면에 띄우는 표기.
  String get label => '${rank.label}${suit.symbol}';

  /// 숫자만 비교한다. 무늬는 홀덤에서 순위를 가르지 않는다.
  @override
  int compareTo(PlayingCard other) => rank.value.compareTo(other.rank.value);

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);

  @override
  String toString() => code;
}

/// 카드 목록을 `["As","Kd"]` 꼴로 바꾼다.
List<String> encodeCards(Iterable<PlayingCard> cards) =>
    cards.map((card) => card.code).toList(growable: false);

/// `["As","Kd"]`를 카드 목록으로 되돌린다.
List<PlayingCard> decodeCards(Iterable<dynamic> codes) =>
    codes.map((code) => PlayingCard.fromCode('$code')).toList(growable: false);
