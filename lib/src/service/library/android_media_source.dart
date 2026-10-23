import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right, Unit, unit;
import 'package:permission_handler/permission_handler.dart' as ph;

import 'package:mptrack3/src/service/library/api/channels.dart';
import 'package:mptrack3/src/service/library/api/errors_const.dart';
import 'package:mptrack3/src/service/library/api/library_error.dart';
import 'package:mptrack3/src/service/library/media_source.dart';
import 'package:mptrack3/src/service/library/models/index.dart';

/// MediaStore-backed library (native side: MediaStoreBridge.kt).
///
/// Reads with READ_MEDIA_AUDIO only and writes through the system
/// confirmation dialogs on Android 11+, so no MANAGE_EXTERNAL_STORAGE is
/// needed (Google Play rejects it for music players).
class AndroidMediaSource implements MediaSource {
  static const _channel = MethodChannel(LibraryChannels.androidMediaStore);
  static const _events = EventChannel(LibraryChannels.androidMediaChanges);

  /// Top-level directories where Android 11+ accepts audio files.
  static const allowedAudioRoots = {
    'Music',
    'Podcasts',
    'Audiobooks',
    'Ringtones',
    'Alarms',
    'Notifications',
    'Recordings',
  };

  /// Skips voice notes and notification sounds.
  static const minDuration = Duration(seconds: 20);

  int _sdkInt = 0;
  Stream<void>? _changes;

  Future<int> _sdk() async {
    if (_sdkInt == 0) {
      try {
        _sdkInt = await _channel.invokeMethod<int>('sdkInt') ?? 0;
      } catch (e) {
        log('sdkInt failed: $e');
      }
    }
    return _sdkInt;
  }

  @override
  bool get systemConfirmsWrites => _sdkInt >= 30;

  @override
  Future<PermissionStatus> requestPermission() async {
    final sdk = await _sdk();
    final permission = sdk >= 33 ? ph.Permission.audio : ph.Permission.storage;
    var status = await permission.status;
    if (!status.isGranted) status = await permission.request();
    if (status.isGranted || status.isLimited) return PermissionStatus.granted;
    if (status.isPermanentlyDenied) return PermissionStatus.permanentlyDenied;
    return PermissionStatus.denied;
  }

  @override
  Future<Either<LibraryError, LibrarySnapshot>> load() async {
    await _sdk();
    try {
      final raw =
          await _channel.invokeMethod<Map<Object?, Object?>>('queryLibrary');
      if (raw == null) return const Right(LibrarySnapshot(tracks: []));

      final labels = <String, String>{};
      final volumes = raw['volumes'];
      if (volumes is Map) {
        volumes.forEach((k, v) => labels['$k'] = '$v');
      }

      final tracks = <Track>[];
      final rows = raw['tracks'];
      if (rows is List) {
        for (final row in rows) {
          if (row is! Map) continue;
          final track = _trackFromRow(row);
          if (track != null) tracks.add(track);
        }
      }
      return Right(LibrarySnapshot(tracks: tracks, volumeLabels: labels));
    } on PlatformException catch (e) {
      return Left(
          LibraryError(code: LibraryErrors.platform, message: e.message));
    } catch (e) {
      return Left(LibraryError(code: LibraryErrors.unknown, message: '$e'));
    }
  }

  Track? _trackFromRow(Map row) {
    final id = row['id'];
    final uri = row['uri'];
    if (id == null || uri is! String) return null;
    final duration =
        Duration(milliseconds: (row['duration'] as num?)?.toInt() ?? 0);
    if (duration > Duration.zero && duration < minDuration) return null;
    final fileName = (row['displayName'] as String?) ?? '';
    final title = (row['title'] as String?)?.trim();
    return Track(
      id: '$id',
      uri: uri,
      volume: (row['volume'] as String?) ?? 'external_primary',
      folder: _trimSlashes((row['relativePath'] as String?) ?? ''),
      fileName: fileName,
      title: (title == null || title.isEmpty) ? fileName : title,
      artist: row['artist'] as String?,
      album: row['album'] as String?,
      duration: duration,
      dateAdded: (row['dateAdded'] as num?)?.toInt() ?? 0,
      size: (row['size'] as num?)?.toInt() ?? 0,
      filePath: row['data'] as String?,
    );
  }

  static String _trimSlashes(String path) {
    var result = path.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    while (result.startsWith('/')) {
      result = result.substring(1);
    }
    return result;
  }

  @override
  Stream<void> get changes => _changes ??= _events
      .receiveBroadcastStream()
      .map((_) {})
      .handleError((Object e) => log('media_changes error: $e'));

  @override
  Future<Uint8List?> artwork(Track track, {int size = 512}) async {
    try {
      return await _channel.invokeMethod<Uint8List>(
          'artwork', {'id': int.parse(track.id), 'size': size});
    } catch (_) {
      return null;
    }
  }

  @override
  String? writeRestriction(FolderRef target) {
    if (target.path.isEmpty) return 'cannot write to the storage root';
    if (_sdkInt >= 30 &&
        !allowedAudioRoots.contains(target.path.split('/').first)) {
      return 'Android only allows music inside Music/ (or Podcasts/, Audiobooks/...)';
    }
    return null;
  }

  @override
  Future<Either<LibraryError, Unit>> createFolder(FolderRef folder) =>
      _folderOp('createFolder', folder);

  @override
  Future<Either<LibraryError, Unit>> removeEmptyFolder(FolderRef folder) =>
      _folderOp('removeEmptyFolder', folder);

  Future<Either<LibraryError, Unit>> _folderOp(
      String method, FolderRef folder) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
              method, {'volume': folder.volume, 'relativePath': folder.path}) ??
          false;
      return ok
          ? const Right(unit)
          : Left(LibraryError(
              code: LibraryErrors.platform, message: '$method failed'));
    } on PlatformException catch (e) {
      return Left(
          LibraryError(code: LibraryErrors.platform, message: e.message));
    }
  }

  @override
  Future<Either<LibraryError, FileOpResult>> delete(List<Track> tracks) =>
      _writeOp('delete', tracks, const {});

  @override
  Future<Either<LibraryError, FileOpResult>> move(
          List<Track> tracks, FolderRef target) =>
      _writeOp('move', tracks,
          {'volume': target.volume, 'relativePath': '${target.path}/'});

  Future<Either<LibraryError, FileOpResult>> _writeOp(
      String method, List<Track> tracks, Map<String, Object?> extra) async {
    if (tracks.isEmpty) return const Right(FileOpResult());
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(method, {
        'ids': tracks.map((t) => int.parse(t.id)).toList(),
        ...extra,
      });
      return Right(_parseResult(raw));
    } on PlatformException catch (e) {
      return Left(LibraryError(
          code: LibraryErrors.platform, message: e.message ?? e.code));
    }
  }

  FileOpResult _parseResult(Map<Object?, Object?>? raw) {
    if (raw == null) return const FileOpResult(cancelled: true);
    final failed = <String, String>{};
    final rawFailed = raw['failed'];
    if (rawFailed is Map) {
      rawFailed.forEach((k, v) => failed['$k'] = '$v');
    }
    return FileOpResult(
      succeeded:
          (raw['succeeded'] as List?)?.map((e) => '$e').toList() ?? const [],
      failed: failed,
      cancelled: raw['cancelled'] == true,
    );
  }
}
