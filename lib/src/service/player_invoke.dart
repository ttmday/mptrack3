import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'package:mptrack3/src/model/media_item_converter.dart';
import 'package:mptrack3/src/service/audio_manager.dart';

// DateTime playerTapTime = DateTime.now();
// bool get isProcessForPlay {
//   return DateTime.now().difference(playerTapTime).inMilliseconds > 600;
// }

// Timer? debounce;

// void playerPlayProcessDebounce(List songsList, int index) {
//   debounce?.cancel();
//   debounce = Timer(const Duration(milliseconds: 600), () {
//     PlayerInvoke.init(songsList: songsList, index: index);
//   });
// }

class PlayerInvoke {
  final AudioManager _audioManager;

  late final List<SongModel> _songs;
  PlayerInvoke(AudioManager audioManager) : _audioManager = audioManager;

  Future<void> init({
    required List<SongModel> songsList,
    required int index,
    bool fromMiniPlayer = false,
    bool shuffle = false,
    String? playlistBox,
  }) async {
    _songs = songsList;
    _audioManager.init();
    final int globalIndex = index < 0 ? 0 : index;
    final List finalList = songsList.toList();
    if (shuffle) finalList.shuffle();

    if (!fromMiniPlayer) {
      if (!Platform.isAndroid) {
        await _audioManager.stop();
      }

      setValues(finalList, globalIndex);
    }
  }

  Future<void> setValues(List arr, int index, {recommend = false}) async {
    final List<MediaItem> queue = [];
    // final Map playItem = arr[index] as Map;
    // final Map? nextItem =
    //     index == arr.length - 1 ? null : arr[index + 1] as Map;

    queue.addAll(
      arr.map((song) => (song as SongModel).toMediaItem()),
    );
    updateNPlay(queue, index);
  }

  Future<void> updateValues(List arr) async {
    final List<MediaItem> queue = [];

    queue.addAll(
      arr.map((song) => (song as SongModel).toMediaItem()),
    );
    _audioManager.updateQueue(queue);
  }

  void updateSongListBySearch(String search) {
    if (search.isEmpty) {
      updateValues(_songs);
      return;
    }
    List<SongModel> s = _songs.where((song) {
      if (song.title.toLowerCase().contains(search.toLowerCase())) {
        return true;
      }

      if (song.artist != null &&
          song.artist!.toLowerCase().contains(search.toLowerCase())) {
        return true;
      }

      return false;
    }).toList();

    if (s.isEmpty) {
      updateValues(_songs);
      return;
    }

    updateValues(s);
  }

  Future<void> updateNPlay(List<MediaItem> queue, int index) async {
    try {
      await _audioManager.setShuffleMode(AudioServiceShuffleMode.none);
      await _audioManager.adds(queue, index);
    } catch (_) {}
  }
}
