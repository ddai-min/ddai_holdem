import 'dart:async';
import 'dart:math' as math;

import '../engine/card.dart';
import '../engine/game_action.dart';
import '../engine/holdem_engine.dart';
import '../engine/table_state.dart';
import 'bot_brain.dart';
import 'room_command.dart';
import 'room_transport.dart';

/// 봇이 자기 차례에 무엇을 할지 정하는 함수.
///
/// 비워 두면 [BotBrain]이 판단한다. 테스트에서는 "늘 콜"처럼 뻔한 정책을
/// 넣어 판이 흘러가는 길을 정해 둘 수 있다.
typedef BotPolicy =
    GameAction Function(
      ActionOptions options,
      TableState table,
      List<PlayingCard> hole,
    );

/// 기기 안에서만 도는 연습 모드.
///
/// Firestore 대신 메모리에 같은 문서들을 흉내 낸다. [RoomSession] 쪽 코드가
/// 온라인과 완전히 같은 길을 타기 때문에, 여기서 잘 돌면 온라인에서도 같은
/// 규칙으로 돈다. 빈자리는 [BotBrain]이 채운다.
class LocalRoomTransport implements RoomTransport {
  LocalRoomTransport({
    this.botCount = 3,
    this.botDelay = const Duration(milliseconds: 800),
    this.botPolicy,
    math.Random? random,
  }) : _random = random ?? math.Random();

  static const List<String> _botNames = <String>[
    '민준',
    '서연',
    '도윤',
    '지우',
    '하준',
    '수아',
    '은우',
    '나윤',
  ];

  final int botCount;

  /// 봇이 뜸을 들이는 최소 시간. 테스트에서는 0으로 두어 바로 치게 한다.
  final Duration botDelay;

  /// 봇의 판단을 갈아 끼우고 싶을 때 쓴다. 비워 두면 [BotBrain]이 판단한다.
  final BotPolicy? botPolicy;

  final math.Random _random;

  @override
  String get roomId => '연습';

  @override
  String get myUid => 'me';

  @override
  bool get isHost => true;

  @override
  bool get isOnline => false;

  /// 새로 구독한 쪽에 지금 상태부터 한 번 흘려 준다.
  ///
  /// Firestore는 구독하는 순간 현재 문서를 그대로 내려 준다. 로컬도 같아야
  /// [RoomSession]이 어느 쪽이든 똑같이 동작한다. 방장 부트스트랩이 이 첫
  /// 값(처음에는 null)을 신호로 삼는다.
  late final StreamController<TableState?> _tableEvents =
      StreamController<TableState?>.broadcast(
        onListen: () => scheduleMicrotask(() {
          if (!_tableEvents.isClosed) {
            _tableEvents.add(_table);
          }
        }),
      );
  final StreamController<(int, List<String>)> _holeEvents =
      StreamController<(int, List<String>)>.broadcast();
  final StreamController<List<RoomCommand>> _commandEvents =
      StreamController<List<RoomCommand>>.broadcast();

  final List<RoomCommand> _pending = <RoomCommand>[];
  final Map<String, List<String>> _holes = <String, List<String>>{};
  List<String> _deck = const <String>[];

  TableState? _table;
  Timer? _botTimer;
  var _commandSeq = 0;
  var _botsJoined = false;
  var _closed = false;

  @override
  Stream<TableState?> watchTable() => _tableEvents.stream;

  @override
  Stream<(int, List<String>)> watchMyHoleCards() => _holeEvents.stream;

  @override
  Stream<List<RoomCommand>> watchCommands() => _commandEvents.stream;

  @override
  Future<void> sendCommand(RoomCommand command) async {
    if (_closed) {
      return;
    }
    _pending.add(command.withId('c${_commandSeq++}'));
    _commandEvents.add(List<RoomCommand>.unmodifiable(_pending));
  }

  @override
  Future<void> publish({
    required TableState table,
    required Map<String, List<String>> holeCardsByUid,
    required List<String> deck,
    required List<String> consumedCommandIds,
  }) async {
    if (_closed) {
      return;
    }
    _pending.removeWhere((command) => consumedCommandIds.contains(command.id));
    _holes
      ..clear()
      ..addAll(holeCardsByUid);
    _deck = deck;

    // 온라인과 똑같이, 공개 문서에는 남의 홀 카드를 담지 않는다.
    final snapshot = TableState.fromJson(table.toJson());
    _table = snapshot;
    _tableEvents.add(snapshot);
    _holeEvents.add((
      table.handNumber,
      holeCardsByUid[myUid] ?? const <String>[],
    ));

    if (!_botsJoined && snapshot.seatOf(myUid) != null) {
      _botsJoined = true;
      _seatBots(snapshot);
    }
    // 처리 중이라 넘어간 명령이 있으면 다시 알린다. Firestore에서 스냅샷이
    // 한 번 더 오는 것과 같은 자리다.
    if (_pending.isNotEmpty) {
      _commandEvents.add(List<RoomCommand>.unmodifiable(_pending));
    }
    _scheduleBot(snapshot);
  }

  @override
  Future<({List<String> deck, Map<String, List<String>> holes})>
  loadSecret() async => (deck: _deck, holes: _holes);

  @override
  Future<void> close() async {
    _closed = true;
    _botTimer?.cancel();
    await _tableEvents.close();
    await _holeEvents.close();
    await _commandEvents.close();
  }

  void _seatBots(TableState table) {
    final room = math.min(botCount, table.config.maxSeats - 1);
    final names = _botNames.toList()..shuffle(_random);
    for (var i = 0; i < room; i++) {
      unawaited(
        sendCommand(
          RoomCommand(
            id: '',
            uid: 'bot$i',
            type: RoomCommandType.join,
            name: names[i % names.length],
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        ),
      );
    }
  }

  /// 봇 차례면 잠깐 뜸을 들였다가 액션을 보낸다.
  void _scheduleBot(TableState table) {
    _botTimer?.cancel();
    final acting = table.actingSeat;
    if (_closed || !table.phase.isBetting || acting == null) {
      return;
    }
    final seat = table.seatAt(acting);
    final uid = seat.uid;
    if (uid == null || !uid.startsWith('bot')) {
      return;
    }

    final options = HoldemEngine(table).optionsFor(acting);
    if (!options.isActive) {
      return;
    }
    final hole = decodeCards(_holes[uid] ?? const <String>[]);
    final action =
        botPolicy?.call(options, table, hole) ??
        BotBrain.decide(
          options: options,
          hole: hole,
          community: table.community,
          pot: table.totalPot,
          random: _random,
        );

    // 사람처럼 보이도록 조금 기다린다. 너무 빠르면 무슨 일이 일어났는지 못 본다.
    // 테스트에서 [botDelay]를 0으로 두면 흔들림 없이 바로 친다.
    final jitter = botDelay > Duration.zero ? _random.nextInt(900) : 0;
    _botTimer = Timer(
      botDelay + Duration(milliseconds: jitter),
      () => sendCommand(
        RoomCommand(
          id: '',
          uid: uid,
          type: RoomCommandType.play,
          action: action,
          handNumber: table.handNumber,
          actionCounter: table.actionCounter,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
  }
}
