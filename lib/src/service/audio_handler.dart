import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/model/media_item_converter.dart';

Future<MyAudioHandler> initAudioService() async {
  return await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'github.com.ttmday.mptrack3.channel.audio',
        androidNotificationChannelName: 'MpTrack3 playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        notificationColor: AppColors.background,
      ));
}

abstract class AudioPlayerHandler extends BaseAudioHandler {
  Future<void> setNewPlaylist(List<MediaItem> mediaItems, int index);
  Future<void> skipToQueueItemById(String id);
  Future<void> moveQueueItem(int currentIndex, int newIndex);
  Future<void> removeQueueItemIndex(int index);
}

class MyAudioHandler extends AudioPlayerHandler with QueueHandler, SeekHandler {
  final player = AudioPlayer();
  final playlist =
      ConcatenatingAudioSource(children: [], useLazyPreparation: true);
  late List<int> preferredCompactNotificationButton = [1, 2, 3];

  MyAudioHandler() {
    loadEmptyPlaylist();
    notifyAudioHandlerAboutPlaybackEvents();
    listenForDurationChanges();
    listenForCurrentSongIndexChanges();
    listenForSequenceStateChanges();
  }

  Future<void> loadEmptyPlaylist() async {
    try {
      preferredCompactNotificationButton = [0, 1, 2];
      await player.setAudioSource(playlist);
    } catch (_) {}
  }

  Future<void> notifyAudioHandlerAboutPlaybackEvents() async {
    player.playbackEventStream.listen((event) {
      final playing = player.playing;

      playbackState.add(PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[player.processingState]!,
        repeatMode: const {
          LoopMode.off: AudioServiceRepeatMode.none,
          LoopMode.one: AudioServiceRepeatMode.one,
          LoopMode.all: AudioServiceRepeatMode.all,
        }[player.loopMode]!,
        shuffleMode: player.shuffleModeEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: event.currentIndex,
      ));
    });
  }

  Future<void> listenForDurationChanges() async {
    player.durationStream.listen((duration) {
      var index = player.currentIndex;
      final newQueue = queue.value;
      if (index == null || newQueue.isEmpty || newQueue.length < index) return;
      if (player.shuffleModeEnabled) {
        index = player.shuffleIndices!.indexOf(index);
      }
      final oldMediaItem = newQueue[index];
      final newMediaItem = oldMediaItem.copyWith(
        duration: duration,
      );
      newQueue[index] = newMediaItem;
      queue.add(newQueue);

      mediaItem.add(newMediaItem);
    });
  }

  Future<void> listenForCurrentSongIndexChanges() async {
    player.currentIndexStream.listen((index) async {
      final pPlaylist = queue.value;
      if (index == null || pPlaylist.isEmpty) return;
      if (player.shuffleModeEnabled) {
        index = player.shuffleIndices!.indexOf(index);
      }
      final image = await pPlaylist[index].getImage();
      MediaItem media = pPlaylist[index];
      if (image != null) {
        media = pPlaylist[index].copyWith(artUri: Uri.dataFromBytes(image));
      }

      mediaItem.add(media);
    });
  }

  Future<void> listenForSequenceStateChanges() async {
    player.sequenceStateStream.listen((sequenceState) {
      final sequence = sequenceState?.effectiveSequence;
      if (sequence == null || sequence.isEmpty) return;
      final items = sequence.map((source) => source.tag as MediaItem);
      queue.add(items.toList());
    });
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final audioSource = createAudioSource(mediaItem);
    await playlist.add(audioSource);
    final newQueue = queue.value..add(mediaItem);
    queue.add(newQueue);
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    final audioSource = createAudioSources(mediaItems);
    await playlist.addAll(audioSource);
    final newQueue = queue.value..addAll(mediaItems);
    queue.add(newQueue);
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    final index = queue.value.indexWhere((item) => item.id == mediaItem.id);
    var dataArr = queue.value;
    dataArr[index] = mediaItem;
    queue.add(dataArr);
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    await playlist.clear();
    await playlist.addAll(createAudioSources(newQueue));
  }

  Future<void> playFromQuery(String q) async {
    // await super.playFromSearch(q);
  }

  UriAudioSource createAudioSource(MediaItem mediaItem) {
    return AudioSource.uri(mediaItem.extras!['uri']!, tag: mediaItem);
  }

  List<UriAudioSource> createAudioSources(List<MediaItem> mediaItems) {
    return mediaItems.map((item) {
      final artUri = _getArtworkUri(item.id);

      item = item.copyWith(artUri: artUri);
      return AudioSource.uri(item.extras!['uri']!, tag: item);
    }).toList();
  }

  Uri? _getArtworkUri(dynamic songId) {
    try {
      // on_audio_query puede darnos los bytes, no siempre un URI directo para artUri
      // Alternativa 1: Usar el URI de la canción directamente (Android a veces lo resuelve)
      // Esto es lo más simple si funciona en tu caso de uso
      // Necesitarías obtener el song.uri aquí si no lo pasaste
      // return Uri.parse(song.uri);

      // Alternativa 2: Consultar los bytes y guardarlos temporalmente (más complejo)
      // Uint8List? artworkBytes = await _audioQuery.queryArtwork(
      //   songId,
      //   ArtworkType.AUDIO,
      //   format: ArtworkFormat.JPEG, // o PNG
      //   size: 200, // Tamaño adecuado para notificación
      // );
      // if (artworkBytes != null) {
      //   // Guardar los bytes en un archivo temporal
      //   final tempDir = await getTemporaryDirectory();
      //   final tempFile = File('${tempDir.path}/art_$songId.jpg');
      //   await tempFile.writeAsBytes(artworkBytes);
      //   return tempFile.uri; // Devuelve un file:// URI
      // }

      // Alternativa 3 (Recomendada si la 1 no funciona bien):
      // Construir un content URI específico para la carátula en Android
      // Esto a menudo funciona bien con MediaStore
      return Uri.parse('content://media/external/audio/media/$songId/albumart');
    } catch (e) {
      print("Error obteniendo artwork URI: $e");
      return null;
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    await playlist.removeRange(0, index);
    final newQueue = queue.value..clear();
    queue.add(newQueue);
  }

  @override
  Future<void> play() async {
    await player.play();
  }

  @override
  Future<void> pause() async {
    await player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    player.seek(position);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    if (player.shuffleModeEnabled) {
      index = player.shuffleIndices![index];
    }
    await player.seek(Duration.zero, index: index);
    await player.play();
  }

  @override
  Future<void> skipToQueueItemById(String id) async {
    if (id.isEmpty || queue.value.isEmpty) return;
    int index = queue.value.indexWhere((q) => q.id == id);
    if (player.shuffleModeEnabled) {
      index = player.shuffleIndices![index];
    }
    await player.seek(Duration.zero, index: index);
    await player.play();
  }

  @override
  Future<void> skipToNext() async {
    player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    player.seekToPrevious();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.group:
      case AudioServiceRepeatMode.all:
        player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.none) {
      player.setShuffleModeEnabled(false);
    } else {
      player.shuffle();
      player.setShuffleModeEnabled(true);
    }
  }

  @override
  Future customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'dispose') {
      await player.dispose();
      super.stop();
    }
  }

  @override
  Future<void> stop() async {
    playbackState.add(playbackState.value
        .copyWith(processingState: AudioProcessingState.idle));

    await super.stop();
    await player.stop();
    return;
  }

  @override
  Future<void> moveQueueItem(int currentIndex, int newIndex) async {
    await playlist.move(currentIndex, newIndex);
  }

  @override
  Future<void> removeQueueItemIndex(int index) async {
    await playlist.removeAt(index);
  }

  @override
  Future<void> setNewPlaylist(List<MediaItem> mediaItems, int index) async {
    if (!Platform.isAndroid) {
      await player.stop();
    }

    var getCount = queue.value.length;
    await playlist.removeRange(0, getCount);
    final audioSource = createAudioSources(mediaItems);
    await playlist.addAll(audioSource);
    final newQueue = queue.value..addAll(mediaItems);
    queue.add(newQueue);

    try {
      await player.setAudioSource(playlist,
          initialIndex: index, initialPosition: Duration.zero);
    } catch (_) {
      setNewPlaylist(mediaItems, index);
    }
  }
}
