import 'package:ddai_holdem/engine/game_action.dart';
import 'package:ddai_holdem/engine/table_config.dart';
import 'package:ddai_holdem/engine/table_state.dart';
import 'package:ddai_holdem/net/local_room_transport.dart';
import 'package:ddai_holdem/net/room_session.dart';
import 'package:flutter_test/flutter_test.dart';

const TableConfig _config = TableConfig(
  smallBlind: 10,
  bigBlind: 20,
  startingChips: 1000,
  maxSeats: 4,
);

/// 스트림과 타이머가 한 바퀴 돌 틈을 준다.
Future<void> settle([int turns = 12]) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// [test]가 참이 될 때까지 기다린다. 끝내 참이 되지 않으면 실패한다.
Future<void> waitUntil(
  bool Function() test, {
  String reason = '조건이 만족되지 않았습니다',
}) async {
  for (var i = 0; i < 400; i++) {
    if (test()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail(reason);
}

void main() {
  late LocalRoomTransport transport;
  late RoomSession session;

  setUp(() async {
    transport = LocalRoomTransport(botCount: 2, botDelay: Duration.zero);
    session = RoomSession(
      transport: transport,
      myName: '나',
      config: _config,
    );
    await session.start();
    await settle();
  });

  tearDown(() async => session.dispose());

  test('방을 열면 나와 봇들이 자리에 앉는다', () async {
    await waitUntil(
      () => (session.table.value?.occupiedSeats.length ?? 0) == 3,
      reason: '나 한 명과 봇 두 명이 앉아야 합니다',
    );

    final table = session.table.value!;
    expect(session.mySeat, isNotNull);
    expect(session.mySeat!.chips, 1000);
    expect(table.phase, HandPhase.waiting);
    expect(session.isHost, isTrue);
  });

  test('핸드를 시작하면 내 홀 카드가 두 장 들어온다', () async {
    await waitUntil(() => (session.table.value?.readySeats.length ?? 0) == 3);
    await session.startHand();
    await waitUntil(() => session.table.value!.phase != HandPhase.waiting);

    final table = session.table.value!;
    expect(table.handNumber, 1);
    expect(session.mySeat!.holeCards, hasLength(2));
    // 남의 카드는 내 화면에 실리지 않는다.
    for (final seat in table.seats) {
      if (seat.isOccupied && seat.uid != session.myUid) {
        expect(seat.holeCards, isEmpty);
      }
    }
  });

  test('끝까지 진행하면 핸드가 마무리되고 칩 총량이 유지된다', () async {
    await waitUntil(() => (session.table.value?.readySeats.length ?? 0) == 3);
    await session.startHand();
    await waitUntil(() => session.table.value!.phase != HandPhase.waiting);

    // 내 차례가 오면 체크할 수 있으면 체크, 아니면 콜로 따라간다.
    var guard = 0;
    while (session.table.value!.phase.isBetting && guard++ < 300) {
      final options = session.myOptions;
      if (options.isActive) {
        await session.act(
          options.canCheck
              ? const GameAction.check()
              : const GameAction.call(),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }

    final table = session.table.value!;
    expect(table.phase, HandPhase.showdown, reason: '핸드가 끝나야 합니다');
    expect(table.result, isNotNull);
    expect(
      table.seats.fold<int>(0, (sum, seat) => sum + seat.chips),
      3000,
      reason: '칩이 사라지거나 늘어나면 안 됩니다',
    );
  });

  test('차례가 아닐 때는 아무 선택지도 열리지 않는다', () async {
    await waitUntil(() => (session.table.value?.readySeats.length ?? 0) == 3);
    final table = session.table.value!;
    // 아직 핸드를 시작하지 않았으니 누구의 차례도 아니다.
    expect(table.actingSeat, isNull);
    expect(session.myOptions.isActive, isFalse);
  });
}
