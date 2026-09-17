import 'package:meta/meta.dart';

import 'hand_rank.dart';

/// 팟 하나가 누구에게 갔는지.
@immutable
class PotAward {
  const PotAward({
    required this.label,
    required this.amount,
    required this.winnerSeats,
  });

  /// "메인 팟", "사이드 팟 1" 같은 이름.
  final String label;

  final int amount;

  /// 나눠 가진 자리들. 둘 이상이면 무승부다.
  final List<int> winnerSeats;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'amount': amount,
    'winnerSeats': winnerSeats,
  };

  factory PotAward.fromJson(Map<String, dynamic> json) => PotAward(
    label: '${json['label'] ?? ''}',
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    winnerSeats: <int>[
      for (final value in (json['winnerSeats'] as List<dynamic>? ?? const []))
        (value as num).toInt(),
    ],
  );
}

/// 핸드가 끝난 결과. 결과 창이 이 값 하나만 보고 그려진다.
@immutable
class HandResult {
  const HandResult({
    required this.wentToShowdown,
    required this.awards,
    required this.winnings,
    required this.rankings,
  });

  /// 카드를 까고 이겼는가. 거짓이면 나머지가 다 폴드해서 이긴 것이다.
  final bool wentToShowdown;

  final List<PotAward> awards;

  /// 자리 번호 → 이번 핸드에 받은 칩.
  final Map<int, int> winnings;

  /// 자리 번호 → 공개된 족보. 쇼다운까지 간 자리만 들어 있다.
  final Map<int, HandRank> rankings;

  List<int> get winnerSeats => <int>{
    for (final award in awards) ...award.winnerSeats,
  }.toList();

  int get totalAwarded =>
      awards.fold(0, (sum, award) => sum + award.amount);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'wentToShowdown': wentToShowdown,
    'awards': <Map<String, dynamic>>[
      for (final award in awards) award.toJson(),
    ],
    'winnings': <String, int>{
      for (final entry in winnings.entries) '${entry.key}': entry.value,
    },
    'rankings': <String, dynamic>{
      for (final entry in rankings.entries) '${entry.key}': entry.value.toJson(),
    },
  };

  factory HandResult.fromJson(Map<String, dynamic> json) => HandResult(
    wentToShowdown: json['wentToShowdown'] as bool? ?? false,
    awards: <PotAward>[
      for (final award in (json['awards'] as List<dynamic>? ?? const []))
        PotAward.fromJson(Map<String, dynamic>.from(award as Map)),
    ],
    winnings: <int, int>{
      for (final entry
          in (json['winnings'] as Map<dynamic, dynamic>? ?? const {}).entries)
        int.parse('${entry.key}'): (entry.value as num).toInt(),
    },
    rankings: <int, HandRank>{
      for (final entry
          in (json['rankings'] as Map<dynamic, dynamic>? ?? const {}).entries)
        int.parse('${entry.key}'): HandRankCodec.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        ),
    },
  );
}
