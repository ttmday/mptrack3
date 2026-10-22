import 'dart:typed_data';

import 'package:mptrack3/src/model/folder_tree.dart';
import 'package:mptrack3/src/model/track.dart';

class LibrarySnapshot {
  const LibrarySnapshot({
    required this.tracks,
    this.folders = const [],
    this.volumeLabels = const {},
  });

  final List<Track> tracks;

  /// Directories known to exist even without tracks.
  final List<FolderRef> folders;
  final Map<String, String> volumeLabels;
}

/// Outcome of a file operation.
class FileOpResult {
  const FileOpResult({
    this.succeeded = const [],
    this.failed = const {},
    this.cancelled = false,
    this.renamed = const {},
  });

  /// Old track id -> new track id, for platforms where moving changes the id.
  final Map<String, String> renamed;

  /// Ids of tracks the operation applied to.
  final List<String> succeeded;

  /// Track id -> reason.
  final Map<String, String> failed;

  /// The user dismissed the system confirmation dialog.
  final bool cancelled;

  bool get ok => !cancelled && failed.isEmpty;
}

enum PermissionStatus { granted, denied, permanentlyDenied }

/// Platform specific access to audio files.
abstract class MediaSource {
  Future<PermissionStatus> requestPermission();

  Future<LibrarySnapshot> load();

  /// Emits when the underlying storage reports a change.
  Stream<void> get changes;

  Future<Uint8List?> artwork(Track track, {int size = 512});

  /// Whether the OS shows its own confirmation before delete/move. When
  /// false the app must confirm destructive actions itself.
  bool get systemConfirmsWrites;

  /// Returns a reason when a folder cannot be created/moved into, or null if
  /// allowed.
  String? writeRestriction(FolderRef target);

  Future<bool> createFolder(FolderRef folder);

  /// Deletes an empty directory. Returns false when it is not empty or the
  /// platform does not allow it.
  Future<bool> removeEmptyFolder(FolderRef folder);

  Future<FileOpResult> delete(List<Track> tracks);

  Future<FileOpResult> move(List<Track> tracks, FolderRef target);
}
