import 'package:mptrack3/src/service/library/models/track.dart';

Track makeTrack(
  String id, {
  String folder = 'Music',
  String? title,
  String? artist,
  String volume = 'external_primary',
  int dateAdded = 0,
}) {
  return Track(
    id: id,
    uri: 'content://media/external/audio/media/$id',
    volume: volume,
    folder: folder,
    fileName: '${title ?? id}.mp3',
    title: title ?? id,
    artist: artist,
    dateAdded: dateAdded,
  );
}
