import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/card.dart';
import '../engine/game_action.dart';
import '../engine/holdem_engine.dart';
import '../engine/seat.dart';
import '../engine/table_config.dart';
import '../engine/table_state.dart';
import 'room_command.dart';
import 'room_transport.dart';

/// 방 하나에 붙어 있는 동안의 모든 것.
///
/// 방장 기기에서는 [HoldemEngine]을 돌려 결과를 올리고, 나머지 기기에서는
/// 내려온 상태에 내 홀 카드만 얹어 보여 준다. 화면은 어느 쪽이든 [table] 하나만
/// 보면 된다.
class RoomSession {
  RoomSession({
    required this.transport,
    required this.myName,
    required this.config,
  });

  /// 결과를 보여 주고 다음 핸드로 넘어가기까지 기다리는 시간.
  static const Duration handBreak = Duration(seconds: 6);

  final RoomTransport transport;
  final String myName;
  final TableConfig config;

  /// 화면이 구독하는 테이블 상태.
  final ValueNotifier<TableState?> table = ValueNotifier<TableState?>(null);

  /// 화면 위에 잠깐 띄우는 안내나 오류.
  final ValueNotifier<String?> notice = ValueNotifier<String?>(null);

  /// 명령을 보내고 아직 결과가 돌아오지 않은 상태. 버튼 연타를 막는다.
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  String get myUid => transport.myUid;

  bool get isHost => transport.isHost;

  bool get isOnline => transport.isOnline;

  String get roomId => transport.roomId;

  // 방장만 쓰는 것들
  HoldemEngine? _engine;
  bool _bootstrapping = false;
  bool _processing = false;
  DateTime? _showdownSince;
  final Set<String> _consumed = <String>{};
  final Set<String> _leaveAfterHand = <String>{};

  // 참가자가 쓰는 것들
  TableState? _public;
  int _holeCardsHand = -1;
  List<PlayingCard> _holeCards = const <PlayingCard>[];

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  Timer? _ticker;
  bool _closed = false;

  // ------------------------------------------------------------------ 수명

  Future<void> start() async {
    _subscriptions.add(transport.watchTable().listen(_onTable));
    _subscriptions.add(transport.watchMyHoleCards().listen(_onHoleCards));
    if (transport.isHost) {
      _subscriptions.add(transport.watchCommands().listen(_onCommands));
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else {
      await _send(RoomCommandType.join, name: myName);
    }
  }

  Future<void> dispose() async {
    _closed = true;
    _ticker?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await transport.close();
    table.dispose();
    notice.dispose();
    busy.dispose();
  }

  // -------------------------------------------------------------- 화면 조작

  /// 지금 내 자리.
  PlayerSeat? get mySeat => table.value?.seatOf(myUid);

  /// 내가 고를 수 있는 선택지. 내 차례가 아니면 [ActionOptions.none]이다.
  ActionOptions get myOptions {
    final state = table.value;
    final seat = state?.seatOf(myUid);
    if (state == null || seat == null) {
      return ActionOptions.none;
    }
    // 규칙을 한 벌 더 두지 않으려고 엔진에 그대로 물어본다. 베팅에 관한 정보는
    // 전부 공개되어 있어서 참가자 쪽에서도 같은 답이 나온다.
    return HoldemEngine(state).optionsFor(seat.index);
  }

  Future<void> act(GameAction action) async {
    final state = table.value;
    if (state == null) {
      return;
    }
    await _send(
      RoomCommandType.play,
      action: action,
      handNumber: state.handNumber,
      actionCounter: state.actionCounter,
    );
  }

  Future<void> startHand() async {
    final state = table.value;
    await _send(
      RoomCommandType.startHand,
      handNumber: state?.handNumber ?? 0,
    );
  }

  Future<void> sitOut() => _send(RoomCommandType.sitOut);

  /// 다시 참가한다. 칩이 다 떨어진 상태면 새로 받는다.
  Future<void> sitIn() => _send(RoomCommandType.sitIn);

  Future<void> leave() => _send(RoomCommandType.leave);

  Future<void> _send(
    RoomCommandType type, {
    String name = '',
    GameAction? action,
    int handNumber = 0,
    int actionCounter = 0,
  }) async {
    final command = RoomCommand(
      id: '',
      uid: myUid,
      type: type,
      name: name.isEmpty ? myName : name,
      action: action,
      handNumber: handNumber,
      actionCounter: actionCounter,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    busy.value = true;
    try {
      await transport.sendCommand(command);
    } catch (error) {
      notice.value = '전송하지 못했습니다: $error';
    } finally {
      busy.value = false;
    }
  }

  // ------------------------------------------------------------ 참가자 쪽

  void _onTable(TableState? state) {
    if (transport.isHost) {
      // 방장은 자기 엔진이 원본이라 내려온 값을 되읽지 않는다. 처음 붙었을
      // 때만 남아 있던 판을 이어받는다.
      if (_engine == null && !_bootstrapping) {
        unawaited(_bootstrapHost(state));
      }
      return;
    }
    _public = state;
    _rebuildView();
  }

  void _onHoleCards((int, List<String>) payload) {
    final (handNumber, codes) = payload;
    _holeCardsHand = handNumber;
    _holeCards = decodeCards(codes);
    if (transport.isHost) {
      return;
    }
    _rebuildView();
  }

  /// 공개 상태에 내 홀 카드를 얹어 화면용 스냅샷을 만든다.
  void _rebuildView() {
    final state = _public;
    if (state == null) {
      return;
    }
    final seat = state.seatOf(myUid);
    // 핸드 번호가 맞을 때만 얹는다. 지난 판 카드가 남아 보이면 안 된다.
    if (seat != null &&
        seat.holeCards.isEmpty &&
        _holeCards.isNotEmpty &&
        _holeCardsHand == state.handNumber) {
      seat.holeCards = _holeCards;
    }
    table.value = state;
  }

  // -------------------------------------------------------------- 방장 쪽

  Future<void> _bootstrapHost(TableState? existing) async {
    _bootstrapping = true;
    try {
      final state = existing ?? TableState.empty(config);
      final engine = HoldemEngine(state);
      _engine = engine;

      if (state.isHandInProgress) {
        // 돌리던 판이 있다. 덱과 모두의 홀 카드를 되살려 이어 간다.
        final secret = await transport.loadSecret();
        if (secret.deck.isEmpty && state.phase.isBetting) {
          notice.value = '돌리던 판을 이어받지 못해 새로 시작합니다.';
          engine.resetToWaiting();
        } else {
          engine.restoreDeck(secret.deck);
          for (final seat in state.seats) {
            final codes = secret.holes[seat.uid];
            if (codes != null) {
              seat.holeCards = decodeCards(codes);
            }
          }
        }
      }

      _seatPlayer(uid: myUid, name: myName);
      await _publish(const <String>[]);
    } finally {
      _bootstrapping = false;
    }
  }

  Future<void> _onCommands(List<RoomCommand> commands) async {
    final engine = _engine;
    if (engine == null || commands.isEmpty || _processing || _closed) {
      return;
    }
    _processing = true;
    try {
      final handled = <String>[];
      for (final command in commands) {
        handled.add(command.id);
        // 지웠는데도 스냅샷이 한 번 더 오는 경우가 있다. 두 번 반영하지 않는다.
        if (!_consumed.add(command.id)) {
          continue;
        }
        try {
          _applyCommand(engine, command);
        } on IllegalActionException catch (error) {
          debugPrint('명령을 버렸습니다(${command.type.name}): $error');
        }
      }
      if (_consumed.length > 400) {
        _consumed.clear();
      }
      await _publish(handled);
    } finally {
      _processing = false;
    }
  }

  void _applyCommand(HoldemEngine engine, RoomCommand command) {
    final state = engine.state;
    switch (command.type) {
      case RoomCommandType.join:
        if (!_seatPlayer(uid: command.uid, name: command.name)) {
          notice.value = '자리가 꽉 찼습니다.';
        }
        _leaveAfterHand.remove(command.uid);

      case RoomCommandType.leave:
        final seat = state.seatOf(command.uid);
        if (seat == null) {
          return;
        }
        if (seat.isActive && state.phase.isBetting) {
          // 판이 도는 중에는 자리를 바로 빼지 않는다. 접속이 끊긴 것으로 두면
          // 차례가 왔을 때 [_tick]이 대신 폴드하고, 핸드가 끝나면 비운다.
          seat.connected = false;
          _leaveAfterHand.add(command.uid);
        } else {
          seat.leave();
        }

      case RoomCommandType.sitOut:
        state.seatOf(command.uid)?.sittingOut = true;

      case RoomCommandType.sitIn:
        final seat = state.seatOf(command.uid);
        if (seat == null) {
          return;
        }
        seat.sittingOut = false;
        if (seat.chips <= 0) {
          seat.chips = state.config.startingChips;
        }

      case RoomCommandType.startHand:
        if (command.uid != myUid) {
          throw const IllegalActionException('방장만 시작할 수 있습니다.');
        }
        if (state.phase.isBetting || command.handNumber != state.handNumber) {
          return;
        }
        if (!engine.canStartHand) {
          throw const IllegalActionException('두 명 이상 있어야 시작할 수 있습니다.');
        }
        engine.startHand();

      case RoomCommandType.play:
        final seat = state.seatOf(command.uid);
        final action = command.action;
        if (seat == null || action == null) {
          return;
        }
        if (command.handNumber != state.handNumber ||
            command.actionCounter != state.actionCounter) {
          // 화면이 한발 늦은 상태에서 누른 액션이다. 반영하면 엉뚱한 판단이 된다.
          return;
        }
        engine.apply(seatIndex: seat.index, action: action);
    }
  }

  bool _seatPlayer({required String uid, required String name}) {
    final state = _engine!.state;
    final existing = state.seatOf(uid);
    if (existing != null) {
      existing
        ..name = name.isEmpty ? existing.name : name
        ..connected = true;
      return true;
    }
    for (final seat in state.seats) {
      if (!seat.isOccupied) {
        seat.sit(
          uid: uid,
          name: name.isEmpty ? '플레이어' : name,
          chips: state.config.startingChips,
        );
        return true;
      }
    }
    return false;
  }

  /// 1초마다 시간 초과·접속 끊김·다음 핸드를 살핀다.
  void _tick() {
    final engine = _engine;
    if (engine == null || _processing || _closed) {
      return;
    }
    final state = engine.state;
    var changed = false;

    if (!state.phase.isBetting && _leaveAfterHand.isNotEmpty) {
      for (final uid in _leaveAfterHand) {
        state.seatOf(uid)?.leave();
      }
      _leaveAfterHand.clear();
      changed = true;
    }

    if (state.phase.isBetting) {
      final acting = state.actingSeat;
      if (acting != null) {
        final seat = state.seatAt(acting);
        final deadline = state.actionDeadlineMs;
        final expired =
            deadline != null &&
            DateTime.now().millisecondsSinceEpoch > deadline;
        if (!seat.connected || expired) {
          engine.applyTimeout();
          changed = true;
        }
      }
    } else if (state.phase == HandPhase.showdown) {
      final since = _showdownSince;
      if (since != null && DateTime.now().difference(since) >= handBreak) {
        if (engine.canStartHand) {
          engine.startHand();
        } else {
          engine.resetToWaiting();
        }
        changed = true;
      }
    }

    if (changed) {
      unawaited(_publish(const <String>[]));
    }
  }

  Future<void> _publish(List<String> consumedCommandIds) async {
    final engine = _engine;
    if (engine == null || _closed) {
      return;
    }
    final state = engine.state;

    _showdownSince = state.phase == HandPhase.showdown
        ? (_showdownSince ?? DateTime.now())
        : null;

    final holes = <String, List<String>>{
      for (final seat in state.seats)
        if (seat.uid != null && seat.holeCards.isNotEmpty)
          seat.uid!: encodeCards(seat.holeCards),
    };

    // 방장 화면은 올리기 전에 먼저 갱신한다. 내 손이 느려 보일 이유가 없다.
    table.value = TableState.fromJson(state.toJson(viewerUid: myUid));

    try {
      await transport.publish(
        table: state,
        holeCardsByUid: holes,
        deck: engine.deck?.toCodes() ?? const <String>[],
        consumedCommandIds: consumedCommandIds,
      );
    } catch (error) {
      notice.value = '상태를 올리지 못했습니다: $error';
    }
  }
}
