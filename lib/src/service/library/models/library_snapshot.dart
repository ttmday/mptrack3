import 'package:equatable/equatable.dart';

import 'package:mptrack3/src/service/library/models/folder_tree.dart';
import 'package:mptrack3/src/service/library/models/track.dart';

class LibrarySnapshot extends Equatable {
  const LibrarySnapshot({
    required this.tracks,
    this.folders = const [],
    this.volumeLabels = const {},
  });

  final List<Track> tracks;

  /// Directories known to exist even without tracks.
  final List<FolderRef> folders;
  final Map<String, String> volumeLabels;

  @override
  List<Object?> get props => [tracks, folders, volumeLabels];

  @override
  bool? get stringify => false;
}
