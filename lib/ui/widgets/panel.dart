import 'package:flutter/material.dart';

import '../game_theme.dart';

/// 어두운 배경 위에 얹는 카드. 화면마다 같은 모양을 쓴다.
class GamePanel extends StatelessWidget {
  const GamePanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.accent = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 테두리를 강조해 눈이 먼저 가게 한다.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: GamePalette.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent ? GamePalette.accent : GamePalette.border,
          width: accent ? 1.4 : 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 작은 제목 줄.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: GamePalette.textSecondary,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// 값 하나를 고르는 칩 줄.
class OptionRow<T> extends StatelessWidget {
  const OptionRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    super.key,
  });

  final String label;
  final List<T> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: GamePalette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (final option in options)
                _Chip(
                  label: labelOf(option),
                  selected: option == value,
                  onTap: () => onChanged(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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
      color: selected ? GamePalette.accent : GamePalette.surfaceHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? GamePalette.accent : GamePalette.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected
                  ? GamePalette.background
                  : GamePalette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 잘못된 상황을 알리는 빨간 줄.
class ErrorNote extends StatelessWidget {
  const ErrorNote(this.message, {this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: GamePalette.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GamePalette.danger.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: GamePalette.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: GamePalette.textPrimary,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
