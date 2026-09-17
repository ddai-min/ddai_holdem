import 'package:meta/meta.dart';

import 'seat.dart';

/// 팟 하나. 누가 가져갈 자격이 있는지를 함께 들고 다닌다.
///
/// 올인한 사람이 있으면 팟이 여러 개로 갈린다. 500칩만 가진 사람이 올인했는데
/// 다른 둘이 2000까지 올렸다면, 500씩 모인 메인 팟은 셋 다 노릴 수 있지만
/// 나머지 1500씩이 모인 사이드 팟은 둘만 노릴 수 있다.
@immutable
class Pot {
  const Pot({required this.amount, required this.eligibleSeats});

  final int amount;

  /// 이 팟을 가져갈 수 있는 자리 번호들.
  final List<int> eligibleSeats;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'amount': amount,
    'eligibleSeats': eligibleSeats,
  };

  factory Pot.fromJson(Map<String, dynamic> json) => Pot(
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    eligibleSeats: <int>[
      for (final value in (json['eligibleSeats'] as List<dynamic>? ?? const []))
        (value as num).toInt(),
    ],
  );
}

/// 지금까지 자리별로 낸 칩을 보고 메인 팟과 사이드 팟을 나눈다.
///
/// 낸 금액이 같은 사람끼리 층을 이룬다고 보고, 낮은 층부터 차곡차곡 쌓는다.
/// 폴드한 사람이 낸 칩도 팟에는 그대로 들어가지만 가져갈 자격은 없다.
List<Pot> buildPots(List<PlayerSeat> seats) {
  final levels = <int>{
    for (final seat in seats)
      if (seat.handBet > 0) seat.handBet,
  }.toList()..sort();

  final pots = <Pot>[];
  var previous = 0;
  // 살아남은 사람이 아무도 없는 층이 생기면(정상 진행에서는 나오지 않는다)
  // 그 칩을 다음 팟에 얹어 준다. 어떤 경우에도 칩이 사라지지 않게 하는 안전장치다.
  var carry = 0;

  for (final level in levels) {
    final band = level - previous;
    var amount = carry;
    final eligible = <int>[];

    for (final seat in seats) {
      final paid = seat.handBet < level ? seat.handBet : level;
      final contribution = paid - previous;
      if (contribution > 0) {
        amount += contribution < band ? contribution : band;
      }
      if (seat.isActive && seat.handBet >= level) {
        eligible.add(seat.index);
      }
    }

    if (amount > 0 && eligible.isNotEmpty) {
      pots.add(Pot(amount: amount, eligibleSeats: eligible));
      carry = 0;
    } else {
      carry = amount;
    }
    previous = level;
  }

  if (carry > 0 && pots.isNotEmpty) {
    final last = pots.removeLast();
    pots.add(Pot(amount: last.amount + carry, eligibleSeats: last.eligibleSeats));
  }
  return _mergeSameEligibility(pots);
}

/// 가져갈 사람이 똑같은 팟끼리는 하나로 합친다.
///
/// 폴드한 사람이 남기고 간 칩 때문에 층이 갈리는 일이 흔한데, 자격이 같다면
/// 나눠 둘 이유가 없다. 합쳐 두면 화면에도 "팟 하나"로 정직하게 보인다.
List<Pot> _mergeSameEligibility(List<Pot> pots) {
  final merged = <Pot>[];
  for (final pot in pots) {
    final previous = merged.isEmpty ? null : merged.last;
    if (previous != null &&
        _sameSeats(previous.eligibleSeats, pot.eligibleSeats)) {
      merged[merged.length - 1] = Pot(
        amount: previous.amount + pot.amount,
        eligibleSeats: previous.eligibleSeats,
      );
    } else {
      merged.add(pot);
    }
  }
  return merged;
}

bool _sameSeats(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}
