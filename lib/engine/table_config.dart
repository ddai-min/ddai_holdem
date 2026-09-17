import 'package:meta/meta.dart';

/// 한 테이블의 규칙. 방을 만들 때 정하고 게임 도중에는 바뀌지 않는다.
@immutable
class TableConfig {
  const TableConfig({
    this.smallBlind = 10,
    this.bigBlind = 20,
    this.startingChips = 2000,
    this.maxSeats = 6,
    this.actionSeconds = 30,
  }) : assert(smallBlind > 0, '스몰 블라인드는 1칩 이상이어야 합니다.'),
       assert(bigBlind >= smallBlind, '빅 블라인드가 스몰 블라인드보다 작을 수는 없습니다.'),
       assert(startingChips >= bigBlind * 10, '시작 칩은 빅 블라인드의 10배 이상이어야 합니다.'),
       assert(maxSeats >= 2 && maxSeats <= 9, '한 테이블에는 2~9명이 앉습니다.');

  final int smallBlind;
  final int bigBlind;

  /// 참가할 때 나눠 주는 칩.
  final int startingChips;

  /// 테이블 좌석 수.
  final int maxSeats;

  /// 한 사람이 고민할 수 있는 시간(초). 넘기면 체크 또는 폴드로 처리한다.
  final int actionSeconds;

  TableConfig copyWith({
    int? smallBlind,
    int? bigBlind,
    int? startingChips,
    int? maxSeats,
    int? actionSeconds,
  }) => TableConfig(
    smallBlind: smallBlind ?? this.smallBlind,
    bigBlind: bigBlind ?? this.bigBlind,
    startingChips: startingChips ?? this.startingChips,
    maxSeats: maxSeats ?? this.maxSeats,
    actionSeconds: actionSeconds ?? this.actionSeconds,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'smallBlind': smallBlind,
    'bigBlind': bigBlind,
    'startingChips': startingChips,
    'maxSeats': maxSeats,
    'actionSeconds': actionSeconds,
  };

  factory TableConfig.fromJson(Map<String, dynamic> json) {
    int read(String key, int fallback) =>
        (json[key] as num?)?.toInt() ?? fallback;
    return TableConfig(
      smallBlind: read('smallBlind', 10),
      bigBlind: read('bigBlind', 20),
      startingChips: read('startingChips', 2000),
      maxSeats: read('maxSeats', 6),
      actionSeconds: read('actionSeconds', 30),
    );
  }
}
