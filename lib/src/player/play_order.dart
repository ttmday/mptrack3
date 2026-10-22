import 'dart:math' as math;

enum RepeatMode { off, one, all }

/// Decides which queue index plays next.
///
/// The queue itself never changes order when shuffle toggles: [order] is a
/// permutation of queue indices and [position] points into it. With shuffle
/// on, the current track is moved to the front of a fresh permutation so
/// nothing repeats until every track has played, and "previous" walks back
/// through what actually played.
class PlayOrder {
  PlayOrder({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;
  List<int> _order = const [];
  int _position = -1;
  bool _shuffle = false;

  List<int> get order => List.unmodifiable(_order);
  int get position => _position;
  bool get shuffle => _shuffle;
  int get length => _order.length;

  /// Queue index currently selected, or null when the queue is empty.
  int? get current =>
      (_position >= 0 && _position < _order.length) ? _order[_position] : null;

  /// Resets the order for a queue of [length] items starting at [startIndex].
  void reset(int length, {int startIndex = 0, bool? shuffle}) {
    if (shuffle != null) _shuffle = shuffle;
    if (length <= 0) {
      _order = const [];
      _position = -1;
      return;
    }
    final start = startIndex.clamp(0, length - 1);
    if (_shuffle) {
      _order = _shuffledWithFirst(length, start);
      _position = 0;
    } else {
      _order = List<int>.generate(length, (i) => i);
      _position = start;
    }
  }

  void setShuffle(bool enabled) {
    if (enabled == _shuffle) return;
    _shuffle = enabled;
    final cur = current;
    if (cur == null) return;
    reset(_order.length, startIndex: cur);
  }

  /// Moves to [queueIndex] (e.g. the user tapped a track).
  ///
  /// In shuffle mode the remaining tracks are reshuffled after it so the
  /// tapped track does not get played twice in the same cycle.
  void jumpTo(int queueIndex) {
    if (queueIndex < 0 || queueIndex >= _order.length) return;
    if (_shuffle) {
      final played = _order.sublist(0, _position + 1)..remove(queueIndex);
      final rest = _order.sublist(_position + 1)..remove(queueIndex);
      rest.shuffle(_random);
      _order = [...played, queueIndex, ...rest];
      _position = played.length;
    } else {
      _position = queueIndex;
    }
  }

  /// Index that would play after the current one, without moving.
  int? peekNext(RepeatMode repeat) {
    if (_order.isEmpty) return null;
    if (_position + 1 < _order.length) return _order[_position + 1];
    return repeat == RepeatMode.all ? (_shuffle ? null : _order.first) : null;
  }

  bool hasNext(RepeatMode repeat) =>
      _order.isNotEmpty &&
      (_position + 1 < _order.length || repeat == RepeatMode.all);

  bool hasPrevious(RepeatMode repeat) =>
      _order.isNotEmpty && (_position > 0 || repeat == RepeatMode.all);

  /// Advances and returns the new queue index, or null at the end.
  int? next(RepeatMode repeat) {
    if (_order.isEmpty) return null;
    if (_position + 1 < _order.length) {
      _position++;
      return current;
    }
    if (repeat != RepeatMode.all) return null;
    if (_shuffle) {
      // Start a new cycle that does not begin with the track just played.
      final last = _order[_position];
      _order = _shuffledAvoidingFirst(_order.length, last);
    }
    _position = 0;
    return current;
  }

  int? previous(RepeatMode repeat) {
    if (_order.isEmpty) return null;
    if (_position > 0) {
      _position--;
      return current;
    }
    if (repeat != RepeatMode.all) return null;
    _position = _order.length - 1;
    return current;
  }

  /// Queue indices in the order they will play after the current one.
  List<int> upcoming(RepeatMode repeat, {int limit = 50}) {
    if (_order.isEmpty) return const [];
    final result = <int>[];
    for (var i = _position + 1;
        i < _order.length && result.length < limit;
        i++) {
      result.add(_order[i]);
    }
    if (repeat == RepeatMode.all && !_shuffle) {
      for (var i = 0; i <= _position && result.length < limit; i++) {
        result.add(_order[i]);
      }
    }
    return result;
  }

  /// Registers [count] new items appended to the end of the queue. In
  /// shuffle mode they are scattered among the tracks still to come.
  void append(int count) {
    if (count <= 0) return;
    final start = _order.length;
    final updated = List<int>.of(_order);
    for (var i = 0; i < count; i++) {
      final index = start + i;
      if (_shuffle && _position >= 0) {
        final min = _position + 1;
        final insertAt = min + _random.nextInt(updated.length - min + 1);
        updated.insert(insertAt, index);
      } else {
        updated.add(index);
      }
    }
    _order = updated;
    if (_position < 0) _position = 0;
  }

  /// Removes [queueIndex] from the order and shifts higher indices down.
  /// Call after removing the same index from the queue.
  void removeQueueIndex(int queueIndex) {
    final pos = _order.indexOf(queueIndex);
    if (pos < 0) return;
    final updated = <int>[];
    for (final i in _order) {
      if (i == queueIndex) continue;
      updated.add(i > queueIndex ? i - 1 : i);
    }
    _order = updated;
    if (pos < _position) {
      _position--;
    } else if (pos == _position && _position >= _order.length) {
      _position = _order.length - 1;
    }
    if (_order.isEmpty) _position = -1;
  }

  List<int> _shuffledWithFirst(int length, int first) {
    final rest = List<int>.generate(length, (i) => i)..remove(first);
    rest.shuffle(_random);
    return [first, ...rest];
  }

  List<int> _shuffledAvoidingFirst(int length, int avoid) {
    final all = List<int>.generate(length, (i) => i)..shuffle(_random);
    if (length > 1 && all.first == avoid) {
      final swapWith = 1 + _random.nextInt(length - 1);
      all[0] = all[swapWith];
      all[swapWith] = avoid;
    }
    return all;
  }
}
