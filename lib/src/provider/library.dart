import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart' show Either;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mptrack3/src/provider/notifier/library.dart';
import 'package:mptrack3/src/service/library/android_media_source.dart';
import 'package:mptrack3/src/service/library/api/library_error.dart';
import 'package:mptrack3/src/service/library/ios_media_source.dart';
import 'package:mptrack3/src/service/library/media_source.dart';
import 'package:mptrack3/src/service/library/models/index.dart';

export 'package:mptrack3/src/provider/notifier/library.dart';

/// The music library and its folder tree, shared by the whole app.
class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this._prefs, {MediaSource? source})
      : source = source ??
            (Platform.isIOS ? IosMediaSource() : AndroidMediaSource());

  static const _virtualFoldersKey = 'library.virtualFolders';
  static const _hiddenFoldersKey = 'library.hiddenFolders';
  static const _refreshDebounce = Duration(milliseconds: 1500);

  final MediaSource source;
  final SharedPreferences _prefs;

  LibraryStatus _status = LibraryStatus.loading;
  String? _error;
  List<Track> _allTracks = const [];
  List<Track> _tracks = const [];
  Map<String, Track> _byId = const {};
  FolderTree _tree = FolderTree.empty();
  List<FolderRef> _platformFolders = const [];
  Map<String, String> _volumeLabels = const {};

  StreamSubscription<void>? _changesSub;
  Timer? _debounce;
  bool _loading = false;
  bool _reloadPending = false;

  final _diffs = StreamController<LibraryDiff>.broadcast();
  final _artCache = <String, Future<Uint8List?>>{};

  LibraryStatus get status => _status;
  String? get error => _error;

  /// Tracks outside hidden folders.
  List<Track> get tracks => _tracks;
  FolderTree get tree => _tree;
  Stream<LibraryDiff> get diffs => _diffs.stream;
  Track? byId(String id) => _byId[id];

  Set<FolderRef> get hiddenFolders => _readRefs(_hiddenFoldersKey);
  Set<FolderRef> get _virtualFolders => _readRefs(_virtualFoldersKey);

  Future<void> init() async {
    final permission = await source.requestPermission();
    if (permission != PermissionStatus.granted) {
      _status = permission == PermissionStatus.permanentlyDenied
          ? LibraryStatus.permanentlyDenied
          : LibraryStatus.noPermission;
      notifyListeners();
      return;
    }
    await reload();
    _changesSub ??= source.changes.listen((_) => scheduleReload());
  }

  Future<void> retryPermission() async {
    _status = LibraryStatus.loading;
    notifyListeners();
    await init();
  }

  void scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(_refreshDebounce, reload);
  }

  Future<LibraryDiff> reload() async {
    if (_loading) {
      _reloadPending = true;
      return const LibraryDiff();
    }
    _loading = true;
    final result = await source.load();
    _loading = false;
    final diff = result.fold(_onLoadError, _applySnapshot);
    notifyListeners();
    if (!diff.isEmpty) _diffs.add(diff);
    if (_reloadPending) {
      _reloadPending = false;
      scheduleReload();
    }
    return diff;
  }

  LibraryDiff _onLoadError(LibraryError error) {
    log('library load failed: $error');
    _error = error.message ?? error.code;
    if (_status != LibraryStatus.ready) _status = LibraryStatus.error;
    return const LibraryDiff();
  }

  LibraryDiff _applySnapshot(LibrarySnapshot snapshot) {
    final previous = _byId;
    final wasReady = _status == LibraryStatus.ready;
    _allTracks = snapshot.tracks;
    _platformFolders = snapshot.folders;
    _volumeLabels = {..._volumeLabels, ...snapshot.volumeLabels};
    _rebuild();
    _status = LibraryStatus.ready;
    _error = null;
    if (!wasReady) return const LibraryDiff();
    return LibraryDiff(
      added: _tracks.where((t) => !previous.containsKey(t.id)).toList(),
      removedIds: previous.keys.where((id) => !_byId.containsKey(id)).toSet(),
      updated: _tracks
          .where((t) => previous[t.id] != null && previous[t.id]!.folder != t.folder)
          .toList(),
    );
  }

  void _rebuild() {
    final hidden = hiddenFolders;
    _tracks = _allTracks.where((t) => !_isHidden(t, hidden)).toList()
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    _byId = {for (final t in _tracks) t.id: t};
    _tree = FolderTree.build(
      _tracks,
      extraFolders: [
        ..._platformFolders.where((f) => !_isHiddenRef(f, hidden)),
        ..._virtualFolders,
      ],
      volumeLabels: _volumeLabels,
    );
  }

  static bool _isHidden(Track track, Set<FolderRef> hidden) =>
      _isHiddenRef(FolderRef(track.volume, track.folder), hidden);

  static bool _isHiddenRef(FolderRef ref, Set<FolderRef> hidden) {
    for (final h in hidden) {
      if (h.volume != ref.volume) continue;
      if (ref.path == h.path || ref.path.startsWith('${h.path}/')) return true;
    }
    return false;
  }

  /// Creates [name] inside [parent]; returns an error message or null.
  Future<String?> createFolder(FolderNode parent, String name) async {
    final clean = name.trim();
    if (parent.ref == null) return 'choose a storage first (cd into it)';
    if (clean.isEmpty || clean == '.' || clean == '..') return 'invalid name';
    if (RegExp(r'[/\\:*?"<>|]').hasMatch(clean)) {
      return 'name cannot contain / \\ : * ? " < > |';
    }
    if (_tree.matchChild(parent, clean)?.name.toLowerCase() ==
        clean.toLowerCase()) {
      return '$clean: already exists';
    }
    final ref = FolderRef(parent.volume!, parent.ref!.child(clean));
    final restriction = source.writeRestriction(ref);
    if (restriction != null) return restriction;

    // Creating it on disk is best effort: MediaStore only lists folders that
    // contain tracks, so the folder is also remembered locally.
    await source.createFolder(ref);
    _writeRefs(_virtualFoldersKey, {..._virtualFolders, ref});
    _rebuild();
    notifyListeners();
    return null;
  }

  Future<String?> removeFolder(FolderNode node) async {
    final ref = node.ref;
    if (ref == null || ref.path.isEmpty) return 'cannot remove a storage root';
    if (node.totalTracks > 0) return '${node.name}: folder is not empty';
    await source.removeEmptyFolder(ref);
    _writeRefs(
      _virtualFoldersKey,
      _virtualFolders
          .where((f) => !(f.volume == ref.volume &&
              (f.path == ref.path || f.path.startsWith('${ref.path}/'))))
          .toSet(),
    );
    _platformFolders = _platformFolders.where((f) => f != ref).toList();
    _rebuild();
    notifyListeners();
    return null;
  }

  Future<void> hideFolder(FolderRef ref) async {
    _writeRefs(_hiddenFoldersKey, {...hiddenFolders, ref});
    final before = _byId.keys.toSet();
    _rebuild();
    notifyListeners();
    final removed = before.difference(_byId.keys.toSet());
    if (removed.isNotEmpty) _diffs.add(LibraryDiff(removedIds: removed));
  }

  Future<bool> unhideFolder(FolderRef ref) async {
    final hidden = hiddenFolders;
    if (!hidden.remove(ref)) return false;
    _writeRefs(_hiddenFoldersKey, hidden);
    _rebuild();
    notifyListeners();
    return true;
  }

  Future<FileOpResult> deleteTracks(List<Track> tracks) async {
    final result = _orFailed(await source.delete(tracks), tracks);
    if (result.succeeded.isNotEmpty) {
      final ids = result.succeeded.toSet();
      _allTracks = _allTracks.where((t) => !ids.contains(t.id)).toList();
      _rebuild();
      notifyListeners();
      _diffs.add(LibraryDiff(removedIds: ids));
      scheduleReload();
    }
    return result;
  }

  Future<FileOpResult> moveTracks(List<Track> tracks, FolderNode target) async {
    final ref = target.ref;
    if (ref == null) {
      return FileOpResult(
          failed: {for (final t in tracks) t.id: 'invalid target'});
    }
    final restriction = source.writeRestriction(ref);
    if (restriction != null) {
      return FileOpResult(failed: {for (final t in tracks) t.id: restriction});
    }
    final crossVolume = tracks.where((t) => t.volume != ref.volume).toList();
    if (crossVolume.isNotEmpty) {
      return FileOpResult(failed: {
        for (final t in crossVolume) t.id: 'cannot move between storages'
      });
    }
    final result = _orFailed(await source.move(tracks, ref), tracks);
    if (result.succeeded.isNotEmpty) {
      final ok = result.succeeded.toSet();
      final updated = <Track>[];
      _allTracks = _allTracks.map((t) {
        if (!ok.contains(t.id)) return t;
        final newId = result.renamed[t.id];
        final newPath = t.filePath == null
            ? null
            : _replaceFolder(t.filePath!, t.folder, ref.path);
        final moved = t.copyWith(
          id: newId,
          folder: ref.path,
          filePath: newPath,
          // Content uris on Android survive a move; file uris (iOS) do not.
          uri: (newId != null && newPath != null)
              ? Uri.file(newPath).toString()
              : null,
        );
        updated.add(moved);
        return moved;
      }).toList();
      _rebuild();
      notifyListeners();
      _diffs.add(LibraryDiff(renamed: result.renamed, updated: updated));
      scheduleReload();
    }
    return result;
  }

  static FileOpResult _orFailed(
          Either<LibraryError, FileOpResult> result, List<Track> tracks) =>
      result.fold(
        (error) => FileOpResult(
            failed: {for (final t in tracks) t.id: error.message ?? error.code}),
        (value) => value,
      );

  static String _replaceFolder(
      String full, String oldFolder, String newFolder) {
    final marker = oldFolder.isEmpty ? '/' : '/$oldFolder/';
    final index = full.lastIndexOf(marker);
    if (index < 0) return full;
    final replacement = newFolder.isEmpty ? '/' : '/$newFolder/';
    return full.replaceRange(index, index + marker.length, replacement);
  }

  Future<Uint8List?> artwork(Track track, {int size = 512}) {
    final key = '${track.id}@$size';
    final cached = _artCache.remove(key);
    if (cached != null) {
      _artCache[key] = cached;
      return cached;
    }
    final future = source.artwork(track, size: size);
    _artCache[key] = future;
    while (_artCache.length > 80) {
      _artCache.remove(_artCache.keys.first);
    }
    return future;
  }

  Set<FolderRef> _readRefs(String key) =>
      (_prefs.getStringList(key) ?? const [])
          .map(FolderRef.fromKey)
          .whereType<FolderRef>()
          .toSet();

  void _writeRefs(String key, Set<FolderRef> refs) {
    unawaited(_prefs.setStringList(key, refs.map((r) => r.key).toList()));
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    _debounce?.cancel();
    _diffs.close();
    super.dispose();
  }
}
