import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/model/track.dart';
import 'package:mptrack3/src/player/play_order.dart';

typedef ArtworkLoader = Future<Uint8List?> Function(Track track);

Future<PlayerHandler> initPlayerHandler(ArtworkLoader artworkLoader) async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  return AudioService.init(
    builder: () => PlayerHandler(artworkLoader),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'github.com.ttmday.mptrack3.channel.audio',
      androidNotificationChannelName: 'Mptrack3 playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      notificationColor: AppColors.background,
    ),
  );
}

/// Owns playback. The queue keeps the order it was given (folder order);
/// [PlayOrder] decides what plays next, so shuffling never reorders the list
/// the user sees.
///
/// Each track is loaded individually into just_audio instead of using a
/// concatenating source; this trades gapless playback for a queue that is
/// trivial to keep consistent with library changes.
class PlayerHandler extends BaseAudioHandler with SeekHandler {
  PlayerHandler(this._artworkLoader) {
    _player.playbackEventStream.listen(
      (_) => _broadcastState(),
      // Load failures are handled where setAudioSource is awaited.
      onError: (Object e, StackTrace st) =>
          log('playback error', error: e, stackTrace: st),
    );
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _onCompleted();
    });
    _player.durationStream.listen(_onDuration);
    playbackState.add(PlaybackState());
    queue.add(const []);
  }

  final ArtworkLoader _artworkLoader;
  final AudioPlayer _player = AudioPlayer();
  final PlayOrder _order = PlayOrder();

  List<Track> _tracks = const [];
  RepeatMode _repeat = RepeatMode.off;
  int _loadToken = 0;
  int _consecutiveFailures = 0;
  bool _completing = false;

  /// Current track (richer than [mediaItem]).
  final currentTrack = BehaviorSubject<Track?>.seeded(null);

  /// Emits whenever the play order / queue / modes change.
  final orderChanged = PublishSubject<void>();

  /// Human readable origin of the queue, e.g. "~/Music/Rock".
  final queueLabel = BehaviorSubject<String>.seeded('');

  List<Track> get tracks => List.unmodifiable(_tracks);
  RepeatMode get repeat => _repeat;
  bool get shuffle => _order.shuffle;
  bool get playing => _player.playing;
  Duration get position => _player.position;
  int? get currentIndex => _order.current;
  bool get hasNext => _order.hasNext(_repeat == RepeatMode.one ? RepeatMode.off : _repeat);
  bool get hasPrevious => _order.hasPrevious(_repeat == RepeatMode.one ? RepeatMode.off : _repeat);
  Stream<Duration> get positionStream => _player.positionStream;

  /// Every queued track in play order (already played, current, upcoming).
  List<Track> orderedTracks() =>
      _order.order.where((i) => i < _tracks.length).map((i) => _tracks[i]).toList();

  /// Tracks in the order they will play after the current one.
  List<Track> upcoming({int limit = 50}) =>
      _order.upcoming(_repeat, limit: limit).map((i) => _tracks[i]).toList();

  // ---------------------------------------------------------------------
  // Queue management

  Future<void> setTracks(
    List<Track> tracks, {
    int startIndex = 0,
    bool autoplay = true,
    bool? shuffle,
    String label = '',
    Duration position = Duration.zero,
  }) async {
    _tracks = List.of(tracks);
    _order.reset(_tracks.length, startIndex: startIndex, shuffle: shuffle);
    queueLabel.add(label);
    queue.add(_tracks.map((t) => t.toMediaItem()).toList());
    _consecutiveFailures = 0;
    _notifyOrder();
    if (_tracks.isEmpty) {
      await _player.stop();
      currentTrack.add(null);
      mediaItem.add(null);
      return;
    }
    await _loadCurrent(autoplay: autoplay, position: position);
  }

  /// Appends tracks (e.g. new files that appeared in the playing folder).
  void appendTracks(List<Track> tracks) {
    final known = _tracks.map((t) => t.id).toSet();
    final fresh = tracks.where((t) => !known.contains(t.id)).toList();
    if (fresh.isEmpty) return;
    _tracks = [..._tracks, ...fresh];
    _order.append(fresh.length);
    queue.add(_tracks.map((t) => t.toMediaItem()).toList());
    _notifyOrder();
  }

  /// Removes tracks that no longer exist. If the current one is removed,
  /// playback continues with the next track.
  Future<void> removeTracks(Set<String> ids) async {
    if (ids.isEmpty || _tracks.isEmpty) return;
    final current = currentTrack.value;
    final removingCurrent = current != null && ids.contains(current.id);
    final wasPlaying = _player.playing;

    for (var i = _tracks.length - 1; i >= 0; i--) {
      if (ids.contains(_tracks[i].id)) _order.removeQueueIndex(i);
    }
    _tracks = _tracks.where((t) => !ids.contains(t.id)).toList();
    queue.add(_tracks.map((t) => t.toMediaItem()).toList());
    _notifyOrder();

    if (!removingCurrent) return;
    if (_tracks.isEmpty) {
      await _player.stop();
      currentTrack.add(null);
      mediaItem.add(null);
      return;
    }
    await _loadCurrent(autoplay: wasPlaying);
  }

  /// Applies metadata/location changes (moves) to queued tracks.
  void updateTracks(List<Track> updated, Map<String, String> renamed) {
    if (_tracks.isEmpty || (updated.isEmpty && renamed.isEmpty)) return;
    final byId = {for (final t in updated) t.id: t};
    final reverse = {for (final e in renamed.entries) e.value: e.key};
    final oldToNew = <String, Track>{};
    for (final t in updated) {
      oldToNew[reverse[t.id] ?? t.id] = t;
    }
    var changed = false;
    _tracks = _tracks.map((t) {
      final replacement = oldToNew[t.id] ?? byId[t.id];
      if (replacement == null) return t;
      changed = true;
      return replacement;
    }).toList();
    if (!changed) return;
    queue.add(_tracks.map((t) => t.toMediaItem()).toList());
    final index = _order.current;
    if (index != null) {
      currentTrack.add(_tracks[index]);
      final item = mediaItem.value;
      mediaItem.add(_tracks[index].toMediaItem(artUri: item?.artUri));
    }
    _notifyOrder();
  }

  // ---------------------------------------------------------------------
  // Transport

  @override
  Future<void> play() async {
    if (_tracks.isEmpty) return;
    if (_player.processingState == ProcessingState.idle) {
      // After stop() the source is released: start the track over.
      await _loadCurrent(autoplay: true);
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  Future<void> togglePlay() => _player.playing ? pause() : play();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    final manualRepeat = _repeat == RepeatMode.one ? RepeatMode.off : _repeat;
    final next = _order.next(manualRepeat);
    if (next == null) return;
    _notifyOrder();
    await _loadCurrent(autoplay: true);
  }

  /// Restarts the track when more than 3 s in, otherwise goes back.
  @override
  Future<void> skipToPrevious() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    final manualRepeat = _repeat == RepeatMode.one ? RepeatMode.off : _repeat;
    final previous = _order.previous(manualRepeat);
    if (previous == null) {
      await _player.seek(Duration.zero);
      return;
    }
    _notifyOrder();
    await _loadCurrent(autoplay: true);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    _order.jumpTo(index);
    _notifyOrder();
    await _loadCurrent(autoplay: true);
  }

  Future<void> playTrackId(String id) async {
    final index = _tracks.indexWhere((t) => t.id == id);
    if (index >= 0) await skipToQueueItem(index);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _order.setShuffle(shuffleMode != AudioServiceShuffleMode.none);
    _notifyOrder();
    _broadcastState();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeat = switch (repeatMode) {
      AudioServiceRepeatMode.none => RepeatMode.off,
      AudioServiceRepeatMode.one => RepeatMode.one,
      AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => RepeatMode.all,
    };
    _notifyOrder();
    _broadcastState();
  }

  @override
  Future<void> onTaskRemoved() async {
    if (!_player.playing) await stop();
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'dispose') {
      await _player.dispose();
      await super.stop();
    }
  }

  // ---------------------------------------------------------------------
  // Internals

  Future<void> _loadCurrent({required bool autoplay, Duration position = Duration.zero}) async {
    final index = _order.current;
    if (index == null || index >= _tracks.length) return;
    final track = _tracks[index];
    final token = ++_loadToken;

    currentTrack.add(track);
    mediaItem.add(track.toMediaItem());
    _broadcastState();

    try {
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(track.uri), tag: track.id),
        initialPosition: position,
      );
      if (token != _loadToken) return;
      _consecutiveFailures = 0;
      if (autoplay) unawaited(_player.play());
    } catch (e) {
      if (token != _loadToken) return;
      log('cannot load ${track.uri}: $e');
      await _onTrackFailed(autoplay: autoplay);
      return;
    }
    unawaited(_publishArtwork(track, token));
  }

  Future<void> _onTrackFailed({bool autoplay = true}) async {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _tracks.length) {
      await _player.stop();
      return;
    }
    final next = _order.next(RepeatMode.all);
    if (next == null) return;
    _notifyOrder();
    await _loadCurrent(autoplay: autoplay);
  }

  Future<void> _onCompleted() async {
    if (_completing) return;
    _completing = true;
    try {
      if (_repeat == RepeatMode.one) {
        await _player.seek(Duration.zero);
        unawaited(_player.play());
        return;
      }
      final next = _order.next(_repeat);
      if (next == null) {
        await _player.pause();
        await _player.seek(Duration.zero);
        return;
      }
      _notifyOrder();
      await _loadCurrent(autoplay: true);
    } finally {
      _completing = false;
    }
  }

  void _onDuration(Duration? duration) {
    final index = _order.current;
    if (duration == null || index == null || index >= _tracks.length) return;
    final track = _tracks[index];
    if (track.duration == duration) return;
    final updated = track.copyWith(duration: duration);
    _tracks = List.of(_tracks)..[index] = updated;
    currentTrack.add(updated);
    final item = mediaItem.value;
    if (item != null && item.id == track.id) {
      mediaItem.add(item.copyWith(duration: duration));
    }
  }

  Future<void> _publishArtwork(Track track, int token) async {
    Uri? artUri;
    try {
      final bytes = await _artworkLoader(track);
      if (bytes == null || token != _loadToken) return;
      final dir = await getTemporaryDirectory();
      // One file per track: audio_service caches artwork by uri, so a
      // reused file name would show a stale cover in the notification.
      final name = track.id.hashCode.toUnsigned(32).toRadixString(16);
      final file = File('${dir.path}/art_$name.jpg');
      if (!await file.exists()) await file.writeAsBytes(bytes, flush: true);
      artUri = Uri.file(file.path);
    } catch (e) {
      log('artwork publish failed: $e');
    }
    if (artUri == null || token != _loadToken) return;
    final item = mediaItem.value;
    if (item != null && item.id == track.id) {
      mediaItem.add(item.copyWith(artUri: artUri));
    }
  }

  void _notifyOrder() {
    orderChanged.add(null);
  }

  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToQueueItem,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _order.current,
      repeatMode: switch (_repeat) {
        RepeatMode.off => AudioServiceRepeatMode.none,
        RepeatMode.one => AudioServiceRepeatMode.one,
        RepeatMode.all => AudioServiceRepeatMode.all,
      },
      shuffleMode: _order.shuffle
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    ));
  }
}
