import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../engine/card.dart';
import '../engine/table_state.dart';
import '../ui/game_theme.dart';
import 'components/chips_layer.dart';
import 'components/community_board.dart';
import 'components/dealer_button.dart';
import 'components/seat_component.dart';
import 'components/table_felt.dart';
import 'table_layout.dart';

/// 테이블을 그리는 Flame 게임.
///
/// 규칙은 전혀 모른다. [applyState]로 받은 상태를 그대로 그릴 뿐이라, 방장이든
/// 참가자든 같은 코드로 같은 그림이 나온다. 버튼과 안내 문구는 Flutter 오버레이
/// 쪽이 맡는다.
class HoldemGame extends FlameGame {
  static const int _defaultSeatCount = 6;

  TableState? _state;

  /// 실제로 그림에 반영된 상태.
  ///
  /// 화면에 붙기 전에 들어온 상태는 [_state]에만 담기고 아직 그려지지 않는다.
  /// 둘을 나눠 두면 "받았지만 아직 못 그린" 구간이 눈에 보인다.
  TableState? _rendered;

  String _viewerUid = '';
  int _seatCount = _defaultSeatCount;
  int _viewerSeat = 0;

  late TableLayout layout = _buildLayout();
  late final TableFelt _felt = TableFelt(layout: layout);
  late final CommunityBoard _board = CommunityBoard(layout: layout);
  late final ChipsLayer _chips = ChipsLayer(layout: layout);
  late final DealerButton _button = DealerButton(layout: layout);
  final List<SeatComponent> _seats = <SeatComponent>[];

  /// 지금 그림에 반영되어 있는 상태.
  TableState? get renderedState => _rendered;

  @override
  Color backgroundColor() => GamePalette.background;

  @override
  Future<void> onLoad() async {
    // 여기서 add를 기다리면 안 된다. 컴포넌트가 실제로 붙는 것은 onLoad가
    // 끝난 뒤라서, 기다리는 순간 서로를 기다리며 영원히 로딩 화면에 머문다.
    addAll(<Component>[_felt, _board, _chips, _button]);
    _buildSeats(_seatCount);
  }

  @override
  void onMount() {
    super.onMount();
    // 화면에 붙기 전에 들어온 상태는 그리지 못하고 넘겼다. 이제 다시 얹는다.
    // 이걸 빠뜨리면, 아무도 움직이지 않는 대기실에서 다음 변화가 올 때까지
    // 빈 테이블만 보인다.
    final state = _state;
    if (state != null) {
      applyState(state, viewerUid: _viewerUid);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _relayout();
    }
  }

  /// 새 상태를 그림에 반영한다.
  void applyState(TableState state, {required String viewerUid}) {
    _state = state;
    _viewerUid = viewerUid;
    if (!isLoaded) {
      // 아직 뜨지 않았다. [onMount]가 다시 부른다.
      return;
    }
    _rendered = state;

    final seatCount = state.config.maxSeats;
    final viewerSeat = state.seatOf(viewerUid)?.index ?? 0;
    if (seatCount != _seatCount) {
      _seatCount = seatCount;
      _viewerSeat = viewerSeat;
      _buildSeats(seatCount);
      return;
    }
    if (viewerSeat != _viewerSeat) {
      _viewerSeat = viewerSeat;
      _relayout();
    }

    final highlight = _winningCards(state);
    final winners = state.result?.winnerSeats.toSet() ?? const <int>{};

    for (final component in _seats) {
      final seat = state.seatAt(component.seatIndex);
      component.apply(
        seat: seat,
        viewer: seat.uid != null && seat.uid == viewerUid,
        acting: state.actingSeat == seat.index,
        winner: state.phase == HandPhase.showdown &&
            winners.contains(seat.index),
        deadline: state.actionDeadlineMs,
        seconds: state.config.actionSeconds,
        highlight: highlight,
      );
    }

    _board.show(state.community, highlighted: highlight);
    _chips.state = state;
    _button.seatIndex = state.isHandInProgress ? state.buttonSeat : null;
  }

  /// 쇼다운에서 이긴 패를 이루는 카드들.
  Set<PlayingCard> _winningCards(TableState state) {
    final result = state.result;
    if (state.phase != HandPhase.showdown ||
        result == null ||
        !result.wentToShowdown) {
      return const <PlayingCard>{};
    }
    return <PlayingCard>{
      for (final seatIndex in result.winnerSeats)
        ...?result.rankings[seatIndex]?.cards,
    };
  }

  TableLayout _buildLayout() => TableLayout(
    size: size,
    seatCount: _seatCount,
    viewerSeat: _viewerSeat,
  );

  void _buildSeats(int count) {
    for (final seat in _seats) {
      seat.removeFromParent();
    }
    _seats.clear();
    _relayout();
    for (var index = 0; index < count; index++) {
      _seats.add(SeatComponent(seatIndex: index, layout: layout));
    }
    addAll(_seats);
    final state = _state;
    if (state != null) {
      applyState(state, viewerUid: _viewerUid);
    }
  }

  void _relayout() {
    layout = _buildLayout();
    _felt.layout = layout;
    _board.applyLayout(layout);
    _chips.layout = layout;
    _button.layout = layout;
    for (final seat in _seats) {
      seat.applyLayout(layout);
    }
  }
}
