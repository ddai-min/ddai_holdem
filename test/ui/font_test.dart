import 'dart:io';

import 'package:ddai_holdem/ui/game_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 한글 글꼴이 앱 안에 남아 있는지 지킨다.
///
/// Flutter 웹은 글꼴을 구글 CDN에서 런타임에 받아 온다. 글꼴 지정을 한 군데라도
/// 빠뜨리면 그 글자만 조용히 기본 글꼴로 돌아가고, CDN이 막힌 자리에서는 아예
/// 나오지 않는다. 눈으로 보기 전에는 알 수 없는 종류의 고장이라 테스트로 묶는다.
void main() {
  test('pubspec이 글꼴을 선언하고 파일이 실제로 있다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: $kFontFamily'));

    for (final weight in <String>['Regular', 'Bold']) {
      final asset = File('assets/fonts/NotoSansKR-$weight.ttf');
      expect(asset.existsSync(), isTrue, reason: '${asset.path}가 없다');
      expect(pubspec, contains(asset.path));
    }
    // 재배포 조건이 OFL이다. 라이선스 전문을 함께 둔다.
    expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
  });

  test('테마가 글자를 내는 곳마다 앱 글꼴을 쓴다', () {
    final theme = buildGameTheme();

    expect(theme.textTheme.bodyMedium?.fontFamily, kFontFamily);
    expect(theme.textTheme.labelLarge?.fontFamily, kFontFamily);

    // 컴포넌트 테마가 넘기는 TextStyle은 DefaultTextStyle을 통째로 갈아 끼우므로
    // 테마 글꼴을 물려받지 못한다. 하나씩 직접 얹어야 한다.
    expect(
      theme.filledButtonTheme.style?.textStyle
          ?.resolve(const <WidgetState>{})
          ?.fontFamily,
      kFontFamily,
    );
    expect(theme.snackBarTheme.contentTextStyle?.fontFamily, kFontFamily);
    expect(theme.inputDecorationTheme.labelStyle?.fontFamily, kFontFamily);
  });

  test('Flame 컴포넌트의 TextPaint가 모두 앱 글꼴을 쓴다', () {
    // Flame의 TextPaint는 위젯 테마를 타지 않는다. 테이블을 그리는 쪽은
    // TextStyle마다 글꼴 이름을 직접 얹어야 한다.
    final files = Directory('lib/game/components')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    expect(files, isNotEmpty);

    var checked = 0;
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trim() != 'style: TextStyle(') {
          continue;
        }
        checked++;
        expect(
          lines[i + 1],
          contains('fontFamily: kFontFamily'),
          reason: '${file.path}:${i + 1} 의 TextStyle에 글꼴이 빠졌다',
        );
      }
    }
    expect(checked, 8, reason: 'TextPaint를 더하거나 뺐다면 이 수도 같이 고친다');
  });
}
