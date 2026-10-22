import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mptrack3/src/library/library_repository.dart';
import 'package:mptrack3/src/model/folder_tree.dart';
import 'package:mptrack3/src/model/track.dart';
import 'package:mptrack3/src/player/audio_handler.dart';
import 'package:mptrack3/src/player/play_order.dart';

enum PlayState { stopped, paused, loading, playing }

class ProgressState {
  const ProgressState(this.position, this.duration);
  final Duration position;
  final Duration duration;
  static const zero = ProgressState(Duration.zero, Duration.zero);
}

/// UI-facing facade over [PlayerHandler]: exposes listenables, keeps the
/// queue in sync with library changes, persists the session and runs the
/// sleep timer.
class PlayerController {
  PlayerController(this._handler, this._library, this._prefs) {
    _subs.addAll([
      _handler.currentTrack.listen((t) {
        currentTrack.value = t;
        _refreshNavigation();
        _scheduleSave();
      }),
      _handler.playbackState.listen(_onPlaybackState),
      _handler.orderChanged.listen((_) {
        _refreshNavigation();
        _scheduleSave();
      }),
      _handler.queueLabel.listen((label) => queueLabel.value = label),
      _handler.positionStream.listen((position) {
        final duration = currentTrack.value?.duration ?? Duration.zero;
        progress.value = ProgressState(position, duration);
      }),
      _library.diffs.listen(_onLibraryDiff),
    ]);
  }

  static const _sessionKey = 'player.session';
  static const _shuffleKey = 'player.shuffle';
  static const _repeatKey = 'player.repeat';
  static const _contextKey = 'player.context';
  static const _positionKey = 'player.position';

  final PlayerHandler _handler;
  final LibraryRepository _library;
  final SharedPreferences _prefs;
  final List<StreamSubscription<dynamic>> _subs = [];

  final currentTrack = ValueNotifier<Track?>(null);
  final playState = ValueNotifier<PlayState>(PlayState.stopped);
  final progress = ValueNotifier<ProgressState>(ProgressState.zero);
  final shuffle = ValueNotifier<bool>(false);
  final repeat = ValueNotifier<RepeatMode>(RepeatMode.off);
  final hasNext = ValueNotifier<bool>(false);
  final hasPrevious = ValueNotifier<bool>(false);
  final queueLabel = ValueNotifier<String>('');

  /// Increments whenever the queue or its order changes.
  final queueVersion = ValueNotifier<int>(0);
  final sleepAt = ValueNotifier<DateTime?>(null);

  /// Folder the queue was built from, used to append new files.
  FolderRef? _context;

  /// Whether the queue also includes the context folder's subfolders.
  bool _contextRecursive = false;
  Timer? _sleepTimer;
  Timer? _saveTimer;

  List<Track> get queue => _handler.tracks;
  int? get currentIndex => _handler.currentIndex;
  List<Track> upcoming({int limit = 50}) => _handler.upcoming(limit: limit);

  /// Whether [tracks] contain exactly the songs of the current queue.
  bool isQueue(List<Track> tracks) {
    final queue = _handler.tracks;
    if (queue.isEmpty || queue.length != tracks.length) return false;
    final ids = queue.map((t) => t.id).toSet();
    return tracks.every((t) => ids.contains(t.id));
  }

  /// [tracks] as they should be shown: in play order when shuffle is on and
  /// they are the current queue, otherwise unchanged.
  List<Track> displayOrder(List<Track> tracks) {
    if (!shuffle.value || !isQueue(tracks)) return tracks;
    return _handler.orderedTracks();
  }

  /// Shuffle button: turning shuffle on for a list that is not playing yet
  /// starts that list shuffled; otherwise it just toggles the mode.
  Future<void> toggleShuffleFor(
    List<Track> visible, {
    String label = '',
    FolderRef? context,
    bool recursive = false,
  }) async {
    final enable = !shuffle.value;
    if (enable && visible.isNotEmpty && !isQueue(visible)) {
      await _prefs.setBool(_shuffleKey, true);
      await playTracks(
        visible,
        startIndex: DateTime.now().microsecond % visible.length,
        shuffle: true,
        label: label,
        context: context,
        recursive: recursive,
      );
      return;
    }
    await setShuffle(enable);
  }

  // ---------------------------------------------------------------------
  // Starting playback

  Future<void> playTracks(
    List<Track> tracks, {
    int startIndex = 0,
    bool? shuffle,
    String label = '',
    FolderRef? context,
    bool recursive = false,
  }) async {
    if (tracks.isEmpty) return;
    _context = context;
    _contextRecursive = recursive;
    if (shuffle != null) this.shuffle.value = shuffle;
    await _handler.setTracks(
      tracks,
      startIndex: startIndex,
      shuffle: this.shuffle.value,
      label: label,
    );
  }

  /// Plays [tracks] starting at [track]. If the same queue is already
  /// loaded it just jumps, so the shuffle cycle is preserved.
  Future<void> playFrom(
    List<Track> tracks,
    Track track, {
    String label = '',
    FolderRef? context,
    bool restart = false,
  }) async {
    if (!restart && _sameQueue(tracks)) {
      await _handler.playTrackId(track.id);
      return;
    }
    final index = tracks.indexWhere((t) => t.id == track.id);
    await playTracks(tracks,
        startIndex: index < 0 ? 0 : index, label: label, context: context);
  }

  /// Plays every track under [folder]. With [shuffled] true it starts at a
  /// random track with shuffle on.
  Future<bool> playFolder(
    FolderNode folder,
    List<Track> tracks,
    String label, {
    bool shuffled = false,
  }) async {
    if (tracks.isEmpty) return false;
    final start = shuffled ? DateTime.now().microsecond % tracks.length : 0;
    await playTracks(tracks,
        startIndex: start,
        shuffle: shuffled ? true : null,
        label: label,
        context: folder.ref,
        recursive: true);
    return true;
  }

  bool _sameQueue(List<Track> tracks) {
    final current = _handler.tracks;
    if (current.length != tracks.length) return false;
    for (var i = 0; i < tracks.length; i++) {
      if (current[i].id != tracks[i].id) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------
  // Transport

  Future<void> togglePlay() => _handler.togglePlay();
  Future<void> play() => _handler.play();
  Future<void> pause() => _handler.pause();
  Future<void> stop() => _handler.stop();
  Future<void> next() => _handler.skipToNext();
  Future<void> previous() => _handler.skipToPrevious();
  Future<void> seek(Duration position) => _handler.seek(position);
  Future<void> playQueueIndex(int index) => _handler.skipToQueueItem(index);

  Future<void> setShuffle(bool enabled) async {
    shuffle.value = enabled;
    await _handler.setShuffleMode(
        enabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none);
    await _prefs.setBool(_shuffleKey, enabled);
  }

  Future<void> toggleShuffle() => setShuffle(!shuffle.value);

  Future<void> setRepeat(RepeatMode mode) async {
    repeat.value = mode;
    await _handler.setRepeatMode(switch (mode) {
      RepeatMode.off => AudioServiceRepeatMode.none,
      RepeatMode.one => AudioServiceRepeatMode.one,
      RepeatMode.all => AudioServiceRepeatMode.all,
    });
    await _prefs.setString(_repeatKey, mode.name);
  }

  Future<void> cycleRepeat() => setRepeat(
      RepeatMode.values[(repeat.value.index + 1) % RepeatMode.values.length]);

  // ---------------------------------------------------------------------
  // Sleep timer

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    if (duration == null || duration <= Duration.zero) {
      sleepAt.value = null;
      return;
    }
    sleepAt.value = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      sleepAt.value = null;
      _handler.pause();
    });
  }

  // ---------------------------------------------------------------------
  // Library sync

  void _onLibraryDiff(LibraryDiff diff) {
    if (diff.removedIds.isNotEmpty) {
      unawaited(_handler.removeTracks(diff.removedIds));
    }
    if (diff.updated.isNotEmpty || diff.renamed.isNotEmpty) {
      _handler.updateTracks(diff.updated, diff.renamed);
    }
    final context = _context;
    if (diff.added.isNotEmpty && context != null && _handler.tracks.isNotEmpty) {
      final inContext = diff.added.where((t) =>
          t.volume == context.volume &&
          (t.folder == context.path ||
              (_contextRecursive &&
                  (context.path.isEmpty || t.folder.startsWith('${context.path}/')))));
      _handler.appendTracks(inContext.toList());
    }
  }

  // ---------------------------------------------------------------------
  // State mirroring

  void _onPlaybackState(PlaybackState state) {
    playState.value = switch (state.processingState) {
      AudioProcessingState.loading ||
      AudioProcessingState.buffering =>
        PlayState.loading,
      AudioProcessingState.idle =>
        state.playing ? PlayState.loading : PlayState.stopped,
      _ => state.playing ? PlayState.playing : PlayState.paused,
    };
    if (!state.playing) _scheduleSave();
  }

  void _refreshNavigation() {
    hasNext.value = _handler.hasNext;
    hasPrevious.value = _handler.currentIndex != null;
    queueVersion.value++;
  }

  // ---------------------------------------------------------------------
  // Persistence

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), saveSession);
  }

  Future<void> saveSession() async {
    final track = currentTrack.value;
    final ids = _handler.tracks.map((t) => t.id).toList();
    if (track == null || ids.isEmpty) return;
    await _prefs.setStringList(_sessionKey, [track.id, queueLabel.value, ...ids]);
    await _prefs.setInt(_positionKey, _handler.position.inMilliseconds);
    final context = _context;
    if (context == null) {
      await _prefs.remove(_contextKey);
    } else {
      await _prefs.setString(
          _contextKey, '${_contextRecursive ? 'r' : 'd'}|${context.key}');
    }
  }

  /// Restores modes and the last queue (paused) once the library is loaded.
  Future<void> restoreSession() async {
    final savedShuffle = _prefs.getBool(_shuffleKey) ?? false;
    final savedRepeat = RepeatMode.values
            .where((m) => m.name == _prefs.getString(_repeatKey))
            .firstOrNull ??
        RepeatMode.off;
    shuffle.value = savedShuffle;
    await setRepeat(savedRepeat);

    final saved = _prefs.getStringList(_sessionKey);
    if (saved == null || saved.length < 3) return;
    final currentId = saved[0];
    final label = saved[1];
    final tracks = saved
        .skip(2)
        .map(_library.byId)
        .whereType<Track>()
        .toList();
    if (tracks.isEmpty) return;
    var start = tracks.indexWhere((t) => t.id == currentId);
    final position = start >= 0
        ? Duration(milliseconds: _prefs.getInt(_positionKey) ?? 0)
        : Duration.zero;
    if (start < 0) start = 0;
    final contextKey = _prefs.getString(_contextKey);
    if (contextKey != null && contextKey.length > 2 && contextKey[1] == '|') {
      _contextRecursive = contextKey[0] == 'r';
      _context = FolderRef.fromKey(contextKey.substring(2));
    }
    await _handler.setTracks(
      tracks,
      startIndex: start,
      autoplay: false,
      shuffle: savedShuffle,
      label: label,
      position: position,
    );
  }

  Future<void> dispose() async {
    await saveSession();
    for (final sub in _subs) {
      await sub.cancel();
    }
    _sleepTimer?.cancel();
    _saveTimer?.cancel();
  }
}
