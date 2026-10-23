import 'dart:typed_data';

import 'package:fpdart/fpdart.dart' show Either, Unit;

import 'package:mptrack3/src/service/library/api/library_error.dart';
import 'package:mptrack3/src/service/library/models/index.dart';

enum PermissionStatus { granted, denied, permanentlyDenied }

/// Platform specific access to audio files.
abstract class MediaSource {
  Future<PermissionStatus> requestPermission();

  Future<Either<LibraryError, LibrarySnapshot>> load();

  Stream<void> get changes;

  Future<Uint8List?> artwork(Track track, {int size = 512});

  /// Whether the OS shows its own confirmation before delete/move. When
  /// false the app must confirm destructive actions itself.
  bool get systemConfirmsWrites;

  /// Reason why music cannot be placed in [target], or null if allowed.
  String? writeRestriction(FolderRef target);

  Future<Either<LibraryError, Unit>> createFolder(FolderRef folder);

  Future<Either<LibraryError, Unit>> removeEmptyFolder(FolderRef folder);

  Future<Either<LibraryError, FileOpResult>> delete(List<Track> tracks);

  Future<Either<LibraryError, FileOpResult>> move(List<Track> tracks, FolderRef target);
}
