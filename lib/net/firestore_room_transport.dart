import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../engine/table_config.dart';
import '../engine/table_state.dart';
import 'firebase_gate.dart';
import 'room_command.dart';
import 'room_transport.dart';

/// 방을 찾지 못했거나 들어갈 수 없을 때.
class RoomUnavailableException implements Exception {
  const RoomUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Firestore로 방을 주고받는 통로.
///
/// 문서 구조는 이렇게 나눈다.
///
///   rooms/{code}                  공개 테이블 상태. 방장만 쓴다.
///   rooms/{code}/private/{uid}    그 사람에게만 보이는 홀 카드.
///   rooms/{code}/secret/host      남은 덱과 모두의 홀 카드. 방장만 읽는다.
///   rooms/{code}/commands/{id}    참가자가 보내는 요청. 방장이 읽고 지운다.
///
/// 남의 홀 카드가 공개 문서에 실리지 않는 것이 핵심이다. 규칙 파일
/// (firestore.rules)이 이 경계를 강제한다.
class FirestoreRoomTransport implements RoomTransport {
  FirestoreRoomTransport._({
    required this.roomId,
    required this.myUid,
    required this.isHost,
  });

  /// 방 코드에 쓰는 글자. 0/O, 1/I처럼 헷갈리는 것은 뺐다.
  static const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _codeLength = 5;

  @override
  final String roomId;

  @override
  final String myUid;

  @override
  final bool isHost;

  @override
  bool get isOnline => true;

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// 새 방을 판다. 코드가 겹치면 다른 코드로 몇 번 더 시도한다.
  static Future<FirestoreRoomTransport> create({
    required TableConfig config,
  }) async {
    final uid = await _requireUid();
    final random = math.Random.secure();

    for (var attempt = 0; attempt < 8; attempt++) {
      final code = List<String>.generate(
        _codeLength,
        (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)],
      ).join();
      final doc = _db.collection('rooms').doc(code);
      try {
        await doc.set(<String, dynamic>{
          'hostUid': uid,
          'config': config.toJson(),
          'createdAtMs': DateTime.now().millisecondsSinceEpoch,
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        });
        return FirestoreRoomTransport._(
          roomId: code,
          myUid: uid,
          isHost: true,
        );
      } on FirebaseException catch (error) {
        // 이미 쓰고 있는 코드면 규칙이 막는다. 다른 코드로 다시 해 본다.
        if (error.code != 'permission-denied') {
          rethrow;
        }
      }
    }
    throw const RoomUnavailableException('방을 만들지 못했습니다. 잠시 뒤 다시 시도해 주세요.');
  }

  /// 코드로 방에 들어간다.
  static Future<FirestoreRoomTransport> join(String code) async {
    final uid = await _requireUid();
    final roomId = code.trim().toUpperCase();
    if (roomId.isEmpty) {
      throw const RoomUnavailableException('방 코드를 입력해 주세요.');
    }

    final snapshot = await _db.collection('rooms').doc(roomId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw RoomUnavailableException('$roomId 방을 찾지 못했습니다.');
    }
    return FirestoreRoomTransport._(
      roomId: roomId,
      myUid: uid,
      isHost: data['hostUid'] == uid,
    );
  }

  static Future<String> _requireUid() async {
    if (!await FirebaseGate.ensureReady()) {
      throw RoomUnavailableException(
        FirebaseGate.problem ?? '온라인에 연결하지 못했습니다.',
      );
    }
    final uid = FirebaseGate.uid;
    if (uid == null) {
      throw const RoomUnavailableException('로그인하지 못했습니다.');
    }
    return uid;
  }

  DocumentReference<Map<String, dynamic>> get _room =>
      _db.collection('rooms').doc(roomId);

  CollectionReference<Map<String, dynamic>> get _commands =>
      _room.collection('commands');

  DocumentReference<Map<String, dynamic>> get _secret =>
      _room.collection('secret').doc('host');

  @override
  Stream<TableState?> watchTable() => _room.snapshots().map((snapshot) {
    final table = snapshot.data()?['table'];
    if (table is! Map) {
      return null;
    }
    return TableState.fromJson(Map<String, dynamic>.from(table));
  });

  @override
  Stream<(int, List<String>)> watchMyHoleCards() =>
      _room.collection('private').doc(myUid).snapshots().map((snapshot) {
        final data = snapshot.data();
        if (data == null) {
          return (-1, const <String>[]);
        }
        return (
          (data['handNumber'] as num?)?.toInt() ?? -1,
          <String>[
            for (final code in (data['cards'] as List<dynamic>? ?? const []))
              '$code',
          ],
        );
      });

  @override
  Stream<List<RoomCommand>> watchCommands() {
    if (!isHost) {
      return const Stream<List<RoomCommand>>.empty();
    }
    return _commands.orderBy('createdAtMs').snapshots().map(
      (snapshot) => <RoomCommand>[
        for (final doc in snapshot.docs) RoomCommand.fromJson(doc.id, doc.data()),
      ],
    );
  }

  @override
  Future<void> sendCommand(RoomCommand command) =>
      _commands.add(command.toJson());

  @override
  Future<void> publish({
    required TableState table,
    required Map<String, List<String>> holeCardsByUid,
    required List<String> deck,
    required List<String> consumedCommandIds,
  }) async {
    final batch = _db.batch();

    // 공개 문서에는 viewerUid를 주지 않는다. 남의 홀 카드는 여기 실리지 않는다.
    batch.set(_room, <String, dynamic>{
      'table': table.toJson(),
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));

    for (final entry in holeCardsByUid.entries) {
      batch.set(_room.collection('private').doc(entry.key), <String, dynamic>{
        'handNumber': table.handNumber,
        'cards': entry.value,
      });
    }

    batch.set(_secret, <String, dynamic>{
      'handNumber': table.handNumber,
      'deck': deck,
      'holes': holeCardsByUid,
    });

    for (final id in consumedCommandIds) {
      batch.delete(_commands.doc(id));
    }

    await batch.commit();
  }

  @override
  Future<({List<String> deck, Map<String, List<String>> holes})>
  loadSecret() async {
    final data = (await _secret.get()).data();
    if (data == null) {
      return (deck: const <String>[], holes: const <String, List<String>>{});
    }
    return (
      deck: <String>[
        for (final code in (data['deck'] as List<dynamic>? ?? const [])) '$code',
      ],
      holes: <String, List<String>>{
        for (final entry
            in (data['holes'] as Map<dynamic, dynamic>? ?? const {}).entries)
          '${entry.key}': <String>[
            for (final code in (entry.value as List<dynamic>? ?? const []))
              '$code',
          ],
      },
    );
  }

  @override
  Future<void> close() async {}
}
