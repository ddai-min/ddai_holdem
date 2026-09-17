import '../engine/table_state.dart';
import 'room_command.dart';

/// 방 하나를 주고받는 통로.
///
/// [RoomSession]은 이 인터페이스만 보고 돌아간다. Firestore를 쓰든 기기 안
/// 메모리를 쓰든 게임 진행 코드는 똑같다.
abstract class RoomTransport {
  /// 방 코드. 친구에게 알려 주는 그 값이다.
  String get roomId;

  String get myUid;

  /// 내가 이 방의 진행을 맡고 있는가.
  bool get isHost;

  /// 다른 기기와 이어져 있는가. 거짓이면 혼자 하는 연습 모드다.
  bool get isOnline;

  /// 공개 테이블 상태. 아직 아무것도 없으면 null이 흐른다.
  Stream<TableState?> watchTable();

  /// 나에게만 보이는 홀 카드. `(핸드 번호, 카드 표기들)`.
  Stream<(int, List<String>)> watchMyHoleCards();

  /// 방장이 처리해야 할 명령들. 방장이 아니면 빈 스트림이다.
  Stream<List<RoomCommand>> watchCommands();

  /// 명령을 보낸다.
  Future<void> sendCommand(RoomCommand command);

  /// 방장이 한 번에 결과를 올린다.
  ///
  /// 테이블·홀 카드·남은 덱·처리한 명령 삭제를 한 묶음으로 처리해서, 중간
  /// 상태가 남에게 보이지 않게 한다.
  Future<void> publish({
    required TableState table,
    required Map<String, List<String>> holeCardsByUid,
    required List<String> deck,
    required List<String> consumedCommandIds,
  });

  /// 방장만 읽을 수 있는 비밀 문서.
  ///
  /// 진행 중이던 핸드의 남은 덱과 모두의 홀 카드가 들어 있다. 방장 기기가
  /// 잠깐 끊겼다 돌아와도 돌리던 판을 그대로 이어 가기 위한 것이다.
  Future<({List<String> deck, Map<String, List<String>> holes})> loadSecret();

  Future<void> close();
}
