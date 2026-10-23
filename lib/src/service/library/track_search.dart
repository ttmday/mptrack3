import 'package:mptrack3/src/service/library/models/index.dart';
import 'package:mptrack3/src/utils/text.dart';

/// Accent/case-insensitive search across title, artist, album, folder and
/// file name. Every query token must match somewhere; results are ranked so
/// title matches come first.
List<Track> searchTracks(String query, Iterable<Track> tracks, {int? limit}) {
  final tokens = tokenize(query);
  if (tokens.isEmpty) return const [];
  final phrase = tokens.join(' ');

  final scored = <(Track, int)>[];
  for (final track in tracks) {
    final text = track.searchText;
    if (!tokens.every(text.contains)) continue;
    scored.add((track, _score(track, phrase, tokens)));
  }
  scored.sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    if (byScore != 0) return byScore;
    return a.$1.normalizedTitle.compareTo(b.$1.normalizedTitle);
  });
  final result = scored.map((e) => e.$1);
  return (limit == null ? result : result.take(limit)).toList();
}

int _score(Track track, String phrase, List<String> tokens) {
  final title = track.normalizedTitle;
  var score = 0;
  if (title == phrase) score += 100;
  if (title.startsWith(phrase)) score += 50;
  if (title.contains(phrase)) score += 25;
  final artist = normalizeText(track.artist ?? '');
  if (artist.contains(phrase)) score += 15;
  for (final token in tokens) {
    if (title.contains(token)) score += 5;
  }
  return score;
}

/// Result of resolving a user-typed track reference (terminal commands).
class TrackMatch {
  const TrackMatch(this.matches);
  final List<Track> matches;
  bool get isUnique => matches.length == 1;
  bool get isEmpty => matches.isEmpty;
  Track get single => matches.single;
}

/// Resolves [name] to a track: exact title or file name first (preferring
/// [preferred], usually the current folder), then a unique search hit.
TrackMatch resolveTrack(String name, Iterable<Track> preferred, Iterable<Track> all) {
  final wanted = normalizeText(name);
  if (wanted.isEmpty) return const TrackMatch([]);

  for (final pool in [preferred, all]) {
    final exact = pool
        .where((t) => t.normalizedTitle == wanted || t.normalizedFileName == wanted ||
            normalizeText(t.fileName) == wanted)
        .toSet()
        .toList();
    if (exact.isNotEmpty) return TrackMatch(exact);
  }
  for (final pool in [preferred, all]) {
    final hits = searchTracks(name, pool);
    if (hits.isNotEmpty) return TrackMatch(hits);
  }
  return const TrackMatch([]);
}
