import 'card.dart';

/// 테이블의 자리 하나.
///
/// 비어 있는 자리도 객체로 남겨 둔다. 자리 번호가 화면 위 위치와 그대로
/// 이어지기 때문에, 사람이 나갔다고 목록에서 빼 버리면 남은 사람들이 자리를
/// 옮겨 다니는 것처럼 보인다.
class PlayerSeat {
  PlayerSeat({
    required this.index,
    this.uid,
    this.name = '',
    this.chips = 0,
    this.connected = true,
    this.sittingOut = false,
  });

  /// 자리 번호. 0번이 화면 아래 가운데(내 자리 기준 회전 전)다.
  final int index;

  String? uid;
  String name;
  int chips;

  /// 접속 상태. 끊긴 사람은 차례가 와도 자동으로 넘긴다.
  bool connected;

  /// 다음 핸드를 쉰다. 칩이 떨어졌거나 본인이 골랐을 때 켜진다.
  bool sittingOut;

  // ------------------------------------------------ 이번 핸드에서만 쓰는 값들

  /// 이번 핸드에 카드를 받았는가.
  bool inHand = false;

  bool hasFolded = false;

  /// 이번 베팅 라운드에 낸 칩. 자리 앞에 쌓인 칩으로 그려진다.
  int roundBet = 0;

  /// 이번 핸드에 낸 칩 전부. 사이드 팟을 나눌 때 기준이 된다.
  int handBet = 0;

  /// 이번 라운드에 한 번이라도 행동했는가.
  ///
  /// 블라인드를 낸 것은 행동으로 치지 않는다. 그래야 모두가 콜만 하고 돌아왔을
  /// 때 빅 블라인드에게 "레이즈할래?" 기회가 한 번 더 간다.
  bool hasActed = false;

  /// 받은 두 장. 남의 카드는 쇼다운 전까지 비어 있다.
  List<PlayingCard> holeCards = const <PlayingCard>[];

  /// 쇼다운에서 공개된 자리인가.
  bool revealed = false;

  /// 마지막으로 한 행동. 자리 위에 "콜", "레이즈 200"처럼 잠깐 띄운다.
  String? lastActionLabel;

  bool get isOccupied => uid != null;

  /// 이번 핸드에 아직 살아 있는가.
  bool get isActive => inHand && !hasFolded;

  /// 칩을 다 밀어 넣어 더 낼 것이 없는가.
  bool get isAllIn => isActive && chips == 0;

  /// 차례가 돌아올 수 있는 상태인가.
  bool get canAct => isActive && chips > 0;

  /// 다음 핸드에 참가할 수 있는가.
  bool get isReadyForHand => isOccupied && !sittingOut && chips > 0;

  /// 핸드를 새로 시작할 때 초기화한다. 칩과 사람은 그대로 둔다.
  void resetForHand() {
    inHand = false;
    hasFolded = false;
    roundBet = 0;
    handBet = 0;
    hasActed = false;
    holeCards = const <PlayingCard>[];
    revealed = false;
    lastActionLabel = null;
  }

  /// 베팅 라운드가 끝날 때 자리 앞 칩을 팟으로 넘긴다.
  void resetForRound() {
    roundBet = 0;
    hasActed = false;
    lastActionLabel = null;
  }

  /// [amount]만큼 칩을 밀어 넣는다. 스택보다 크면 있는 만큼만 낸다.
  ///
  /// 실제로 낸 금액을 돌려준다.
  int commit(int amount) {
    final paid = amount < chips ? amount : chips;
    if (paid <= 0) {
      return 0;
    }
    chips -= paid;
    roundBet += paid;
    handBet += paid;
    return paid;
  }

  void sit({required String uid, required String name, required int chips}) {
    this.uid = uid;
    this.name = name;
    this.chips = chips;
    connected = true;
    sittingOut = false;
    resetForHand();
  }

  void leave() {
    uid = null;
    name = '';
    chips = 0;
    connected = false;
    sittingOut = false;
    resetForHand();
  }

  /// [includeHoleCards]가 거짓이면 홀 카드를 빼고 담는다.
  ///
  /// 공개 문서에는 절대 남의 카드가 들어가면 안 된다. 쇼다운에서 공개된
  /// 자리([revealed])만 예외다.
  Map<String, dynamic> toJson({bool includeHoleCards = false}) =>
      <String, dynamic>{
        'index': index,
        if (uid != null) 'uid': uid,
        'name': name,
        'chips': chips,
        'connected': connected,
        'sittingOut': sittingOut,
        'inHand': inHand,
        'hasFolded': hasFolded,
        'roundBet': roundBet,
        'handBet': handBet,
        'hasActed': hasActed,
        'revealed': revealed,
        if (lastActionLabel != null) 'lastActionLabel': lastActionLabel,
        if (includeHoleCards || revealed) 'holeCards': encodeCards(holeCards),
      };

  factory PlayerSeat.fromJson(Map<String, dynamic> json) {
    final seat = PlayerSeat(
      index: (json['index'] as num).toInt(),
      uid: json['uid'] as String?,
      name: '${json['name'] ?? ''}',
      chips: (json['chips'] as num?)?.toInt() ?? 0,
      connected: json['connected'] as bool? ?? true,
      sittingOut: json['sittingOut'] as bool? ?? false,
    );
    seat
      ..inHand = json['inHand'] as bool? ?? false
      ..hasFolded = json['hasFolded'] as bool? ?? false
      ..roundBet = (json['roundBet'] as num?)?.toInt() ?? 0
      ..handBet = (json['handBet'] as num?)?.toInt() ?? 0
      ..hasActed = json['hasActed'] as bool? ?? false
      ..revealed = json['revealed'] as bool? ?? false
      ..lastActionLabel = json['lastActionLabel'] as String?
      ..holeCards = decodeCards(json['holeCards'] as List<dynamic>? ?? const []);
    return seat;
  }
}
