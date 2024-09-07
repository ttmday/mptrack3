import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';

class AudioQueryRequest {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  // Indicate if application has permission to the library.
  bool _hasPermission = false;

  Future<bool> init() async {
    // (Optinal) Set logging level. By default will be set to 'WARN'.
    //
    // Log will appear on:
    //  * XCode: Debug Console
    //  * VsCode: Debug Console
    //  * Android Studio: Debug and Logcat Console
    LogConfig logConfig = LogConfig(logType: LogType.DEBUG);
    _audioQuery.setLogConfig(logConfig);

    // Check and request for permission.
    return await checkAndRequestPermissions();
  }

  Future<bool> checkAndRequestPermissions({bool retry = false}) async {
    // The param 'retryRequest' is false, by default.
    try {
      _hasPermission = await _audioQuery.checkAndRequest(
        retryRequest: retry,
      );

      // Only call update the UI if application has all required permissions.
      return _hasPermission;
    } catch (e) {
      return false;
    }
  }

  Future<List<SongModel>> getSongs() {
    return computeIsolate<List<SongModel>>(() => _audioQuery.querySongs(
          sortType: null,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
        ));
  }

  Future<List<dynamic>> getSong(String path) {
    return _audioQuery.queryWithFilters(
      path,
      WithFiltersType.AUDIOS,
    );
  }

  scan(String path) async {
    File file = File(path);
    try {
      if (file.existsSync()) {
        _audioQuery.scanMedia(file.path); // Scan the media 'path'
      }
    } catch (e) {
      log("Error Query Audio scan $e");
    }
  }
}

Future<T> computeIsolate<T>(Future<T> Function() function) async {
  final receivePort = ReceivePort();
  var rootToken = RootIsolateToken.instance!;
  await Isolate.spawn<_IsolateData>(
    _isolateEntry,
    _IsolateData(
      token: rootToken,
      function: function,
      answerPort: receivePort.sendPort,
    ),
  );
  return await receivePort.first;
}

void _isolateEntry(_IsolateData isolateData) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(isolateData.token);
  final answer = await isolateData.function();
  isolateData.answerPort.send(answer);
}

class _IsolateData {
  final RootIsolateToken token;
  final Function function;
  final SendPort answerPort;

  _IsolateData({
    required this.token,
    required this.function,
    required this.answerPort,
  });
}
