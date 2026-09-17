import 'dart:math' as math;

import 'card.dart';
import 'deck.dart';
import 'game_action.dart';
import 'hand_evaluator.dart';
import 'hand_rank.dart';
import 'hand_result.dart';
import 'pot.dart';
import 'seat.dart';
import 'table_config.dart';
import 'table_state.dart';

/// 규칙에 어긋난 액션이 들어왔을 때 던진다.
///
/// 남이 보낸 액션을 그대로 믿지 않고 여기서 한 번 더 거르기 때문에, 화면이
/// 잠깐 어긋나 있거나 누가 문서를 직접 고쳐도 판이 망가지지 않는다.
class IllegalActionException implements Exception {
  const IllegalActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 노 리밋 텍사스 홀덤 한 판의 규칙을 담은 상태 기계.
///
/// 화면도 네트워크도 모른다. [TableState] 하나를 받아 고쳐 나갈 뿐이라서,
/// 방장 기기에서 돌리든 나중에 서버로 옮기든 그대로 쓸 수 있다.
class HoldemEngine {
  HoldemEngine(
    this.state, {
    math.Random? random,
    DateTime Function()? clock,
    this.deckFactory,
  }) : _random = random ?? math.Random.secure(),
       _clock = clock ?? DateTime.now;

  final TableState state;
  final math.Random _random;
  final DateTime Function() _clock;

  /// 핸드를 시작할 때 덱을 만드는 방법.
  ///
  /// 비워 두면 매번 새로 잘 섞는다. 테스트에서 정해진 순서의 덱을 물려줄 때만
  /// 채운다.
  final Deck Function()? deckFactory;

  Deck? _deck;

  TableConfig get config => state.config;

  /// 진행 중인 핸드의 남은 덱. 방장이 저장해 두었다가 되살릴 때 쓴다.
  Deck? get deck => _deck;

  void restoreDeck(List<String> codes) => _deck = Deck.fromCodes(codes);

  /// 핸드를 시작할 수 있는 인원이 모였는가.
  bool get canStartHand => state.readySeats.length >= 2;

  // ------------------------------------------------------------- 핸드 시작

  /// 새 핸드를 돌린다. 버튼을 옮기고 블라인드를 걷은 뒤 두 장씩 나눠 준다.
  void startHand() {
    if (!canStartHand) {
      throw const IllegalActionException('두 명 이상 있어야 시작할 수 있습니다.');
    }

    for (final seat in state.seats) {
      seat.resetForHand();
      if (seat.isOccupied && seat.chips <= 0) {
        seat.sittingOut = true;
      }
    }

    state
      ..handNumber += 1
      ..phase = HandPhase.preflop
      ..community = const <PlayingCard>[]
      ..pots = const <Pot>[]
      ..result = null
      ..message = null
      ..actionCounter = 0;

    // 버튼을 다음 참가자에게 넘긴다. 자리가 비어 있으면 건너뛴다.
    state.buttonSeat = _nextIndex(state.buttonSeat, (seat) => seat.isReadyForHand);
    for (final seat in state.readySeats) {
      seat.inHand = true;
    }

    // 2명일 때는 버튼이 곧 스몰 블라인드이고 프리플랍에서 먼저 친다.
    // 3명 이상이면 버튼 왼쪽부터 스몰·빅 블라인드 순이다.
    final headsUp = state.activeSeats.length == 2;
    final smallBlindSeat = headsUp
        ? state.buttonSeat
        : _nextIndex(state.buttonSeat, (seat) => seat.inHand);
    final bigBlindSeat = _nextIndex(smallBlindSeat, (seat) => seat.inHand);

    _postBlind(state.seatAt(smallBlindSeat), config.smallBlind, 'SB');
    _postBlind(state.seatAt(bigBlindSeat), config.bigBlind, 'BB');
    state
      ..currentBet = config.bigBlind
      ..minRaise = config.bigBlind;

    _deck = deckFactory?.call() ?? Deck.shuffled(random: _random);
    final order = _orderFrom(state.buttonSeat, (seat) => seat.inHand);
    for (var round = 0; round < 2; round++) {
      for (final seat in order) {
        seat.holeCards = <PlayingCard>[...seat.holeCards, _deck!.draw()];
      }
    }

    // 블라인드만으로 이미 전원 올인이 된 판은 받을 액션이 없다. 보드만 깐다.
    final first = _nextIndex(bigBlindSeat, (seat) => seat.canAct);
    if (first < 0 || _ableToAct().length < 2) {
      _closeBettingRound();
      _openNextStreet();
    } else {
      _setActing(first);
    }
  }

  /// 블라인드를 건다. 블라인드는 '행동'으로 치지 않아서, 모두가 콜만 하고
  /// 돌아오면 빅 블라인드에게 레이즈할 기회가 한 번 더 간다.
  void _postBlind(PlayerSeat seat, int amount, String label) {
    final paid = seat.commit(amount);
    seat
      ..lastActionLabel = paid < amount ? '$label 올인' : label
      ..hasActed = false;
  }

  // ------------------------------------------------------------- 액션 처리

  /// [seatIndex]가 지금 고를 수 있는 선택지.
  ActionOptions optionsFor(int seatIndex) {
    if (!state.phase.isBetting || state.actingSeat != seatIndex) {
      return ActionOptions.none;
    }
    final seat = state.seatAt(seatIndex);
    if (!seat.canAct) {
      return ActionOptions.none;
    }

    final toCall = state.currentBet - seat.roundBet;
    final canCheck = toCall <= 0;
    final callAmount = toCall < seat.chips ? toCall : seat.chips;

    // 올인했을 때의 이번 라운드 누적 금액. 레이즈 상한이 된다.
    final maxRaiseTo = seat.roundBet + seat.chips;
    final wantedMin = state.currentBet + state.minRaise;

    return ActionOptions(
      seatIndex: seatIndex,
      canFold: true,
      canCheck: canCheck,
      canCall: !canCheck && callAmount > 0,
      callAmount: canCheck ? 0 : callAmount,
      // 이미 행동한 뒤에 '부족한 올인'만 끼어들었다면 다시 올릴 수는 없다.
      // 제대로 된 레이즈가 나왔을 때만 hasActed가 풀리기 때문에, 이 플래그
      // 하나로 "베팅이 다시 열렸는가"를 그대로 읽을 수 있다.
      canRaise: maxRaiseTo > state.currentBet && !seat.hasActed,
      minRaiseTo: wantedMin < maxRaiseTo ? wantedMin : maxRaiseTo,
      maxRaiseTo: maxRaiseTo,
      isReraise: state.currentBet > 0,
      chips: seat.chips,
      roundBet: seat.roundBet,
    );
  }

  /// 액션 하나를 반영한다. 규칙에 어긋나면 [IllegalActionException]을 던진다.
  void apply({required int seatIndex, required GameAction action}) {
    if (!state.phase.isBetting) {
      throw const IllegalActionException('지금은 베팅할 때가 아닙니다.');
    }
    if (state.actingSeat != seatIndex) {
      throw const IllegalActionException('아직 차례가 아닙니다.');
    }
    final seat = state.seatAt(seatIndex);
    final options = optionsFor(seatIndex);
    if (!options.isActive) {
      throw const IllegalActionException('행동할 수 있는 자리가 아닙니다.');
    }

    switch (action.type) {
      case ActionType.fold:
        seat
          ..hasFolded = true
          ..lastActionLabel = '폴드';
      case ActionType.check:
        if (!options.canCheck) {
          throw const IllegalActionException('맞춰야 할 금액이 남아 체크할 수 없습니다.');
        }
        seat.lastActionLabel = '체크';
      case ActionType.call:
        if (!options.canCall) {
          throw const IllegalActionException('콜할 금액이 없습니다.');
        }
        seat
          ..commit(options.callAmount)
          ..lastActionLabel = seat.isAllIn ? '올인 ${seat.roundBet}' : '콜';
      case ActionType.bet:
      case ActionType.raise:
        _raiseTo(seat, action.amount, options);
      case ActionType.allIn:
        _raiseTo(seat, options.maxRaiseTo, options);
    }

    seat.hasActed = true;
    state.actionCounter += 1;
    _advance();
  }

  /// 제한 시간을 넘긴 사람을 대신 처리한다. 체크할 수 있으면 체크, 아니면 폴드.
  void applyTimeout() {
    final acting = state.actingSeat;
    if (acting == null) {
      return;
    }
    final options = optionsFor(acting);
    if (!options.isActive) {
      return;
    }
    apply(
      seatIndex: acting,
      action: options.canCheck
          ? const GameAction.check()
          : const GameAction.fold(),
    );
  }

  /// [target]까지 올린다. 칩이 모자라면 올인으로 처리한다.
  void _raiseTo(PlayerSeat seat, int target, ActionOptions options) {
    final maxRaiseTo = options.maxRaiseTo;
    if (target > maxRaiseTo) {
      throw const IllegalActionException('가진 칩보다 많이 걸 수는 없습니다.');
    }

    // 전부 밀어도 현재 베팅에 못 미치면 '모자란 콜'이다. 레이즈가 아니다.
    if (target >= maxRaiseTo && maxRaiseTo <= state.currentBet) {
      seat
        ..commit(seat.chips)
        ..lastActionLabel = '올인 ${seat.roundBet}';
      return;
    }
    if (target <= state.currentBet) {
      throw const IllegalActionException('앞사람보다 높게 올려야 합니다.');
    }
    if (!options.canRaise) {
      throw const IllegalActionException('베팅이 다시 열리지 않아 콜이나 폴드만 할 수 있습니다.');
    }

    final isAllIn = target >= maxRaiseTo;
    final minimum = state.currentBet + state.minRaise;
    if (!isAllIn && target < minimum) {
      throw IllegalActionException('최소 $minimum까지 올려야 합니다.');
    }

    final increment = target - state.currentBet;
    final wasOpen = state.currentBet > 0;
    seat.commit(target - seat.roundBet);
    seat.lastActionLabel = seat.isAllIn
        ? '올인 ${seat.roundBet}'
        : '${wasOpen ? "레이즈" : "벳"} ${seat.roundBet}';
    state.currentBet = seat.roundBet;

    // 최소 폭을 채운 레이즈라야 이미 행동한 사람들의 차례가 다시 열린다.
    // 칩이 모자라 어중간하게 올린 올인은 차례를 다시 열지 않는다.
    if (increment >= state.minRaise) {
      state.minRaise = increment;
      for (final other in state.seats) {
        if (other.index != seat.index && other.canAct) {
          other.hasActed = false;
        }
      }
    }
  }

  // --------------------------------------------------------------- 진행 제어

  void _advance() {
    if (state.activeSeats.length <= 1) {
      _awardUncontested();
      return;
    }
    if (!_isRoundComplete()) {
      final next = _nextIndex(state.actingSeat!, (seat) => seat.canAct);
      if (next >= 0) {
        _setActing(next);
        return;
      }
    }
    _closeBettingRound();
    _openNextStreet();
  }

  /// 살아 있고 칩도 남은 사람들이 모두 행동했고 금액도 맞췄는가.
  bool _isRoundComplete() {
    for (final seat in state.seats) {
      if (!seat.canAct) {
        continue;
      }
      if (!seat.hasActed || seat.roundBet != state.currentBet) {
        return false;
      }
    }
    return true;
  }

  void _closeBettingRound() {
    _returnUncalledBet();
    for (final seat in state.seats) {
      seat.resetForRound();
    }
    state
      ..currentBet = 0
      ..minRaise = config.bigBlind
      ..actingSeat = null
      ..actionDeadlineMs = null;
  }

  /// 아무도 받아 주지 않은 베팅을 돌려준다.
  ///
  /// 300을 걸었는데 남은 사람이 100까지밖에 못 따라왔다면, 남는 200은 애초에
  /// 승부에 걸린 적이 없으므로 그대로 스택으로 되돌아간다.
  void _returnUncalledBet() {
    PlayerSeat? top;
    var second = 0;
    for (final seat in state.seats) {
      if (seat.roundBet <= 0) {
        continue;
      }
      if (top == null || seat.roundBet > top.roundBet) {
        second = top?.roundBet ?? second;
        top = seat;
      } else if (seat.roundBet > second) {
        second = seat.roundBet;
      }
    }
    if (top == null) {
      return;
    }
    final excess = top.roundBet - second;
    if (excess <= 0) {
      return;
    }
    top
      ..chips += excess
      ..roundBet -= excess
      ..handBet -= excess;
  }

  /// 다음 스트리트를 연다. 베팅할 수 있는 사람이 둘 미만이면 보드만 계속 깐다.
  void _openNextStreet() {
    while (true) {
      if (state.phase == HandPhase.river) {
        _showdown();
        return;
      }
      _dealStreet();
      if (state.activeSeats.length <= 1) {
        _awardUncontested();
        return;
      }
      if (_ableToAct().length >= 2) {
        _setActing(_nextIndex(state.buttonSeat, (seat) => seat.canAct));
        return;
      }
    }
  }

  void _dealStreet() {
    final deck = _deck;
    if (deck == null) {
      throw StateError('진행 중인 덱이 없습니다.');
    }
    // 카드를 한 장 태우는 것은 관례다. 승부에 영향은 없다.
    deck.burn();
    switch (state.phase) {
      case HandPhase.preflop:
        state
          ..community = <PlayingCard>[...state.community, ...deck.drawMany(3)]
          ..phase = HandPhase.flop;
      case HandPhase.flop:
        state
          ..community = <PlayingCard>[...state.community, deck.draw()]
          ..phase = HandPhase.turn;
      case HandPhase.turn:
        state
          ..community = <PlayingCard>[...state.community, deck.draw()]
          ..phase = HandPhase.river;
      case _:
        throw StateError('${state.phase.label}에서는 카드를 더 깔 수 없습니다.');
    }
  }

  // ------------------------------------------------------------------- 정산

  /// 나머지가 다 폴드해서 한 사람만 남았다. 카드를 까지 않고 팟을 넘긴다.
  void _awardUncontested() {
    _returnUncalledBet();

    final survivors = state.activeSeats;
    final amount = state.totalPot;
    final winnings = <int, int>{};
    final awards = <PotAward>[];

    if (survivors.length == 1 && amount > 0) {
      final winner = survivors.single;
      winner.chips += amount;
      winnings[winner.index] = amount;
      awards.add(
        PotAward(label: '팟', amount: amount, winnerSeats: <int>[winner.index]),
      );
      state.pots = <Pot>[
        Pot(amount: amount, eligibleSeats: <int>[winner.index]),
      ];
    }

    state.result = HandResult(
      wentToShowdown: false,
      awards: awards,
      winnings: winnings,
      rankings: const <int, HandRank>{},
    );
    _finishHand();
  }

  /// 패를 까고 팟을 나눈다.
  void _showdown() {
    final pots = buildPots(state.seats);
    state.pots = pots;

    final rankings = <int, HandRank>{};
    for (final seat in state.activeSeats) {
      rankings[seat.index] = HandEvaluator.best(<PlayingCard>[
        ...seat.holeCards,
        ...state.community,
      ]);
      seat.revealed = true;
    }

    final awards = <PotAward>[];
    final winnings = <int, int>{};
    for (var i = 0; i < pots.length; i++) {
      final pot = pots[i];
      HandRank? best;
      final winners = <int>[];
      for (final index in pot.eligibleSeats) {
        final rank = rankings[index];
        if (rank == null) {
          continue;
        }
        if (best == null || rank > best) {
          best = rank;
          winners
            ..clear()
            ..add(index);
        } else if (rank == best) {
          winners.add(index);
        }
      }
      if (winners.isEmpty) {
        continue;
      }
      _payout(pot.amount, winners, winnings);
      awards.add(
        PotAward(
          label: _potLabel(i, pots.length),
          amount: pot.amount,
          winnerSeats: winners,
        ),
      );
    }

    state.result = HandResult(
      wentToShowdown: true,
      awards: awards,
      winnings: winnings,
      rankings: rankings,
    );
    _finishHand();
  }

  /// 팟 하나를 [winners]에게 나눠 준다.
  void _payout(int amount, List<int> winners, Map<int, int> winnings) {
    final share = amount ~/ winners.length;
    var remainder = amount - share * winners.length;
    // 나누어떨어지지 않는 칩은 버튼 왼쪽 사람부터 한 칩씩 더 가져간다.
    for (final index in _orderFromButton(winners)) {
      var take = share;
      if (remainder > 0) {
        take += 1;
        remainder -= 1;
      }
      state.seatAt(index).chips += take;
      winnings[index] = (winnings[index] ?? 0) + take;
    }
  }

  void _finishHand() {
    for (final seat in state.seats) {
      seat
        ..roundBet = 0
        ..handBet = 0
        ..hasActed = false;
      if (seat.isOccupied && seat.chips <= 0) {
        seat.sittingOut = true;
      }
    }
    state
      ..phase = HandPhase.showdown
      ..currentBet = 0
      ..minRaise = 0
      ..actingSeat = null
      ..actionDeadlineMs = null;
    _deck = null;
  }

  // ------------------------------------------------------------------- 보조

  List<PlayerSeat> _ableToAct() =>
      state.seats.where((seat) => seat.canAct).toList(growable: false);

  void _setActing(int index) {
    state
      ..actingSeat = index
      ..actionDeadlineMs =
          _clock().millisecondsSinceEpoch + config.actionSeconds * 1000;
  }

  /// [from]에서 시계 방향으로 돌면서 [test]를 만족하는 첫 자리. 없으면 -1.
  int _nextIndex(int from, bool Function(PlayerSeat) test) {
    final count = state.seats.length;
    for (var step = 1; step <= count; step++) {
      final index = (from + step) % count;
      if (test(state.seats[index])) {
        return index;
      }
    }
    return -1;
  }

  /// [from] 다음 자리부터 시계 방향으로 [test]를 만족하는 자리들.
  List<PlayerSeat> _orderFrom(int from, bool Function(PlayerSeat) test) {
    final count = state.seats.length;
    return <PlayerSeat>[
      for (var step = 1; step <= count; step++)
        if (test(state.seats[(from + step) % count]))
          state.seats[(from + step) % count],
    ];
  }

  /// 버튼 왼쪽부터의 순서로 늘어놓는다.
  List<int> _orderFromButton(List<int> indices) {
    final count = state.seats.length;
    int distance(int index) =>
        (index - state.buttonSeat - 1 + count * 2) % count;
    return indices.toList()
      ..sort((a, b) => distance(a).compareTo(distance(b)));
  }

  static String _potLabel(int index, int count) {
    if (count <= 1) {
      return '팟';
    }
    return index == 0 ? '메인 팟' : '사이드 팟 $index';
  }
}

/// 사람이 모자라 더는 돌릴 수 없을 때 대기 상태로 되돌린다.
///
/// 지난 핸드 결과([TableState.result])는 남겨 둔다. 마지막 판이 어떻게 끝났는지는
/// 기다리는 동안에도 보여 주는 편이 낫다.
extension HoldemEngineReset on HoldemEngine {
  void resetToWaiting() {
    for (final seat in state.seats) {
      seat.resetForHand();
    }
    state
      ..phase = HandPhase.waiting
      ..community = const <PlayingCard>[]
      ..pots = const <Pot>[]
      ..currentBet = 0
      ..minRaise = 0
      ..actingSeat = null
      ..actionDeadlineMs = null;
  }
}
