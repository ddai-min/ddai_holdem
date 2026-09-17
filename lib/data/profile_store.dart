import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

/// 기기에 남겨 두는 내 설정. 지금은 닉네임 하나뿐이다.
abstract class ProfileStore {
  String get nickname;

  Future<void> saveNickname(String value);

  /// 저장소를 열지 못해도 게임은 뜨게 한다.
  static Future<ProfileStore> open() async {
    try {
      return await _PreferencesProfileStore.open();
    } catch (_) {
      return InMemoryProfileStore();
    }
  }
}

class InMemoryProfileStore implements ProfileStore {
  InMemoryProfileStore([this._nickname = '']);

  String _nickname;

  @override
  String get nickname => _nickname;

  @override
  Future<void> saveNickname(String value) async => _nickname = value;
}

class _PreferencesProfileStore implements ProfileStore {
  _PreferencesProfileStore(this._preferences, this._nickname);

  static const String _key = 'nickname';

  static Future<_PreferencesProfileStore> open() async {
    final preferences = await SharedPreferences.getInstance();
    return _PreferencesProfileStore(
      preferences,
      preferences.getString(_key) ?? '',
    );
  }

  final SharedPreferences _preferences;
  String _nickname;

  @override
  String get nickname => _nickname;

  @override
  Future<void> saveNickname(String value) async {
    _nickname = value;
    await _preferences.setString(_key, value);
  }
}

/// 닉네임을 비워 둔 사람에게 붙여 줄 이름.
String randomNickname([math.Random? random]) {
  const adjectives = <String>['조용한', '느긋한', '날카로운', '든든한', '재빠른', '태연한'];
  const nouns = <String>['플레이어', '딜러', '올인러', '레이저', '콜러', '블러퍼'];
  final rng = random ?? math.Random();
  return '${adjectives[rng.nextInt(adjectives.length)]} '
      '${nouns[rng.nextInt(nouns.length)]}';
}
