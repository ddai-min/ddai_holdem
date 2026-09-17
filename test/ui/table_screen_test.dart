import 'package:ddai_holdem/engine/game_action.dart';
import 'package:ddai_holdem/engine/table_config.dart';
import 'package:ddai_holdem/engine/table_state.dart';
import 'package:ddai_holdem/net/local_room_transport.dart';
import 'package:ddai_holdem/net/room_session.dart';
import 'package:ddai_holdem/ui/game_theme.dart';
import 'package:ddai_holdem/ui/overlays/action_bar.dart';
import 'package:ddai_holdem/ui/overlays/status_bar.dart';
import 'package:ddai_holdem/game/holdem_game.dart';
import 'package:ddai_holdem/ui/screens/table_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const TableConfig _config = TableConfig(
  smallBlind: 10,
  bigBlind: 20,
  startingChips: 1000,
  maxSeats: 6,
);

/// 봇 둘과 함께 연습 방을 열고 테이블 화면을 띄운다.
Future<RoomSession> pumpTable(
  WidgetTester tester,
  Size surface, {
  BotPolicy? botPolicy,
}) async {
  tester.view
    ..physicalSize = surface
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final session = RoomSession(
    transport: LocalRoomTransport(
      botCount: 2,
      botDelay: Duration.zero,
      botPolicy: botPolicy,
    ),
    myName: '나',
    config: _config,
  );
  await session.start();

  await tester.pumpWidget(
    MaterialApp(theme: buildGameTheme(), home: TableScreen(session: session)),
  );
  // 자리 배치와 Flame 로딩이 끝날 틈을 준다.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  return session;
}

/// 테이블을 닫는다.
///
/// 방장 세션은 1초마다 도는 타이머를 들고 있다. 테스트 본문이 끝나기 전에
/// 반드시 걷어내야 하므로 tearDown이 아니라 본문 끝에서 부른다. 화면을 먼저
/// 내려야 [TableScreen]이 리스너를 떼어 낸 뒤에 세션이 정리된다.
///
/// 정리는 [WidgetTester.runAsync] 안에서 돌린다. 스트림을 닫는 일은 실제
/// 이벤트 루프가 한 바퀴 돌아야 끝나는데, 위젯 테스트의 가짜 시간 안에서는
/// 그 바퀴가 돌지 않아 영영 기다리게 된다.
Future<void> closeTable(WidgetTester tester, RoomSession session) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(session.dispose);
  await tester.pump();
}

void main() {
  testWidgets('세로 화면에서 테이블이 예외 없이 그려진다', (tester) async {
    final session = await pumpTable(tester, const Size(430, 932));

    expect(tester.takeException(), isNull);
    expect(find.text('연습 모드'), findsOneWidget);
    // 나와 봇 둘이 앉아 있으니 방장은 시작할 수 있어야 한다.
    expect(session.table.value!.readySeats, hasLength(3));
    expect(find.text('시작하기'), findsOneWidget);

    // 아무도 움직이지 않는 대기실에서도 테이블에 사람이 그려져 있어야 한다.
    // 게임이 뜨기 전에 들어온 상태를 흘려 버리면 여기서 빈 테이블이 잡힌다.
    final game = tester
        .widget<GameWidget<HoldemGame>>(find.byType(GameWidget<HoldemGame>))
        .game!;
    expect(game.renderedState, isNotNull);
    expect(game.renderedState!.occupiedSeats, hasLength(3));

    await closeTable(tester, session);
  });

  testWidgets('가로로 넓은 화면에서도 넘치지 않는다', (tester) async {
    final session = await pumpTable(tester, const Size(1440, 900));

    expect(tester.takeException(), isNull);
    expect(find.byType(TableScreen), findsOneWidget);

    await closeTable(tester, session);
  });

  testWidgets('핸드를 시작하면 내 패와 액션 버튼이 나타난다', (tester) async {
    // 봇이 절대 폴드하지 않게 해서 차례가 반드시 나에게 돌아오도록 한다.
    final session = await pumpTable(
      tester,
      const Size(430, 932),
      botPolicy: (options, _, _) => options.canCheck
          ? const GameAction.check()
          : const GameAction.call(),
    );

    await tester.tap(find.text('시작하기'));
    for (var i = 0; i < 40 && !session.myOptions.isActive; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    expect(tester.takeException(), isNull);
    expect(session.table.value!.handNumber, 1);
    expect(session.mySeat!.holeCards, hasLength(2));
    expect(session.myOptions.isActive, isTrue, reason: '내 차례가 와야 합니다');

    // 내 차례이므로 버튼 줄이 떠 있어야 한다.
    expect(find.byType(ActionBar), findsOneWidget);
    expect(find.byType(StatusBar), findsNothing);
    expect(find.text('폴드'), findsOneWidget);

    // 내가 빅 블라인드이므로 여기서 체크하면 프리플랍이 닫히고
    // 플랍 세 장이 깔린다.
    await tester.tap(find.text('체크'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      if (session.table.value!.phase == HandPhase.flop) {
        break;
      }
    }
    expect(tester.takeException(), isNull);
    expect(session.table.value!.phase, HandPhase.flop);
    expect(session.table.value!.community, hasLength(3));

    await closeTable(tester, session);
  });

  testWidgets('화면 크기가 바뀌어도 다시 그려진다', (tester) async {
    final session = await pumpTable(tester, const Size(430, 932));

    tester.view.physicalSize = const Size(1280, 720);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    expect(tester.takeException(), isNull);

    await closeTable(tester, session);
  });
}
