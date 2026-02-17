import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:mptrack3/src/service/audio_query_request.dart';
import 'package:mptrack3/src/service/notifications_service.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'package:mptrack3/src/model/media_item_converter.dart';
import 'package:mptrack3/src/service/audio_manager.dart';

// DateTime playerTapTime = DateTime.now();
// bool get isProcessForPlay {
//   return DateTime.now().difference(playerTapTime).inMilliseconds > 600;
// }

Timer? debounce;

void onDebounce(void Function() action) {
  if (debounce != null) {
    debounce!.cancel();
  }
  debounce = Timer(const Duration(milliseconds: 1000), action);
}

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
      await _startListeningForMediaChanges();
    }
  }

  Future<void> _startListeningForMediaChanges() async {
    List<String> filesPath = [];

    try {
      platform.setMethodCallHandler((call) async {
        if (call.method == "onMediaChanged") {
          String filePath = call.arguments;

          if (filePath.contains(".trashed")) return;
          if (!filePath.trim().endsWith('.mp3')) return;

          filesPath.add(filePath);

          onDebounce(() async {
            List<String> paths = filesPath.toSet().toList();
            final songs = await _queryRequest.getSongs();
            if (songs.isEmpty) return;
            _songs = songs;

            _songs.sort((a, b) {
              int? dateA = a.dateAdded;
              int? dateB = b.dateAdded;

              if (dateA != null && dateB != null) {
                return dateB.compareTo(dateA);
              }

              if (dateA == null) {
                return 1;
              }

              return -1;
            });
            final result = songs.where((s) => paths.contains(s.data));
            await _audioManager
                .addQueueItems(result.map((s) => s.toMediaItem()).toList());
            await NotificationsService.getInstance()
                .show(title: "Mptrack3", body: "Playlist actualizada.");
            filesPath = [];
          });
        }
      });

      await platform.invokeMethod('listen');
    } on PlatformException catch (e) {
      log("PlatformException startListeningForMediaChanges: '${e.message}'.");
    } on MissingPluginException catch (e) {
      log("MissingPluginException startListeningForMediaChanges: '${e.message}'.");
    } catch (e) {
      log("Error startListeningForMediaChanges $e");
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
