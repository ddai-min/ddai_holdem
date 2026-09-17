import 'dart:math' as math;

import '../engine/card.dart';
import '../engine/game_action.dart';
import '../engine/hand_evaluator.dart';
import '../engine/hand_rank.dart';

/// 연습 모드에서 사람 대신 치는 아주 단순한 판단기.
///
/// 확률 계산은 하지 않는다. "패가 얼마나 센가"를 0~1로 어림잡고, 콜에 드는
/// 값과 견줘 폴드·콜·레이즈를 고른다. 여기에 약간의 흔들림을 섞어 매번 똑같이
/// 치지 않게 했다. 규칙을 확인하고 화면을 다듬는 데는 이 정도면 충분하다.
abstract final class BotBrain {
  static GameAction decide({
    required ActionOptions options,
    required List<PlayingCard> hole,
    required List<PlayingCard> community,
    required int pot,
    required math.Random random,
  }) {
    final base = community.isEmpty
        ? preflopStrength(hole)
        : postflopStrength(hole, community);
    final strength = (base + (random.nextDouble() - 0.5) * 0.12).clamp(0.0, 1.0);

    if (options.canCheck) {
      // 공짜로 다음 카드를 볼 수 있다. 세면 때리고, 가끔 찔러 본다.
      if (options.canRaise &&
          (strength > 0.68 && random.nextDouble() < 0.7 ||
              strength > 0.30 && random.nextDouble() < 0.12)) {
        return GameAction.bet(_size(options, pot, strength, random));
      }
      return const GameAction.check();
    }

    // 팟 대비 콜 값. 비쌀수록 더 좋은 패가 있어야 따라간다.
    final price = options.callAmount / (pot + options.callAmount).clamp(1, 1 << 30);
    if (strength > 0.80 && options.canRaise && random.nextDouble() < 0.55) {
      return GameAction.raise(_size(options, pot, strength, random));
    }
    if (strength >= price * 1.15 || strength > 0.5) {
      return const GameAction.call();
    }
    return const GameAction.fold();
  }

  /// 홀 카드 두 장만 보고 매기는 세기.
  static double preflopStrength(List<PlayingCard> hole) {
    if (hole.length < 2) {
      return 0;
    }
    final high = math.max(hole[0].value, hole[1].value);
    final low = math.min(hole[0].value, hole[1].value);

    if (high == low) {
      // 포켓 페어. 22가 0.48, AA가 0.95쯤 된다.
      return (0.48 + (high - 2) / 12 * 0.47).clamp(0.0, 1.0);
    }

    var score = (high + low - 4) / 48;
    if (hole[0].suit == hole[1].suit) {
      score += 0.10;
    }
    final gap = high - low;
    if (gap == 1) {
      score += 0.08;
    } else if (gap == 2) {
      score += 0.04;
    }
    if (high >= Rank.king.value) {
      score += 0.06;
    }
    return score.clamp(0.0, 1.0);
  }

  /// 보드가 깔린 뒤의 세기.
  static double postflopStrength(
    List<PlayingCard> hole,
    List<PlayingCard> community,
  ) {
    if (hole.length + community.length < 5) {
      return preflopStrength(hole);
    }
    final rank = HandEvaluator.best(<PlayingCard>[...hole, ...community]);
    final base = switch (rank.category) {
      HandCategory.highCard => 0.12,
      HandCategory.onePair => 0.40,
      HandCategory.twoPair => 0.62,
      HandCategory.threeOfAKind => 0.78,
      HandCategory.straight => 0.86,
      HandCategory.flush => 0.90,
      HandCategory.fullHouse => 0.95,
      HandCategory.fourOfAKind => 0.98,
      HandCategory.straightFlush => 1.0,
    };

    // 보드에 이미 깔린 패라면 남들도 똑같이 들고 있다. 크게 깎는다.
    if (community.length >= 5 &&
        HandEvaluator.best(community).compareTo(rank) == 0) {
      return base * 0.35;
    }
    return base;
  }

  /// 얼마까지 올릴지. 대체로 팟의 절반에서 한 배 사이다.
  static int _size(
    ActionOptions options,
    int pot,
    double strength,
    math.Random random,
  ) {
    if (strength > 0.93 && random.nextDouble() < 0.35) {
      return options.maxRaiseTo;
    }
    final target =
        options.roundBet +
        options.callAmount +
        ((pot + options.callAmount) * (0.5 + random.nextDouble() * 0.4)).round();
    return math.min(math.max(target, options.minRaiseTo), options.maxRaiseTo);
  }
}
