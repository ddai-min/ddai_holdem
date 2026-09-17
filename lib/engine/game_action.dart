import 'package:meta/meta.dart';

/// 플레이어가 자기 차례에 할 수 있는 행동.
enum ActionType {
  fold('폴드'),
  check('체크'),
  call('콜'),
  bet('벳'),
  raise('레이즈'),
  allIn('올인');

  const ActionType(this.label);

  final String label;
}

/// 플레이어가 보낸 한 번의 행동.
@immutable
class GameAction {
  const GameAction(this.type, {this.amount = 0});

  const GameAction.fold() : this(ActionType.fold);
  const GameAction.check() : this(ActionType.check);
  const GameAction.call() : this(ActionType.call);
  const GameAction.bet(int to) : this(ActionType.bet, amount: to);
  const GameAction.raise(int to) : this(ActionType.raise, amount: to);
  const GameAction.allIn() : this(ActionType.allIn);

  final ActionType type;

  /// 벳·레이즈에서 "이번 라운드에 총 얼마까지 올리는가". 추가로 내는 칩이
  /// 아니라 누적 금액이다. 이미 30을 낸 사람이 `raise(100)`을 하면 70을 더 낸다.
  final int amount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.name,
    'amount': amount,
  };

  factory GameAction.fromJson(Map<String, dynamic> json) => GameAction(
    ActionType.values.byName('${json['type']}'),
    amount: (json['amount'] as num?)?.toInt() ?? 0,
  );

  @override
  String toString() =>
      amount > 0 ? '${type.label} $amount' : type.label;
}

/// 지금 차례인 사람이 고를 수 있는 선택지. 액션 바가 이 값을 보고 버튼을 켠다.
@immutable
class ActionOptions {
  const ActionOptions({
    required this.seatIndex,
    required this.canFold,
    required this.canCheck,
    required this.canCall,
    required this.callAmount,
    required this.canRaise,
    required this.minRaiseTo,
    required this.maxRaiseTo,
    required this.isReraise,
    required this.chips,
    required this.roundBet,
  });

  /// 아무것도 할 수 없는 상태(내 차례가 아님).
  static const ActionOptions none = ActionOptions(
    seatIndex: -1,
    canFold: false,
    canCheck: false,
    canCall: false,
    callAmount: 0,
    canRaise: false,
    minRaiseTo: 0,
    maxRaiseTo: 0,
    isReraise: false,
    chips: 0,
    roundBet: 0,
  );

  final int seatIndex;
  final bool canFold;
  final bool canCheck;
  final bool canCall;

  /// 콜하려면 추가로 내야 하는 칩. 스택이 모자라면 올인 금액이 된다.
  final int callAmount;

  final bool canRaise;

  /// 레이즈할 수 있는 최소·최대 누적 금액.
  final int minRaiseTo;
  final int maxRaiseTo;

  /// 앞에 이미 베팅이 있어서 '레이즈'인지, 첫 베팅이라 '벳'인지.
  final bool isReraise;

  final int chips;
  final int roundBet;

  bool get isActive => seatIndex >= 0;

  /// 콜하면 그대로 올인이 되는 상황.
  bool get callIsAllIn => canCall && callAmount >= chips;
}
