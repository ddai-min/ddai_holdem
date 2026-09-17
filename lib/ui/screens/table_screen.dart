import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../engine/table_state.dart';
import '../../game/holdem_game.dart';
import '../../net/room_session.dart';
import '../game_theme.dart';
import '../overlays/action_bar.dart';
import '../overlays/status_bar.dart';
import '../overlays/table_hud.dart';

/// 테이블 화면. Flame이 그리는 테이블 위아래로 띠를 하나씩 둔다.
///
/// 띠가 차지할 높이를 미리 비워 두기 때문에, 내 차례가 오고 갈 때 테이블이
/// 커졌다 작아졌다 하지 않는다. 레이즈 금액 패널만 버튼 줄 위로 잠깐 겹친다.
class TableScreen extends StatefulWidget {
  const TableScreen({required this.session, super.key});

  final RoomSession session;

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  static const double _bottomHeight = 86;

  final HoldemGame _game = HoldemGame();

  RoomSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _session.table.addListener(_syncGame);
    _session.notice.addListener(_showNotice);
    _syncGame();
  }

  @override
  void dispose() {
    _session.table.removeListener(_syncGame);
    _session.notice.removeListener(_showNotice);
    super.dispose();
  }

  void _syncGame() {
    final state = _session.table.value;
    if (state != null) {
      _game.applyState(state, viewerUid: _session.myUid);
    }
  }

  void _showNotice() {
    final message = _session.notice.value;
    if (message == null || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _leave() async {
    await _session.leave();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final topBand = TableHud.height + padding.top;
    final bottomBand = _bottomHeight + padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _leave();
        }
      },
      child: Scaffold(
        backgroundColor: GamePalette.background,
        body: Stack(
          children: <Widget>[
            // 테이블은 위아래 띠 사이에만 그린다. Flame이 그 크기에 맞춰
            // 좌석 타원을 다시 계산한다.
            Positioned.fill(
              top: topBand,
              bottom: bottomBand,
              child: GameWidget<HoldemGame>(
                game: _game,
                backgroundBuilder: (_) =>
                    const ColoredBox(color: GamePalette.background),
                loadingBuilder: (_) => const Center(
                  child: CircularProgressIndicator(color: GamePalette.accent),
                ),
              ),
            ),
            Positioned(
              top: padding.top,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<TableState?>(
                valueListenable: _session.table,
                builder: (_, state, _) => TableHud(
                  session: _session,
                  state: state,
                  onLeave: _leave,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: padding.bottom,
              child: _BottomBand(
                session: _session,
                minHeight: _bottomHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 아래쪽 띠. 내 차례면 버튼 줄, 아니면 상태 줄이 들어간다.
class _BottomBand extends StatelessWidget {
  const _BottomBand({required this.session, required this.minHeight});

  final RoomSession session;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TableState?>(
      valueListenable: session.table,
      builder: (context, state, _) {
        final options = session.myOptions;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              constraints: BoxConstraints(minHeight: minHeight),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              alignment: Alignment.center,
              child: options.isActive && state != null
                  ? ActionBar(
                      session: session,
                      options: options,
                      state: state,
                    )
                  : StatusBar(session: session, state: state),
            ),
          ),
        );
      },
    );
  }
}
