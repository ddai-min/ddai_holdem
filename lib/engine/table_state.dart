import 'card.dart';
import 'hand_result.dart';
import 'pot.dart';
import 'seat.dart';
import 'table_config.dart';

/// 핸드의 진행 단계.
enum HandPhase {
  /// 핸드와 핸드 사이. 아직 카드를 돌리지 않았다.
  waiting('대기 중'),

  /// 홀 카드 두 장만 받은 상태.
  preflop('프리플랍'),

  /// 커뮤니티 카드 세 장.
  flop('플랍'),

  /// 네 장.
  turn('턴'),

  /// 다섯 장.
  river('리버'),

  /// 패를 까고 팟을 나눈 상태.
  showdown('쇼다운');

  const HandPhase(this.label);

  final String label;

  /// 베팅을 주고받는 단계인가.
  bool get isBetting =>
      this == preflop || this == flop || this == turn || this == river;

  /// 이 단계에서 깔려 있어야 하는 커뮤니티 카드 수.
  int get communityCount => switch (this) {
    waiting || preflop => 0,
    flop => 3,
    turn => 4,
    river || showdown => 5,
  };
}

/// 테이블 전체 상태. 이 객체 하나가 화면에 보이는 모든 것을 담는다.
///
/// 방장 기기의 엔진이 이 값을 고쳐 가며 Firestore에 올리고, 나머지 사람들은
/// 내려받아 그대로 그린다. 그래서 남의 홀 카드만 빼면 모두가 같은 것을 본다.
class TableState {
  TableState({required this.config, required this.seats});

  /// 빈 좌석만 있는 새 테이블.
  factory TableState.empty(TableConfig config) => TableState(
    config: config,
    seats: List<PlayerSeat>.generate(
      config.maxSeats,
      (index) => PlayerSeat(index: index),
      growable: false,
    ),
  );

  TableConfig config;
  final List<PlayerSeat> seats;

  /// 몇 번째 핸드인가. 뒤늦게 도착한 액션을 걸러 내는 데도 쓴다.
  int handNumber = 0;

  HandPhase phase = HandPhase.waiting;

  /// 딜러 버튼이 놓인 자리.
  int buttonSeat = 0;

  List<PlayingCard> community = const <PlayingCard>[];

  /// 이번 라운드에서 맞춰야 하는 금액.
  int currentBet = 0;

  /// 레이즈할 때 최소한 올려야 하는 폭.
  int minRaise = 0;

  /// 지금 행동할 자리. 아무도 행동할 수 없으면 null이다.
  int? actingSeat;

  /// 행동 제한 시각(epoch 밀리초). 넘기면 방장이 대신 체크·폴드 처리한다.
  int? actionDeadlineMs;

  /// 액션이 받아들여질 때마다 1씩 오른다.
  ///
  /// 참가자는 자기가 본 번호를 함께 보내고, 방장은 번호가 어긋난 액션을
  /// 버린다. 버튼을 두 번 눌렀거나 통신이 늦어 같은 액션이 두 번 와도
  /// 한 번만 반영된다.
  int actionCounter = 0;

  /// 쇼다운에서 계산한 팟들.
  List<Pot> pots = const <Pot>[];

  HandResult? result;

  /// 화면 위쪽에 띄우는 한 줄 안내.
  String? message;

  // ------------------------------------------------------------------ 조회

  PlayerSeat seatAt(int index) => seats[index];

  PlayerSeat? seatOf(String? uid) {
    if (uid == null) {
      return null;
    }
    for (final seat in seats) {
      if (seat.uid == uid) {
        return seat;
      }
    }
    return null;
  }

  Iterable<PlayerSeat> get occupiedSeats => seats.where((s) => s.isOccupied);

  /// 이번 핸드에 아직 살아 있는 자리들.
  List<PlayerSeat> get activeSeats =>
      seats.where((s) => s.isActive).toList(growable: false);

  /// 다음 핸드에 참가할 수 있는 자리들.
  List<PlayerSeat> get readySeats =>
      seats.where((s) => s.isReadyForHand).toList(growable: false);

  /// 자리 앞에 나와 있는 칩까지 포함한, 이번 핸드에 걸린 칩 전부.
  int get totalPot => seats.fold(0, (sum, seat) => sum + seat.handBet);

  /// 가운데 쌓인 칩. 자리 앞에 놓인 이번 라운드 베팅은 빼고 센다.
  int get pot => seats.fold(0, (sum, seat) => sum + seat.handBet - seat.roundBet);

  bool get isHandInProgress => phase != HandPhase.waiting;

  // ---------------------------------------------------------------- 직렬화

  /// [viewerUid]의 홀 카드만 채워서 담는다.
  ///
  /// 방장이 Firestore 공개 문서에 올릴 때는 [viewerUid]를 비워 두고,
  /// 각자에게만 보이는 문서에 홀 카드를 따로 넣는다.
  Map<String, dynamic> toJson({String? viewerUid}) => <String, dynamic>{
    'config': config.toJson(),
    'seats': <Map<String, dynamic>>[
      for (final seat in seats)
        seat.toJson(includeHoleCards: viewerUid != null && seat.uid == viewerUid),
    ],
    'handNumber': handNumber,
    'phase': phase.name,
    'buttonSeat': buttonSeat,
    'community': encodeCards(community),
    'currentBet': currentBet,
    'minRaise': minRaise,
    if (actingSeat != null) 'actingSeat': actingSeat,
    if (actionDeadlineMs != null) 'actionDeadlineMs': actionDeadlineMs,
    'actionCounter': actionCounter,
    'pots': <Map<String, dynamic>>[for (final p in pots) p.toJson()],
    if (result != null) 'result': result!.toJson(),
    if (message != null) 'message': message,
  };

  factory TableState.fromJson(Map<String, dynamic> json) {
    final config = TableConfig.fromJson(
      Map<String, dynamic>.from(json['config'] as Map? ?? const {}),
    );
    final seats = <PlayerSeat>[
      for (final seat in (json['seats'] as List<dynamic>? ?? const []))
        PlayerSeat.fromJson(Map<String, dynamic>.from(seat as Map)),
    ];
    final state = TableState(
      config: config,
      seats: seats.isEmpty
          ? List<PlayerSeat>.generate(config.maxSeats, (i) => PlayerSeat(index: i))
          : seats,
    );
    state
      ..handNumber = (json['handNumber'] as num?)?.toInt() ?? 0
      ..phase = HandPhase.values.byName('${json['phase'] ?? 'waiting'}')
      ..buttonSeat = (json['buttonSeat'] as num?)?.toInt() ?? 0
      ..community = decodeCards(json['community'] as List<dynamic>? ?? const [])
      ..currentBet = (json['currentBet'] as num?)?.toInt() ?? 0
      ..minRaise = (json['minRaise'] as num?)?.toInt() ?? 0
      ..actingSeat = (json['actingSeat'] as num?)?.toInt()
      ..actionDeadlineMs = (json['actionDeadlineMs'] as num?)?.toInt()
      ..actionCounter = (json['actionCounter'] as num?)?.toInt() ?? 0
      ..pots = <Pot>[
        for (final p in (json['pots'] as List<dynamic>? ?? const []))
          Pot.fromJson(Map<String, dynamic>.from(p as Map)),
      ]
      ..message = json['message'] as String?;
    final result = json['result'];
    if (result is Map) {
      state.result = HandResult.fromJson(Map<String, dynamic>.from(result));
    }
    return state;
  }
}
