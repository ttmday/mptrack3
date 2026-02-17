import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mptrack3/src/service/audio_handler.dart';

enum ManagerState { loading, empty, error, ready }

class ManagerNotifier extends ValueNotifier<ManagerState> {
  ManagerNotifier() : super(_initialValue);
  static const _initialValue = ManagerState.loading;
}

enum ButtonState {
  paused,
  playing,
  loading,
}

class PlayButtonNotifier extends ValueNotifier<ButtonState> {
  PlayButtonNotifier() : super(_initialValue);
  static const _initialValue = ButtonState.paused;
}

class ProgressBarState {
  final Duration current;
  final Duration buffered;
  final Duration total;

  ProgressBarState(
      {required this.current, required this.buffered, required this.total});
}

class ProgressNotifier extends ValueNotifier<ProgressBarState> {
  ProgressNotifier() : super(_initialValue);
  static final _initialValue = ProgressBarState(
    current: Duration.zero,
    buffered: Duration.zero,
    total: Duration.zero,
  );
}

enum RepeatState {
  off,
  repeatSong,
  repeatPlaylist,
}

class RepeatButtonNotifier extends ValueNotifier<RepeatState> {
  RepeatButtonNotifier() : super(_initialValue);

  static const _initialValue = RepeatState.off;

  void nextState() {
    final next = (value.index + 1) % RepeatState.values.length;
    value = RepeatState.values[next];
  }
}

final class AudioManager {
  final managerNotifier = ManagerNotifier();
  final currentSongNotifier = ValueNotifier<MediaItem?>(null);
  final playbackStatNotifier =
      ValueNotifier<AudioProcessingState>(AudioProcessingState.idle);
  final playlistNotifier = ValueNotifier<List<MediaItem>>([]);
  List<MediaItem> _playlist = [];
  List<MediaItem> _playlistFiltered = [];

  final progressNotifier = ProgressNotifier();
  final repeatButtonNotifier = RepeatButtonNotifier();
  final playButtonNotifier = PlayButtonNotifier();

  final isFirstSongNotifier = ValueNotifier<bool>(true);
  final isLastSongNotifier = ValueNotifier<bool>(true);
  final isShuffleModeEnabledNotifier = ValueNotifier<bool>(false);

  final MyAudioHandler _audioHandler;

  AudioManager(MyAudioHandler audioHandler) : _audioHandler = audioHandler;

  void init() async {
    listenToChangeInPlaylist();
    listenToPlayBackState();
    listenToCurrentPosition();
    listenToBufferedPosition();
    listenToTotalPosition();
    listenToChangesInSong();
  }

  void listenToChangeInPlaylist() {
    _audioHandler.queue.listen((playlist) {
      if (playlist.isEmpty) {
        playlistNotifier.value = [];
        _playlist = [];
        _playlistFiltered = [];
        currentSongNotifier.value = null;
        return;
      }

      bool isNewPlayList = playlist.length > _playlist.length;
      bool isSamePlayList = true;
      // if (playlist.isNotEmpty && _playlist.isNotEmpty) {
      //   isSamePlayList = _playlist[1].id == playlist[1].id;
      // }

      if (_playlistFiltered.isEmpty) {
        playlistNotifier.value = playlist;
      }

      if (isNewPlayList || !isSamePlayList) {
        _playlist = [];
        _playlist = playlist.toSet().toList();
      }

      updateSkipButton();
    });
  }

  updateSkipButton() {
    final mediaItem = _audioHandler.mediaItem.value;
    final playlist = _audioHandler.queue.value;
    if (playlist.length < 2 || mediaItem == null) {
      isFirstSongNotifier.value = true;
      isLastSongNotifier.value = true;
    } else {
      isFirstSongNotifier.value = playlist.first == mediaItem;
      isLastSongNotifier.value = playlist.last == mediaItem;
    }
  }

  void listenToPlayBackState() {
    _audioHandler.playbackState.listen((playbackState) {
      final isPlaying = playbackState.playing;

      final processingState = playbackState.processingState;
      playbackStatNotifier.value = processingState;
      if (processingState == AudioProcessingState.loading ||
          processingState == AudioProcessingState.buffering) {
        playButtonNotifier.value = ButtonState.loading;
      } else if (!isPlaying) {
        playButtonNotifier.value = ButtonState.paused;
      } else if (processingState != AudioProcessingState.completed) {
        playButtonNotifier.value = ButtonState.playing;
      } else {
        _audioHandler.seek(Duration.zero);
        _audioHandler.pause();
      }
    });
  }

  listenToCurrentPosition() {
    AudioService.position.listen((position) {
      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
          current: position,
          buffered: oldState.buffered,
          total: oldState.total);
    });
  }

  listenToBufferedPosition() {
    _audioHandler.playbackState.listen((playbackState) {
      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
          current: oldState.current,
          buffered: playbackState.bufferedPosition,
          total: oldState.total);
    });
  }

  listenToTotalPosition() {
    _audioHandler.mediaItem.listen((mediaItem) {
      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
          current: oldState.current,
          buffered: oldState.buffered,
          total: mediaItem?.duration ?? Duration.zero);
    });
  }

  listenToChangesInSong() {
    _audioHandler.mediaItem.listen((mediaItem) {
      currentSongNotifier.value = mediaItem;

      updateSkipButton();
    });
  }

  void play() => _audioHandler.play();
  void pause() => _audioHandler.pause();
  void playPause() {
    if (_audioHandler.player.playing) {
      _audioHandler.pause();
      return;
    }

    _audioHandler.play();
  }

  void seek(Duration position) => _audioHandler.seek(position);
  void previous() => _audioHandler.skipToPrevious();
  void next() => _audioHandler.skipToNext();

  Future<void> playAS() async {
    return await _audioHandler.play();
  }

  Future<void> updateQueue(List<MediaItem> queue) async {
    return await _audioHandler.updateQueue(queue);
  }

  Future<void> playFromQuery(String q) async {
    if (q.isEmpty) {
      if (_playlist.length > playlistNotifier.value.length) {
        playlistNotifier.value = _playlist;
      }

      if (_playlistFiltered.isNotEmpty) {
        _playlistFiltered = [];
      }
      return;
    }
    List<MediaItem> pl = _playlist
        .where((song) {
          if (song.title.toLowerCase().contains(q.toLowerCase())) {
            return true;
          }

          if (song.artist != null &&
              song.artist!.toLowerCase().contains(q.toLowerCase())) {
            return true;
          }

          return false;
        })
        .toSet()
        .toList();

    if (pl.isEmpty) {
      return;
    }

    _playlistFiltered = [];
    _playlistFiltered = pl;
    playlistNotifier.value = pl;
  }

  Future<void> updateMediaItem(MediaItem mediaItem) async {
    return await _audioHandler.updateMediaItem(mediaItem);
  }

  Future<void> moveMediaItem(int currentIndex, int newIndex) async {
    return await (_audioHandler as AudioPlayerHandler)
        .moveQueueItem(currentIndex, newIndex);
  }

  Future<void> removeQueueItemAt(int index) async {
    return await (_audioHandler as AudioPlayerHandler)
        .removeQueueItemIndex(index);
  }

  Future<void> customAction(String name) async {
    return await _audioHandler.customAction(name);
  }

  Future<void> skipToQueueItem(int index) async {
    if (_playlistFiltered.isNotEmpty) {
      String id = playlistNotifier.value[index].id;
      await _audioHandler.skipToQueueItemById(id);
      return;
    }
    return await _audioHandler.skipToQueueItem(index);
  }

  void repeat() {
    repeatButtonNotifier.nextState();
    final repeatMode = repeatButtonNotifier.value;
    switch (repeatMode) {
      case RepeatState.off:
        _audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
        break;
      case RepeatState.repeatSong:
        _audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
        break;
      case RepeatState.repeatPlaylist:
        _audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
        break;
    }
  }

  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        repeatButtonNotifier.value = RepeatState.off;
        break;
      case AudioServiceRepeatMode.one:
        repeatButtonNotifier.value = RepeatState.repeatSong;
        break;
      case AudioServiceRepeatMode.group:
        break;
      case AudioServiceRepeatMode.all:
        repeatButtonNotifier.value = RepeatState.repeatPlaylist;
        break;
    }
    _audioHandler.setRepeatMode(repeatMode);
  }

  void shuffle() async {
    final enable = !isShuffleModeEnabledNotifier.value;
    isShuffleModeEnabledNotifier.value = enable;

    if (enable) {
      _audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
    } else {
      _audioHandler.setShuffleMode(AudioServiceShuffleMode.none);
    }
  }

  Future<void> setShuffleMode(AudioServiceShuffleMode value) async {
    isShuffleModeEnabledNotifier.value = value == AudioServiceShuffleMode.all;
    return _audioHandler.setShuffleMode(value);
  }

  Future<void> add(MediaItem mediaItem) async {
    _audioHandler.addQueueItem(mediaItem);
  }

  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    _audioHandler.addQueueItems(mediaItems);
  }

  Future<void> adds(List<MediaItem> mediaItems, int index) async {
    if (mediaItems.isEmpty) {
      managerNotifier.value = ManagerState.empty;
      return;
    }

    await _audioHandler.setNewPlaylist(mediaItems, index);
    managerNotifier.value = ManagerState.ready;
  }

  void remove() {
    final lastIndex = _audioHandler.queue.value.length - 1;
    if (lastIndex < 0) return;
    _audioHandler.removeQueueItemAt(lastIndex);
  }

  Future<void> removeAll() async {
    final lastIndex = _audioHandler.queue.value.length - 1;
    if (lastIndex < 0) return;
    _audioHandler.removeQueueItemAt(lastIndex);
  }

  void dispose() {
    _audioHandler.stop();
    _audioHandler.customAction('dispose');
  }

  Future<void> stop() async {
    await _audioHandler.seek(Duration.zero);
    // currentSongNotifier.value = null;
    // await removeAll();
    await Future.delayed(const Duration(milliseconds: 300));
    await _audioHandler.stop();
  }
}
