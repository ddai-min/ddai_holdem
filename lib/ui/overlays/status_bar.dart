import 'package:flutter/material.dart';

import '../../engine/card.dart';
import '../../engine/hand_evaluator.dart';
import '../../engine/hand_rank.dart';
import '../../engine/seat.dart';
import '../../engine/table_state.dart';
import '../../net/room_session.dart';
import '../game_theme.dart';

/// 내 차례가 아닐 때 아래쪽에 뜨는 줄.
///
/// 왼쪽은 내 패(쇼다운에서는 결과), 오른쪽은 지금 해야 할 일이다. 버튼 줄과
/// 같은 자리를 쓰기 때문에 차례가 오고 갈 때 화면이 들썩이지 않는다.
class StatusBar extends StatelessWidget {
  const StatusBar({required this.session, required this.state, super.key});

  final RoomSession session;
  final TableState? state;

  @override
  Widget build(BuildContext context) {
    final table = state;
    if (table == null) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: GamePalette.accent,
          ),
        ),
      );
    }

    final seat = table.seatOf(session.myUid);
    final showdown = table.phase == HandPhase.showdown && table.result != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: showdown
              ? _ResultText(state: table)
              : _MyHand(state: table, seat: seat),
        ),
        const SizedBox(width: 12),
        _buildTrailing(context, table, seat),
      ],
    );
  }

  Widget _buildTrailing(
    BuildContext context,
    TableState table,
    PlayerSeat? seat,
  ) {
    if (seat == null) {
      return const _Note('관전 중');
    }
    if (seat.sittingOut && !table.phase.isBetting) {
      return FilledButton(
        onPressed: session.sitIn,
        child: Text(seat.chips <= 0 ? '리바이' : '참가하기'),
      );
    }
    if (table.phase == HandPhase.waiting) {
      final ready = table.readySeats.length;
      if (session.isHost) {
        return ready >= 2
            ? FilledButton(
                onPressed: session.startHand,
                child: const Text('시작하기'),
              )
            : _Note('친구를 기다리는 중 · $ready명');
      }
      return const _Note('방장이 시작하길 기다리는 중');
    }
    if (table.phase == HandPhase.showdown) {
      return const _Note('다음 판 준비 중');
    }
    final acting = table.actingSeat;
    if (acting != null) {
      return _Note('${table.seatAt(acting).name} 차례');
    }
    return const _Note('카드를 여는 중');
  }
}

class _MyHand extends StatelessWidget {
  const _MyHand({required this.state, required this.seat});

  final TableState state;
  final PlayerSeat? seat;

  @override
  Widget build(BuildContext context) {
    final cards = seat?.holeCards ?? const <PlayingCard>[];
    if (cards.length < 2) {
      return const _Note('카드를 기다리는 중');
    }
    // 보드가 세 장은 깔려야 족보가 정해진다. 그 전에는 카드만 보여 준다.
    final rank = state.community.length >= 3
        ? HandEvaluator.best(<PlayingCard>[...cards, ...state.community])
        : null;

    return Row(
      children: <Widget>[
        for (final card in cards) ...<Widget>[
          CardChip(card: card),
          const SizedBox(width: 6),
        ],
        if (rank != null)
          Flexible(
            child: Text(
              rank.describe(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: GamePalette.textPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

class _ResultText extends StatelessWidget {
  const _ResultText({required this.state});

  final TableState state;

  @override
  Widget build(BuildContext context) {
    final result = state.result!;
    final lines = <String>[
      for (final award in result.awards)
        _describe(award.winnerSeats, award.amount, award.label, result.rankings),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final line in lines)
          Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w700,
              color: GamePalette.seatWinner,
            ),
          ),
        if (lines.isEmpty)
          const Text(
            '판이 끝났습니다',
            style: TextStyle(fontSize: 13, color: GamePalette.textSecondary),
          ),
      ],
    );
  }

  String _describe(
    List<int> winners,
    int amount,
    String label,
    Map<int, HandRank> rankings,
  ) {
    final names = winners.map((index) => state.seatAt(index).name).join(', ');
    final rank = winners.length == 1 ? rankings[winners.first] : null;
    final prefix = state.pots.length > 1 ? '$label · ' : '';
    final suffix = rank == null ? '' : ' · ${rank.describe()}';
    return '$prefix$names ${formatChips(amount)} 획득$suffix';
  }
}

/// 카드 한 장을 작은 표로 보여 준다. 무늬 색을 그대로 살린다.
class CardChip extends StatelessWidget {
  const CardChip({required this.card, super.key});

  final PlayingCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: GamePalette.cardFace,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: GamePalette.cardEdge),
      ),
      child: Text(
        card.label,
        style: TextStyle(
          fontSize: 13,
          height: 1.15,
          fontWeight: FontWeight.w800,
          color: card.suit.isRed ? GamePalette.suitRed : GamePalette.suitBlack,
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: GamePalette.textSecondary,
      ),
    );
  }
}
