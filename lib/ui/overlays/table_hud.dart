import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/table_state.dart';
import '../../net/room_session.dart';
import '../game_theme.dart';

/// 테이블 위쪽 띠. 나가기, 방 코드, 지금 단계를 보여 준다.
class TableHud extends StatelessWidget {
  const TableHud({
    required this.session,
    required this.state,
    required this.onLeave,
    super.key,
  });

  static const double height = 52;

  final RoomSession session;
  final TableState? state;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final table = state;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onLeave,
            icon: const Icon(Icons.arrow_back_rounded),
            color: GamePalette.textSecondary,
            tooltip: '나가기',
          ),
          if (session.isOnline)
            _RoomCodeChip(code: session.roomId)
          else
            const _Tag(icon: Icons.smart_toy_outlined, label: '연습 모드'),
          const Spacer(),
          if (table != null) ...<Widget>[
            Flexible(
              child: Text(
                _statusLine(table),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: GamePalette.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  String _statusLine(TableState table) {
    final blinds =
        '${formatChips(table.config.smallBlind)}/'
        '${formatChips(table.config.bigBlind)}';
    if (!table.isHandInProgress) {
      return '블라인드 $blinds';
    }
    return '#${table.handNumber} · ${table.phase.label} · $blinds';
  }
}

class _RoomCodeChip extends StatelessWidget {
  const _RoomCodeChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '방 코드 복사',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: code));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('방 코드 $code 를 복사했습니다'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: GamePalette.surfaceHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GamePalette.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                code,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                  color: GamePalette.accent,
                ),
              ),
              const SizedBox(width: 7),
              const Icon(
                Icons.copy_rounded,
                size: 14,
                color: GamePalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: GamePalette.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GamePalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: GamePalette.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: GamePalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
