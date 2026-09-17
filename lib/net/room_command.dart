import 'package:meta/meta.dart';

import '../engine/game_action.dart';

/// 참가자가 방장에게 보내는 요청.
///
/// 모든 변경은 이 명령 하나로 통일한다. 참가자는 테이블 문서를 직접 고칠 수
/// 없고, 방장만 규칙을 통과한 결과를 써넣는다. 그래서 문서를 직접 건드려도
/// 판이 어그러지지 않는다.
enum RoomCommandType {
  /// 빈자리에 앉는다.
  join,

  /// 자리를 비운다.
  leave,

  /// 다음 핸드를 쉰다 / 다시 참가한다.
  sitOut,
  sitIn,

  /// 핸드를 시작한다. 방장만 보낼 수 있다.
  startHand,

  /// 베팅 액션.
  play,
}

@immutable
class RoomCommand {
  const RoomCommand({
    required this.id,
    required this.uid,
    required this.type,
    this.name = '',
    this.action,
    this.handNumber = 0,
    this.actionCounter = 0,
    this.createdAtMs = 0,
  });

  /// 문서 id. 처리한 뒤 지우는 데 쓴다.
  final String id;

  final String uid;
  final RoomCommandType type;

  /// [RoomCommandType.join]일 때의 닉네임.
  final String name;

  /// [RoomCommandType.play]일 때의 베팅 액션.
  final GameAction? action;

  /// 보낼 때 화면에 보이던 핸드 번호와 액션 번호.
  ///
  /// 방장은 이 둘이 지금 상태와 어긋난 명령을 버린다. 버튼을 두 번 눌렀거나
  /// 통신이 늦어 한발 늦게 도착한 액션이 두 번 반영되는 일을 막는다.
  final int handNumber;
  final int actionCounter;

  final int createdAtMs;

  RoomCommand withId(String id) => RoomCommand(
    id: id,
    uid: uid,
    type: type,
    name: name,
    action: action,
    handNumber: handNumber,
    actionCounter: actionCounter,
    createdAtMs: createdAtMs,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'uid': uid,
    'type': type.name,
    'name': name,
    if (action != null) 'action': action!.toJson(),
    'handNumber': handNumber,
    'actionCounter': actionCounter,
    'createdAtMs': createdAtMs,
  };

  factory RoomCommand.fromJson(String id, Map<String, dynamic> json) {
    final action = json['action'];
    return RoomCommand(
      id: id,
      uid: '${json['uid'] ?? ''}',
      type: RoomCommandType.values.byName('${json['type'] ?? 'play'}'),
      name: '${json['name'] ?? ''}',
      action: action is Map
          ? GameAction.fromJson(Map<String, dynamic>.from(action))
          : null,
      handNumber: (json['handNumber'] as num?)?.toInt() ?? 0,
      actionCounter: (json['actionCounter'] as num?)?.toInt() ?? 0,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
