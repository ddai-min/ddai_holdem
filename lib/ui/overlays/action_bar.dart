import 'package:flutter/material.dart';

import '../../engine/game_action.dart';
import '../../engine/table_state.dart';
import '../../net/room_session.dart';
import '../game_theme.dart';

/// 내 차례에 뜨는 버튼 줄.
///
/// 레이즈는 금액을 정해야 해서, 누르면 버튼 줄 위로 작은 패널이 올라온다.
/// 테이블을 가리지 않도록 아래에서 위로만 자라게 했다.
class ActionBar extends StatefulWidget {
  const ActionBar({
    required this.session,
    required this.options,
    required this.state,
    super.key,
  });

  final RoomSession session;
  final ActionOptions options;
  final TableState state;

  @override
  State<ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<ActionBar> {
  int? _raiseTo;

  @override
  void didUpdateWidget(ActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 판이 한 칸 넘어갔으면 열어 둔 금액 패널은 의미가 없다.
    if (widget.state.actionCounter != oldWidget.state.actionCounter ||
        widget.state.handNumber != oldWidget.state.handNumber) {
      _raiseTo = null;
    }
  }

  ActionOptions get _options => widget.options;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_raiseTo != null) ...<Widget>[
          _RaisePanel(
            options: _options,
            value: _raiseTo!,
            bigBlind: widget.state.config.bigBlind,
            presets: _presets(),
            onChanged: (value) => setState(() => _raiseTo = value),
            onConfirm: () => _send(GameAction.raise(_raiseTo!)),
            onCancel: () => setState(() => _raiseTo = null),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: _ActionButton(
                label: '폴드',
                color: GamePalette.foldColor,
                onPressed: () => _send(const GameAction.fold()),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _options.canCheck
                  ? _ActionButton(
                      label: '체크',
                      color: GamePalette.checkColor,
                      onPressed: () => _send(const GameAction.check()),
                    )
                  : _ActionButton(
                      label: _options.callIsAllIn ? '올인' : '콜',
                      detail: formatChips(_options.callAmount),
                      color: GamePalette.checkColor,
                      onPressed: () => _send(const GameAction.call()),
                    ),
            ),
            if (_options.canRaise) ...<Widget>[
              const SizedBox(width: 9),
              Expanded(
                child: _ActionButton(
                  label: _options.isReraise ? '레이즈' : '벳',
                  detail: _raiseTo == null ? null : formatChips(_raiseTo!),
                  color: GamePalette.raiseColor,
                  onPressed: () => setState(
                    () => _raiseTo = _raiseTo ?? _options.minRaiseTo,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 빠른 금액 버튼. 팟 대비 비율로 잡는다.
  List<(String, int)> _presets() {
    final pot = widget.state.totalPot;
    int sized(double fraction) {
      final target =
          _options.roundBet +
          _options.callAmount +
          ((pot + _options.callAmount) * fraction).round();
      return target.clamp(_options.minRaiseTo, _options.maxRaiseTo);
    }

    return <(String, int)>[
      ('최소', _options.minRaiseTo),
      ('½팟', sized(0.5)),
      ('팟', sized(1)),
      ('올인', _options.maxRaiseTo),
    ];
  }

  Future<void> _send(GameAction action) async {
    setState(() => _raiseTo = null);
    await widget.session.act(action);
  }
}

class _RaisePanel extends StatelessWidget {
  const _RaisePanel({
    required this.options,
    required this.value,
    required this.bigBlind,
    required this.presets,
    required this.onChanged,
    required this.onConfirm,
    required this.onCancel,
  });

  final ActionOptions options;
  final int value;
  final int bigBlind;
  final List<(String, int)> presets;
  final ValueChanged<int> onChanged;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final min = options.minRaiseTo;
    final max = options.maxRaiseTo;
    final steps = ((max - min) / bigBlind).round().clamp(1, 60);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: GamePalette.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GamePalette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                '올릴 금액',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: GamePalette.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                formatChips(value),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: GamePalette.accent,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (max > min)
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: GamePalette.accent,
                inactiveTrackColor: GamePalette.surfaceHigh,
                thumbColor: GamePalette.accent,
                overlayColor: GamePalette.accent.withValues(alpha: 0.15),
                trackHeight: 4,
              ),
              child: Slider(
                value: value.clamp(min, max).toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: steps,
                onChanged: (next) => onChanged(next.round().clamp(min, max)),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '칩이 이만큼뿐이라 올인만 할 수 있습니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: GamePalette.textSecondary,
                ),
              ),
            ),
          Wrap(
            spacing: 7,
            children: <Widget>[
              for (final (label, amount) in presets)
                if (amount >= min && amount <= max)
                  _PresetChip(
                    label: label,
                    selected: amount == value,
                    onTap: () => onChanged(amount),
                  ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: onConfirm,
                  child: Text(
                    value >= options.maxRaiseTo
                        ? '올인 ${formatChips(value)}'
                        : '${options.isReraise ? "레이즈" : "벳"} '
                              '${formatChips(value)}',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? GamePalette.accent.withValues(alpha: 0.2)
          : GamePalette.surfaceHigh,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? GamePalette.accent : GamePalette.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? GamePalette.accent : GamePalette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.detail,
  });

  final String label;
  final String? detail;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
