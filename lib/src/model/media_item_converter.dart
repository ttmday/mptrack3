import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:on_audio_query/on_audio_query.dart';

final audioQuery = OnAudioQuery();

extension MediaItemConverter on SongModel {
  MediaItem toMediaItem(
      {bool addedByAutoplay = false,
      bool autoplay = true,
      String? playlistBox}) {
    final song = this;
    return MediaItem(
      id: song.id.toString(),
      album: song.album ?? "",
      artist: song.artist ?? "",
      duration: Duration(milliseconds: song.duration ?? 0),
      title: song.title,
      artUri: Uri(),
      genre: song.genre ?? "",
      extras: {
        'uri': Uri.tryParse(song.uri ?? ""),
        'artist_id': song.artistId,
        'album_id': song.albumId,
        // 'genre_id': int.tryParse(song.genreId?.toString() ?? '-1'),
        'addedByAutoplay': addedByAutoplay,
        'autoplay': autoplay,
        'playlistBox': playlistBox,
      },
    );
  }
}

extension MediaItemExtension on MediaItem {
  Future<Uint8List?> getImage() async {
    return await audioQuery.queryArtwork(
        int.tryParse(id) ?? -1, ArtworkType.AUDIO);
  }
}
