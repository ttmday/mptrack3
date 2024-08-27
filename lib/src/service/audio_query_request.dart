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
    return _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );
  }
}
