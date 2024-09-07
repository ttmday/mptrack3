import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:mptrack3/src/service/audio_query_request.dart';
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
  final AudioQueryRequest _queryRequest;
  final platform = const MethodChannel('media_changes');
  List<SongModel> _songs = [];
  PlayerInvoke(AudioManager audioManager, AudioQueryRequest audioQR)
      : _audioManager = audioManager,
        _queryRequest = audioQR;

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
      await startListeningForMediaChanges();
    }
  }

  Future<void> startListeningForMediaChanges() async {
    bool isCalling = false;
    try {
      platform.setMethodCallHandler((call) async {
        if (call.method == "onMediaChanged" && !isCalling) {
          isCalling = true;
          String filePath = call.arguments;
          if (filePath.contains(".trashed")) return;
          if (filePath.trim().endsWith('.mp3')) {
            int isIndex = _songs.indexWhere((s) => s.data == filePath);
            if (isIndex > -1) return;

            final songs = await _queryRequest.getSongs();
            if (songs.isEmpty) return;
            _songs = songs;

            final result = songs.firstWhere((s) => s.data == filePath);
            _audioManager.add(result.toMediaItem());
            isCalling = false;
          }
        }
      });

      await platform.invokeMethod('listen');
    } on PlatformException catch (e) {
      log("PlatformException startListeningForMediaChanges: '${e.message}'.");
    } on MissingPluginException catch (e) {
      log("MissingPluginException startListeningForMediaChanges: '${e.message}'.");
    } catch (e) {
      log("Error startListeningForMediaChanges $e");
    } finally {
      isCalling = false;
    }
  }

  Future<void> setValues(List arr, int index, {recommend = false}) async {
    final List<MediaItem> queue = [];
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
