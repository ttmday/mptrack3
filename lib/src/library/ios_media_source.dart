import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mptrack3/src/library/media_source.dart';
import 'package:mptrack3/src/model/folder_tree.dart';
import 'package:mptrack3/src/model/track.dart';

/// iOS implementation: the library is the app's Documents folder, which is
/// exposed in the Files app ("On My iPhone > Mptrack3"). Users copy music
/// there; folders, moves and deletes are plain file operations inside the
/// sandbox. Tags and artwork are read natively with AVFoundation.
class IosMediaSource implements MediaSource {
  static const _channel = MethodChannel('mptrack3/ios_media');
  static const volumeId = 'documents';
  static const _extensions = {
    'mp3',
    'm4a',
    'aac',
    'wav',
    'aif',
    'aiff',
    'caf',
    'flac',
    'alac',
    'mp4',
  };

  Directory? _root;
  final Map<String, Map<String, Object?>> _metaCache = {};
  bool _cacheLoaded = false;

  Future<Directory> _rootDir() async =>
      _root ??= await getApplicationDocumentsDirectory();

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/metadata_cache.json');
  }

  @override
  bool get systemConfirmsWrites => false;

  @override
  Future<PermissionStatus> requestPermission() async =>
      PermissionStatus.granted;

  @override
  Stream<void> get changes async* {
    final root = await _rootDir();
    if (!FileSystemEntity.isWatchSupported) return;
    yield* root.watch(recursive: true).map((_) {});
  }

  @override
  Future<LibrarySnapshot> load() async {
    final root = await _rootDir();
    await _loadCache();
    final tracks = <Track>[];
    final folders = <FolderRef>[];
    final seen = <String>{};

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      final relative = _relative(root, entity.path);
      if (relative.isEmpty ||
          relative.split('/').any((s) => s.startsWith('.'))) {
        continue;
      }
      if (entity is Directory) {
        folders.add(FolderRef(volumeId, relative));
        continue;
      }
      if (entity is! File) continue;
      final ext = relative.split('.').last.toLowerCase();
      if (!_extensions.contains(ext)) continue;
      seen.add(relative);
      tracks.add(await _buildTrack(entity, relative));
    }
    _metaCache.removeWhere((key, _) => !seen.contains(key));
    unawaited(_saveCache());
    return LibrarySnapshot(
      tracks: tracks,
      folders: folders,
      volumeLabels: const {volumeId: 'Files'},
    );
  }

  Future<Track> _buildTrack(File file, String relative) async {
    final stat = await file.stat();
    final stamp = '${stat.modified.millisecondsSinceEpoch}:${stat.size}';
    var meta = _metaCache[relative];
    if (meta == null || meta['stamp'] != stamp) {
      meta = {'stamp': stamp, ...await _readMetadata(file.path)};
      _metaCache[relative] = meta;
    }
    final slash = relative.lastIndexOf('/');
    final folder = slash >= 0 ? relative.substring(0, slash) : '';
    final fileName = slash >= 0 ? relative.substring(slash + 1) : relative;
    final fallback = _titleFromFileName(fileName);
    final title = (meta['title'] as String?)?.trim();
    return Track(
      id: relative,
      uri: Uri.file(file.path).toString(),
      volume: volumeId,
      folder: folder,
      fileName: fileName,
      title: (title == null || title.isEmpty) ? fallback.$2 : title,
      artist: (meta['artist'] as String?) ?? fallback.$1,
      album: meta['album'] as String?,
      duration:
          Duration(milliseconds: (meta['durationMs'] as num?)?.toInt() ?? 0),
      dateAdded: stat.modified.millisecondsSinceEpoch ~/ 1000,
      size: stat.size,
      filePath: file.path,
    );
  }

  /// "Artist - Title.mp3" -> (Artist, Title).
  static (String?, String) _titleFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    final parts = base.split(' - ');
    if (parts.length >= 2) {
      return (parts.first.trim(), parts.sublist(1).join(' - ').trim());
    }
    return (null, base);
  }

  Future<Map<String, Object?>> _readMetadata(String path) async {
    try {
      final raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('metadata', {'path': path});
      if (raw == null) return const {};
      return raw.map((k, v) => MapEntry('$k', v));
    } catch (e) {
      log('metadata failed for $path: $e');
      return const {};
    }
  }

  Future<void> _loadCache() async {
    if (_cacheLoaded) return;
    _cacheLoaded = true;
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        decoded.forEach((k, v) {
          if (v is Map) _metaCache['$k'] = v.map((a, b) => MapEntry('$a', b));
        });
      }
    } catch (e) {
      log('metadata cache read failed: $e');
    }
  }

  Future<void> _saveCache() async {
    try {
      final file = await _cacheFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(_metaCache));
    } catch (e) {
      log('metadata cache write failed: $e');
    }
  }

  String _relative(Directory root, String path) {
    var rel =
        path.startsWith(root.path) ? path.substring(root.path.length) : path;
    while (rel.startsWith('/')) {
      rel = rel.substring(1);
    }
    return rel;
  }

  @override
  Future<Uint8List?> artwork(Track track, {int size = 512}) async {
    if (track.filePath == null) return null;
    try {
      return await _channel.invokeMethod<Uint8List>(
          'artwork', {'path': track.filePath, 'size': size});
    } catch (e) {
      return null;
    }
  }

  @override
  String? writeRestriction(FolderRef target) => null;

  Future<Directory> _dirFor(FolderRef folder) async {
    final root = await _rootDir();
    return Directory(
        folder.path.isEmpty ? root.path : '${root.path}/${folder.path}');
  }

  @override
  Future<bool> createFolder(FolderRef folder) async {
    try {
      await (await _dirFor(folder)).create(recursive: true);
      return true;
    } catch (e) {
      log('createFolder failed: $e');
      return false;
    }
  }

  @override
  Future<bool> removeEmptyFolder(FolderRef folder) async {
    if (folder.path.isEmpty) return false;
    try {
      final dir = await _dirFor(folder);
      if (!await dir.list().isEmpty) return false;
      await dir.delete();
      return true;
    } catch (e) {
      log('removeEmptyFolder failed: $e');
      return false;
    }
  }

  @override
  Future<FileOpResult> delete(List<Track> tracks) async {
    final ok = <String>[];
    final failed = <String, String>{};
    for (final track in tracks) {
      try {
        await File(track.filePath!).delete();
        ok.add(track.id);
      } catch (e) {
        failed[track.id] = '$e';
      }
    }
    return FileOpResult(succeeded: ok, failed: failed);
  }

  @override
  Future<FileOpResult> move(List<Track> tracks, FolderRef target) async {
    final ok = <String>[];
    final failed = <String, String>{};
    final renamed = <String, String>{};
    final dir = await _dirFor(target);
    await dir.create(recursive: true);
    final root = await _rootDir();
    for (final track in tracks) {
      try {
        final destination = await _freePath(dir, track.fileName);
        await File(track.filePath!).rename(destination.path);
        ok.add(track.id);
        renamed[track.id] = _relative(root, destination.path);
      } catch (e) {
        failed[track.id] = '$e';
      }
    }
    return FileOpResult(succeeded: ok, failed: failed, renamed: renamed);
  }

  /// Returns a non-existing path in [dir], adding " (n)" when needed.
  Future<File> _freePath(Directory dir, String fileName) async {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot) : '';
    var candidate = File('${dir.path}/$fileName');
    var n = 1;
    while (await candidate.exists()) {
      candidate = File('${dir.path}/$base ($n)$ext');
      n++;
    }
    return candidate;
  }
}
