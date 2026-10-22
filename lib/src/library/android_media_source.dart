import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'package:mptrack3/src/library/media_source.dart';
import 'package:mptrack3/src/model/folder_tree.dart';
import 'package:mptrack3/src/model/track.dart';

/// Android implementation backed by MediaStore (see MediaStoreBridge.kt).
///
/// Uses only READ_MEDIA_AUDIO (Android 13+) or READ_EXTERNAL_STORAGE, and
/// the system confirmation dialogs for writes on Android 11+, which keeps
/// the app compatible with Play Store storage policies.
class AndroidMediaSource implements MediaSource {
  static const _channel = MethodChannel('mptrack3/media_store');
  static const _events = EventChannel('mptrack3/media_changes');

  /// Top-level directories Android lets apps place audio files in.
  static const allowedAudioRoots = {
    'Music',
    'Podcasts',
    'Audiobooks',
    'Ringtones',
    'Alarms',
    'Notifications',
    'Recordings',
  };

  /// Shorter files (voice notes, notification sounds) are skipped.
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
  Future<LibrarySnapshot> load() async {
    await _sdk();
    final raw =
        await _channel.invokeMethod<Map<Object?, Object?>>('queryLibrary');
    if (raw == null) return const LibrarySnapshot(tracks: []);

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
        final track = _trackFromMap(row);
        if (track != null) tracks.add(track);
      }
    }
    return LibrarySnapshot(tracks: tracks, volumeLabels: labels);
  }

  Track? _trackFromMap(Map row) {
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
      folder: _cleanFolder((row['relativePath'] as String?) ?? ''),
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

  static String _cleanFolder(String relativePath) {
    var path = relativePath.trim();
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    return path;
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
    } catch (e) {
      return null;
    }
  }

  @override
  String? writeRestriction(FolderRef target) {
    if (target.path.isEmpty) {
      return 'cannot write to the storage root';
    }
    if (_sdkInt >= 30) {
      final top = target.path.split('/').first;
      if (!allowedAudioRoots.contains(top)) {
        return 'Android only allows music inside Music/ (or Podcasts/, Audiobooks/...)';
      }
    }
    return null;
  }

  @override
  Future<bool> createFolder(FolderRef folder) async {
    try {
      return await _channel.invokeMethod<bool>('createFolder',
              {'volume': folder.volume, 'relativePath': folder.path}) ??
          false;
    } catch (e) {
      log('createFolder failed: $e');
      return false;
    }
  }

  @override
  Future<bool> removeEmptyFolder(FolderRef folder) async {
    try {
      return await _channel.invokeMethod<bool>('removeEmptyFolder',
              {'volume': folder.volume, 'relativePath': folder.path}) ??
          false;
    } catch (e) {
      log('removeEmptyFolder failed: $e');
      return false;
    }
  }

  @override
  Future<FileOpResult> delete(List<Track> tracks) {
    return _writeOp('delete', tracks, const {});
  }

  @override
  Future<FileOpResult> move(List<Track> tracks, FolderRef target) {
    return _writeOp('move', tracks,
        {'volume': target.volume, 'relativePath': '${target.path}/'});
  }

  Future<FileOpResult> _writeOp(
      String method, List<Track> tracks, Map<String, Object?> extra) async {
    if (tracks.isEmpty) return const FileOpResult();
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(method, {
        'ids': tracks.map((t) => int.parse(t.id)).toList(),
        ...extra,
      });
      return _parseResult(raw);
    } on PlatformException catch (e) {
      return FileOpResult(
          failed: {for (final t in tracks) t.id: e.message ?? e.code});
    }
  }

  FileOpResult _parseResult(Map<Object?, Object?>? raw) {
    if (raw == null) return const FileOpResult(cancelled: true);
    final cancelled = raw['cancelled'] == true;
    final ok =
        (raw['succeeded'] as List?)?.map((e) => '$e').toList() ?? const [];
    final failed = <String, String>{};
    final rawFailed = raw['failed'];
    if (rawFailed is Map) {
      rawFailed.forEach((k, v) => failed['$k'] = '$v');
    }
    return FileOpResult(succeeded: ok, failed: failed, cancelled: cancelled);
  }
}
