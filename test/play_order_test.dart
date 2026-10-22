import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mptrack3/src/player/play_order.dart';

void main() {
  group('PlayOrder sequential', () {
    test('plays in queue order and stops at the end', () {
      final order = PlayOrder()..reset(3, startIndex: 1);
      expect(order.current, 1);
      expect(order.next(RepeatMode.off), 2);
      expect(order.next(RepeatMode.off), isNull);
      expect(order.current, 2);
    });

    test('repeat all wraps around both ways', () {
      final order = PlayOrder()..reset(3, startIndex: 2);
      expect(order.next(RepeatMode.all), 0);
      expect(order.previous(RepeatMode.all), 2);
    });
  });

  group('PlayOrder shuffle', () {
    test('current track stays first and every track plays once per cycle', () {
      final order = PlayOrder(random: Random(1))..reset(10, startIndex: 4, shuffle: true);
      expect(order.current, 4);
      final played = <int>[order.current!];
      int? next;
      while ((next = order.next(RepeatMode.off)) != null) {
        played.add(next!);
      }
      expect(played.length, 10);
      expect(played.toSet().length, 10);
    });

    test('toggling shuffle keeps the current track', () {
      final order = PlayOrder(random: Random(2))..reset(8, startIndex: 3);
      order.setShuffle(true);
      expect(order.current, 3);
      order.next(RepeatMode.off);
      final now = order.current;
      order.setShuffle(false);
      expect(order.current, now);
      expect(order.order, List.generate(8, (i) => i));
    });

    test('previous walks back through what actually played', () {
      final order = PlayOrder(random: Random(3))..reset(6, shuffle: true);
      final first = order.current;
      final second = order.next(RepeatMode.off);
      order.next(RepeatMode.off);
      expect(order.previous(RepeatMode.off), second);
      expect(order.previous(RepeatMode.off), first);
    });

    test('jumping to a track does not replay it later in the cycle', () {
      final order = PlayOrder(random: Random(4))..reset(6, startIndex: 0, shuffle: true);
      order.jumpTo(5);
      expect(order.current, 5);
      final rest = <int>[];
      int? next;
      while ((next = order.next(RepeatMode.off)) != null) {
        rest.add(next!);
      }
      expect(rest.contains(5), isFalse);
      expect({0, 5, ...rest}.length, 6);
    });

    test('a new cycle never starts with the track that just played', () {
      for (var seed = 0; seed < 50; seed++) {
        final order = PlayOrder(random: Random(seed))..reset(4, shuffle: true);
        for (var i = 0; i < 3; i++) {
          order.next(RepeatMode.all);
        }
        final last = order.current;
        expect(order.next(RepeatMode.all), isNot(last));
      }
    });
  });

  group('PlayOrder edits', () {
    test('removing a queue index shifts the order', () {
      final order = PlayOrder()..reset(4, startIndex: 2);
      order.removeQueueIndex(0);
      expect(order.order, [0, 1, 2]);
      expect(order.current, 1);
    });

    test('appended items play after the current one', () {
      final order = PlayOrder()..reset(2, startIndex: 1);
      order.append(2);
      expect(order.next(RepeatMode.off), 2);
      expect(order.next(RepeatMode.off), 3);
    });
  });
}
