import 'package:equatable/equatable.dart';

import 'package:mptrack3/src/service/library/models/index.dart';

enum LibraryStatus { loading, ready, noPermission, permanentlyDenied, error }

/// What changed after a refresh or a file operation.
class LibraryDiff extends Equatable {
  const LibraryDiff({
    this.added = const [],
    this.removedIds = const {},
    this.renamed = const {},
    this.updated = const [],
  });

  final List<Track> added;
  final Set<String> removedIds;

  /// Old id -> new id (moves on iOS).
  final Map<String, String> renamed;

  /// Tracks that changed folder.
  final List<Track> updated;

  bool get isEmpty =>
      added.isEmpty && removedIds.isEmpty && renamed.isEmpty && updated.isEmpty;

  @override
  List<Object?> get props => [added, removedIds, renamed, updated];
}
