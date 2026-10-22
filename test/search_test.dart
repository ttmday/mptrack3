import 'package:flutter_test/flutter_test.dart';
import 'package:mptrack3/src/library/track_search.dart';

import 'test_tracks.dart';

void main() {
  final tracks = [
    makeTrack('1', title: 'José José - Almohada', artist: 'José José'),
    makeTrack('2', title: 'El Triste', artist: 'José José'),
    makeTrack('3', title: 'No Como El Filme', artist: 'José Madero', folder: 'Music/Rock'),
  ];

  test('ignores accents and case', () {
    expect(searchTracks('jose almohada', tracks).map((t) => t.id), ['1']);
    expect(searchTracks('JOSÉ', tracks).length, 3);
  });

  test('matches folder names and ranks title matches first', () {
    expect(searchTracks('rock', tracks).single.id, '3');
    expect(searchTracks('el', tracks).first.id, '2');
  });

  test('resolveTrack prefers exact titles in the preferred pool', () {
    final match = resolveTrack('el triste', tracks, tracks);
    expect(match.isUnique, isTrue);
    expect(match.single.id, '2');
    expect(resolveTrack('jose', tracks, tracks).isUnique, isFalse);
  });
}
