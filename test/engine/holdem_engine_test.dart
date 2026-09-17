import 'package:ddai_holdem/engine/card.dart';
import 'package:ddai_holdem/engine/deck.dart';
import 'package:ddai_holdem/engine/game_action.dart';
import 'package:ddai_holdem/engine/holdem_engine.dart';
import 'package:ddai_holdem/engine/table_config.dart';
import 'package:ddai_holdem/engine/table_state.dart';
import 'package:flutter_test/flutter_test.dart';

const TableConfig _config = TableConfig(
  smallBlind: 10,
  bigBlind: 20,
  startingChips: 1000,
  maxSeats: 6,
);

/// 자리마다 칩을 정해 앉힌 테이블.
///
/// [button]은 `startHand`가 버튼을 한 칸 옮기기 *전* 위치다. 원하는 자리에
/// 버튼이 놓이게 하려면 그 앞자리를 넘기면 된다.
TableState seatPlayers(List<int> stacks, {required int button}) {
  final state = TableState.empty(_config);
  for (var i = 0; i < stacks.length; i++) {
    state.seats[i].sit(uid: 'u$i', name: 'P$i', chips: stacks[i]);
  }
  state.buttonSeat = button;
  return state;
}

/// 원하는 홀 카드와 보드가 그대로 나오도록 쌓아 둔 덱.
///
/// [holes]는 버튼 왼쪽부터의 순서다. 엔진이 그 순서로 두 바퀴 돌려 나눠 주고,
/// 스트리트마다 한 장씩 태우기 때문에 그 자리에는 쓰지 않는 카드를 끼워 둔다.
Deck stackedDeck({
  required List<List<String>> holes,
  required List<String> board,
}) {
  final ordered = <PlayingCard>[];
  for (var round = 0; round < 2; round++) {
    for (final hole in holes) {
      ordered.add(PlayingCard.fromCode(hole[round]));
    }
  }
  final boardCards = board.map(PlayingCard.fromCode).toList();
  final used = <PlayingCard>{...ordered, ...boardCards};
  final spare = <PlayingCard>[
    for (final suit in Suit.values)
      for (final rank in Rank.values)
        if (!used.contains(PlayingCard(rank, suit))) PlayingCard(rank, suit),
  ];

  var spareIndex = 0;
  PlayingCard burn() => spare[spareIndex++];

  return Deck.stacked(<PlayingCard>[
    ...ordered,
    burn(), ...boardCards.take(3),
    burn(), boardCards[3],
    burn(), boardCards[4],
    ...spare.skip(spareIndex),
  ]);
}

void main() {
  group('핸드 시작', () {
    test('3명이면 버튼 왼쪽이 SB, 그다음이 BB이고 버튼이 먼저 친다', () {
      final state = seatPlayers(<int>[1000, 1000, 1000], button: 2);
      HoldemEngine(state).startHand();

      expect(state.buttonSeat, 0);
      expect(state.seatAt(1).roundBet, 10, reason: 'SB');
      expect(state.seatAt(2).roundBet, 20, reason: 'BB');
      expect(state.currentBet, 20);
      expect(state.minRaise, 20);
      expect(state.actingSeat, 0, reason: '3명일 때 프리플랍 첫 액션은 버튼');
      expect(state.phase, HandPhase.preflop);
      expect(state.seatAt(0).holeCards, hasLength(2));
    });

    test('2명이면 버튼이 SB이고 프리플랍에서 먼저 친다', () {
      final state = seatPlayers(<int>[1000, 1000], button: 1);
      HoldemEngine(state).startHand();

      expect(state.buttonSeat, 0);
      expect(state.seatAt(0).roundBet, 10, reason: '버튼이 곧 SB');
      expect(state.seatAt(1).roundBet, 20, reason: 'BB');
      expect(state.actingSeat, 0);
    });

    test('2명일 때 플랍부터는 BB가 먼저 친다', () {
      final state = seatPlayers(<int>[1000, 1000], button: 1);
      final engine = HoldemEngine(state)..startHand();

      engine.apply(seatIndex: 0, action: const GameAction.call());
      engine.apply(seatIndex: 1, action: const GameAction.check());

      expect(state.phase, HandPhase.flop);
      expect(state.community, hasLength(3));
      expect(state.actingSeat, 1, reason: '플랍부터는 버튼 왼쪽(=BB)부터');
    });
  });

  group('베팅 라운드', () {
    test('모두 콜만 하면 BB에게 마지막 선택권이 간다', () {
      final state = seatPlayers(<int>[1000, 1000, 1000], button: 2);
      final engine = HoldemEngine(state)..startHand();

      engine.apply(seatIndex: 0, action: const GameAction.call());
      engine.apply(seatIndex: 1, action: const GameAction.call());

      expect(state.phase, HandPhase.preflop, reason: '아직 플랍으로 넘어가면 안 된다');
      expect(state.actingSeat, 2);
      expect(engine.optionsFor(2).canCheck, isTrue);
      expect(engine.optionsFor(2).canRaise, isTrue);

      engine.apply(seatIndex: 2, action: const GameAction.check());
      expect(state.phase, HandPhase.flop);
    });

    test('최소 레이즈 폭보다 적게 올릴 수 없다', () {
      final state = seatPlayers(<int>[1000, 1000, 1000], button: 2);
      final engine = HoldemEngine(state)..startHand();

      expect(engine.optionsFor(0).minRaiseTo, 40);
      expect(
        () => engine.apply(seatIndex: 0, action: const GameAction.raise(30)),
        throwsA(isA<IllegalActionException>()),
      );
      engine.apply(seatIndex: 0, action: const GameAction.raise(40));
      expect(state.currentBet, 40);
      expect(state.minRaise, 20);
    });

    test('레이즈가 들어오면 이미 행동한 사람의 차례가 다시 열린다', () {
      final state = seatPlayers(<int>[1000, 1000, 1000], button: 2);
      final engine = HoldemEngine(state)..startHand();

      engine.apply(seatIndex: 0, action: const GameAction.call());
      engine.apply(seatIndex: 1, action: const GameAction.raise(100));

      expect(state.actingSeat, 2, reason: 'BB 먼저');
      engine.apply(seatIndex: 2, action: const GameAction.call());
      expect(state.actingSeat, 0, reason: '콜했던 사람에게 다시 차례가 온다');
      expect(engine.optionsFor(0).callAmount, 80);
    });

    test('차례가 아닌 사람의 액션은 거부한다', () {
      final state = seatPlayers(<int>[1000, 1000, 1000], button: 2);
      final engine = HoldemEngine(state)..startHand();

      expect(
        () => engine.apply(seatIndex: 1, action: const GameAction.call()),
        throwsA(isA<IllegalActionException>()),
      );
    });

    test('맞출 금액이 남았으면 체크할 수 없다', () {
      final state = seatPlayers(<int>[1000, 1000, 1000], button: 2);
      final engine = HoldemEngine(state)..startHand();

      expect(engine.optionsFor(0).canCheck, isFalse);
      expect(
        () => engine.apply(seatIndex: 0, action: const GameAction.check()),
        throwsA(isA<IllegalActionException>()),
      );
    });

    test('부족한 올인은 베팅을 다시 열지 않는다', () {
      // BB가 130밖에 없어 100 레이즈에 30만 더 얹고 올인한다. 이미 콜한
      // 사람들은 차액 30을 맞출 수는 있어도 다시 올릴 수는 없다.
      final state = seatPlayers(<int>[1000, 1000, 130], button: 2);
      final engine = HoldemEngine(state)..startHand();

      engine.apply(seatIndex: 0, action: const GameAction.raise(100));
      engine.apply(seatIndex: 1, action: const GameAction.call());
      engine.apply(seatIndex: 2, action: const GameAction.allIn());

      expect(state.currentBet, 130);
      expect(state.minRaise, 80, reason: '최소 레이즈 폭은 그대로 남는다');
      expect(state.actingSeat, 0);

      final options = engine.optionsFor(0);
      expect(options.callAmount, 30);
      expect(options.canRaise, isFalse, reason: '다시 올릴 수는 없다');
      expect(
        () => engine.apply(seatIndex: 0, action: const GameAction.raise(400)),
        throwsA(isA<IllegalActionException>()),
      );
    });
  });

  group('정산', () {
    test('나머지가 다 폴드하면 카드를 까지 않고 팟을 가져간다', () {
      final state = seatPlayers(<int>[1000, 1000, 1000], button: 2);
      final engine = HoldemEngine(state)..startHand();

      engine.apply(seatIndex: 0, action: const GameAction.fold());
      engine.apply(seatIndex: 1, action: const GameAction.fold());

      expect(state.phase, HandPhase.showdown);
      expect(state.result!.wentToShowdown, isFalse);
      expect(state.seatAt(2).chips, 1010, reason: 'BB가 SB의 10칩을 가져간다');
      expect(state.seatAt(1).chips, 990);
      expect(state.seatAt(0).chips, 1000);
    });

    test('아무도 받지 않은 베팅은 돌려준다', () {
      final state = seatPlayers(<int>[1000, 1000], button: 1);
      final engine = HoldemEngine(state)..startHand();

      // 버튼이 200까지 올렸는데 BB가 폴드했다. 20을 넘는 180은 승부에 걸린
      // 적이 없으므로 그대로 돌아와야 한다.
      engine.apply(seatIndex: 0, action: const GameAction.raise(200));
      engine.apply(seatIndex: 1, action: const GameAction.fold());

      expect(state.seatAt(0).chips, 1020);
      expect(state.seatAt(1).chips, 980);
      expect(
        state.seatAt(0).chips + state.seatAt(1).chips,
        2000,
        reason: '칩 총량은 변하지 않는다',
      );
    });

    test('스택이 다르면 메인 팟과 사이드 팟으로 갈린다', () {
      // 0번(1000)이 올인, 1번(200)과 2번(500)이 각자 가진 만큼 콜한다.
      //   메인 팟 600 = 200 x 3  -> 셋 다 노릴 수 있다
      //   사이드 팟 600 = 300 x 2 -> 0번과 2번만 노릴 수 있다
      final state = seatPlayers(<int>[1000, 200, 500], button: 2);
      final engine = HoldemEngine(
        state,
        deckFactory: () => stackedDeck(
          // 버튼(0번) 왼쪽부터: 1번, 2번, 0번
          holes: <List<String>>[
            <String>['As', 'Ah'], // 1번 - 에이스 원페어
            <String>['Ks', 'Kh'], // 2번 - 킹 원페어
            <String>['Qs', 'Qh'], // 0번 - 퀸 원페어
          ],
          board: <String>['2c', '3d', '7h', '9s', 'Jc'],
        ),
      )..startHand();

      engine.apply(seatIndex: 0, action: const GameAction.allIn());
      engine.apply(seatIndex: 1, action: const GameAction.call());
      engine.apply(seatIndex: 2, action: const GameAction.call());

      expect(state.phase, HandPhase.showdown);
      expect(state.pots, hasLength(2));
      expect(state.pots[0].amount, 600);
      expect(state.pots[0].eligibleSeats, <int>[0, 1, 2]);
      expect(state.pots[1].amount, 600);
      expect(state.pots[1].eligibleSeats, <int>[0, 2]);

      expect(state.seatAt(1).chips, 600, reason: '에이스가 메인 팟을 가져간다');
      expect(state.seatAt(2).chips, 600, reason: '킹이 사이드 팟을 가져간다');
      expect(state.seatAt(0).chips, 500, reason: '받아 주지 않은 500은 돌아온다');
      expect(
        state.seats.fold<int>(0, (sum, seat) => sum + seat.chips),
        1700,
      );
    });

    test('같은 족보면 팟을 나눈다', () {
      final state = seatPlayers(<int>[1000, 1000], button: 1);
      final engine = HoldemEngine(
        state,
        deckFactory: () => stackedDeck(
          // 버튼(0번) 왼쪽부터: 1번, 0번
          holes: <List<String>>[
            <String>['Ah', 'Kc'],
            <String>['As', 'Kd'],
          ],
          // 보드가 QJT라 양쪽 다 A-K-Q-J-T 스트레이트다.
          board: <String>['Qs', 'Jh', 'Ts', '2c', '3d'],
        ),
      )..startHand();

      engine.apply(seatIndex: 0, action: const GameAction.call());
      engine.apply(seatIndex: 1, action: const GameAction.check());
      for (var street = 0; street < 3; street++) {
        engine.apply(seatIndex: 1, action: const GameAction.check());
        engine.apply(seatIndex: 0, action: const GameAction.check());
      }

      expect(state.phase, HandPhase.showdown);
      expect(state.result!.awards.single.winnerSeats, hasLength(2));
      expect(state.seatAt(0).chips, 1000);
      expect(state.seatAt(1).chips, 1000);
    });

    test('나누어떨어지지 않는 칩은 버튼 왼쪽부터 가져간다', () {
      // SB가 5만 넣고 폴드하면 팟이 25가 되어, 둘이 나눌 때 1칩이 남는다.
      final state = TableState.empty(
        const TableConfig(smallBlind: 5, bigBlind: 10, startingChips: 1000),
      );
      for (var i = 0; i < 3; i++) {
        state.seats[i].sit(uid: 'u$i', name: 'P$i', chips: 1000);
      }
      state.buttonSeat = 2;

      final engine = HoldemEngine(
        state,
        deckFactory: () => stackedDeck(
          // 버튼(0번) 왼쪽부터: 1번, 2번, 0번
          holes: <List<String>>[
            <String>['2c', '3d'], // 1번 - 곧 폴드한다
            <String>['Ah', 'Kc'], // 2번
            <String>['As', 'Kd'], // 0번
          ],
          // 양쪽 다 A-K-Q-J-T 스트레이트가 되어 무승부다.
          board: <String>['Qs', 'Jh', 'Ts', '4c', '5d'],
        ),
      )..startHand();

      engine.apply(seatIndex: 0, action: const GameAction.call());
      engine.apply(seatIndex: 1, action: const GameAction.fold());
      engine.apply(seatIndex: 2, action: const GameAction.check());
      for (var street = 0; street < 3; street++) {
        engine.apply(seatIndex: 2, action: const GameAction.check());
        engine.apply(seatIndex: 0, action: const GameAction.check());
      }

      final award = state.result!.awards.single;
      expect(award.amount, 25);
      expect(award.winnerSeats, hasLength(2));
      // 버튼이 0번이니 더 왼쪽인 2번이 남는 1칩을 받는다.
      expect(state.seatAt(2).chips, 1003);
      expect(state.seatAt(0).chips, 1002);
      expect(state.seatAt(1).chips, 995);
    });
  });

  group('연속 진행', () {
    test('핸드를 여러 번 돌려도 칩 총량이 유지된다', () {
      final state = seatPlayers(<int>[1000, 1000, 1000], button: 2);
      final engine = HoldemEngine(state);

      for (var hand = 0; hand < 30; hand++) {
        if (!engine.canStartHand) {
          break;
        }
        engine.startHand();
        var guard = 0;
        while (state.phase.isBetting && guard++ < 200) {
          final acting = state.actingSeat!;
          final options = engine.optionsFor(acting);
          // 체크할 수 있으면 체크, 아니면 콜. 가끔 올인해서 사이드 팟도 만든다.
          if (hand % 7 == 0 && options.canRaise && acting == state.buttonSeat) {
            engine.apply(seatIndex: acting, action: const GameAction.allIn());
          } else if (options.canCheck) {
            engine.apply(seatIndex: acting, action: const GameAction.check());
          } else {
            engine.apply(seatIndex: acting, action: const GameAction.call());
          }
        }
        expect(state.phase, HandPhase.showdown, reason: '$hand번째 핸드가 끝나야 한다');
        expect(
          state.seats.fold<int>(0, (sum, seat) => sum + seat.chips),
          3000,
          reason: '$hand번째 핸드 뒤 칩 총량',
        );
      }
    });

    test('칩이 떨어진 사람은 다음 핸드를 쉰다', () {
      // 40칩뿐인 SB가 올인하고 지면 자리에는 남지만 다음 핸드는 쉰다.
      final state = seatPlayers(<int>[1000, 40, 1000], button: 2);
      final engine = HoldemEngine(
        state,
        deckFactory: () => stackedDeck(
          // 버튼(0번) 왼쪽부터: 1번, 2번, 0번
          holes: <List<String>>[
            <String>['2c', '3d'], // 1번 - 숏스택
            <String>['As', 'Ah'], // 2번 - 보드의 A와 합쳐 트리플
            <String>['Ks', 'Kh'], // 0번
          ],
          board: <String>['Ad', '7h', '9s', 'Jc', '4s'],
        ),
      )..startHand();

      engine.apply(seatIndex: 0, action: const GameAction.call());
      engine.apply(seatIndex: 1, action: const GameAction.allIn());
      engine.apply(seatIndex: 2, action: const GameAction.call());
      engine.apply(seatIndex: 0, action: const GameAction.call());
      for (var street = 0; street < 3; street++) {
        engine.apply(seatIndex: 2, action: const GameAction.check());
        engine.apply(seatIndex: 0, action: const GameAction.check());
      }

      expect(state.seatAt(1).chips, 0);
      expect(state.seatAt(1).sittingOut, isTrue);
      expect(state.seatAt(1).isOccupied, isTrue, reason: '자리에서 내보내지는 않는다');
      expect(state.seatAt(2).chips, 1080);
      expect(state.readySeats, hasLength(2));
    });
  });

  test('테이블 상태는 직렬화해도 그대로다', () {
    final state = seatPlayers(<int>[1000, 1000, 1000], button: 2);
    HoldemEngine(state).startHand();

    final restored = TableState.fromJson(state.toJson(viewerUid: 'u0'));

    expect(restored.phase, state.phase);
    expect(restored.buttonSeat, state.buttonSeat);
    expect(restored.currentBet, state.currentBet);
    expect(restored.actingSeat, state.actingSeat);
    expect(restored.seatAt(1).roundBet, state.seatAt(1).roundBet);
    expect(restored.seatAt(0).holeCards, state.seatAt(0).holeCards);
    expect(restored.seatAt(1).holeCards, isEmpty, reason: '남의 카드는 실리지 않는다');
  });
}
