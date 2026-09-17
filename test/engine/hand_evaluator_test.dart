import 'package:ddai_holdem/engine/card.dart';
import 'package:ddai_holdem/engine/hand_evaluator.dart';
import 'package:ddai_holdem/engine/hand_rank.dart';
import 'package:flutter_test/flutter_test.dart';

List<PlayingCard> hand(String codes) =>
    codes.split(' ').map(PlayingCard.fromCode).toList();

HandRank best(String codes) => HandEvaluator.best(hand(codes));

void main() {
  group('족보 판정', () {
    test('로열 스트레이트 플러시', () {
      expect(best('As Ks Qs Js Ts 2c 7d').category,
          HandCategory.straightFlush);
      expect(best('As Ks Qs Js Ts 2c 7d').tiebreakers.first, 14);
    });

    test('A-2-3-4-5 스트레이트 플러시는 5가 탑이다', () {
      final rank = best('Ah 2h 3h 4h 5h 9c Kd');
      expect(rank.category, HandCategory.straightFlush);
      expect(rank.tiebreakers.first, 5);
      // 에이스를 1로 쳤으므로 맨 뒤로 밀린다.
      expect(rank.cards.first.code, '5h');
      expect(rank.cards.last.code, 'Ah');
    });

    test('포카드와 키커', () {
      final rank = best('9c 9d 9h 9s Kc 3d 2h');
      expect(rank.category, HandCategory.fourOfAKind);
      expect(rank.tiebreakers, <int>[9, 13]);
    });

    test('풀하우스는 높은 트리플을 고른다', () {
      // 트리플이 두 벌(9, 5)이면 9로 풀하우스를 만들고 5는 페어로 쓴다.
      final rank = best('9c 9d 9h 5s 5c 5d 2h');
      expect(rank.category, HandCategory.fullHouse);
      expect(rank.tiebreakers, <int>[9, 5]);
    });

    test('플러시는 같은 무늬 중 높은 다섯 장', () {
      final rank = best('2s 5s 9s Js Ks 3h 4d');
      expect(rank.category, HandCategory.flush);
      expect(rank.tiebreakers, <int>[13, 11, 9, 5, 2]);
    });

    test('무늬가 6장이면 가장 낮은 한 장을 버린다', () {
      final rank = best('2s 5s 9s Js Ks Qs 4d');
      expect(rank.category, HandCategory.flush);
      expect(rank.tiebreakers, <int>[13, 12, 11, 9, 5]);
    });

    test('스트레이트와 플러시가 함께 있으면 플러시', () {
      // 5~9 스트레이트가 있지만 하트 다섯 장짜리 플러시가 더 세다.
      final rank = best('5h 6h 7h 2h Kh 8c 9d');
      expect(rank.category, HandCategory.flush);
    });

    test('A-2-3-4-5 스트레이트', () {
      final rank = best('Ah 2c 3d 4s 5h Kc 9d');
      expect(rank.category, HandCategory.straight);
      expect(rank.tiebreakers.first, 5);
    });

    test('페어가 섞여 있어도 스트레이트를 찾는다', () {
      final rank = best('5h 6c 7d 8s 9h 9c 2d');
      expect(rank.category, HandCategory.straight);
      expect(rank.tiebreakers.first, 9);
    });

    test('투페어는 높은 두 벌과 키커', () {
      final rank = best('Kc Kd 7h 7s 3c 3d 9h');
      expect(rank.category, HandCategory.twoPair);
      expect(rank.tiebreakers, <int>[13, 7, 9]);
    });

    test('원페어 키커는 세 장', () {
      final rank = best('Kc Kd 7h 5s 3c 2d 9h');
      expect(rank.category, HandCategory.onePair);
      expect(rank.tiebreakers, <int>[13, 9, 7, 5]);
    });

    test('하이카드', () {
      final rank = best('Kc 9d 7h 5s 3c 2d 4h');
      expect(rank.category, HandCategory.highCard);
      expect(rank.tiebreakers, <int>[13, 9, 7, 5, 4]);
    });
  });

  group('족보 비교', () {
    test('종류가 다르면 종류로 가른다', () {
      expect(best('2c 2d 2h 9s Kc 3d 4h') > best('Ac Kd Qh Js 9c 3d 4h'), isTrue);
    });

    test('같은 종류면 키커로 가른다', () {
      final higher = best('Kc Kd 9h 5s 3c 2d 4h');
      final lower = best('Kc Kd 8h 5s 3c 2d 4h');
      expect(higher > lower, isTrue);
      expect(lower < higher, isTrue);
    });

    test('완전히 같으면 무승부', () {
      // 보드 다섯 장이 곧 최고의 패라면 홀 카드는 소용이 없다.
      final left = best('2c 3d As Ks Qs Js Ts');
      final right = best('4c 5d As Ks Qs Js Ts');
      expect(left.compareTo(right), 0);
    });

    test('같은 스트레이트면 무늬로 갈리지 않는다', () {
      expect(
        best('9c 8c 7d 6h 5s 2c 3d')
            .compareTo(best('9h 8h 7s 6c 5d 2h 3s')),
        0,
      );
    });
  });

  test('카드 표기는 왕복해도 그대로다', () {
    for (final suit in Suit.values) {
      for (final rank in Rank.values) {
        final card = PlayingCard(rank, suit);
        expect(PlayingCard.fromCode(card.code), card);
      }
    }
  });
}
