import 'package:audio_service/audio_service.dart';
import 'package:mptrack3/src/util/text_normalize.dart';

/// A playable audio file in the library.
///
/// [volume] identifies the storage volume (e.g. "external_primary" on
/// Android, "documents" on iOS) and [folder] is the directory relative to
/// that volume root without leading/trailing slashes (e.g. "Music/Rock").
class Track {
  Track({
    required this.id,
    required this.uri,
    required this.volume,
    required this.folder,
    required this.fileName,
    required this.title,
    this.artist,
    this.album,
    this.duration = Duration.zero,
    this.dateAdded = 0,
    this.size = 0,
    this.filePath,
  });

  /// Stable identifier (MediaStore id on Android, relative path on iOS).
  final String id;

  /// Uri used for playback (content:// on Android, file:// on iOS).
  final String uri;
  final String volume;
  final String folder;
  final String fileName;
  final String title;
  final String? artist;
  final String? album;
  final Duration duration;

  /// Seconds since epoch.
  final int dateAdded;
  final int size;

  /// Absolute path on disk when known.
  final String? filePath;

  late final String searchText = normalizeText(
      '$title ${artist ?? ''} ${album ?? ''} $folder $fileName');
  late final String normalizedTitle = normalizeText(title);
  late final String normalizedFileName = normalizeText(fileNameWithoutExtension);

  String get fileNameWithoutExtension {
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }

  String get folderName {
    final slash = folder.lastIndexOf('/');
    return slash >= 0 ? folder.substring(slash + 1) : folder;
  }

  String get displayArtist =>
      (artist == null || artist!.isEmpty || artist == '<unknown>')
          ? ''
          : artist!;

  Track copyWith({
    String? id,
    String? uri,
    String? folder,
    String? filePath,
    Duration? duration,
  }) {
    return Track(
      id: id ?? this.id,
      uri: uri ?? this.uri,
      volume: volume,
      folder: folder ?? this.folder,
      fileName: fileName,
      title: title,
      artist: artist,
      album: album,
      duration: duration ?? this.duration,
      dateAdded: dateAdded,
      size: size,
      filePath: filePath ?? this.filePath,
    );
  }

  MediaItem toMediaItem({Uri? artUri}) {
    return MediaItem(
      id: id,
      title: title,
      artist: displayArtist.isEmpty ? null : displayArtist,
      album: folderName.isEmpty ? album : folderName,
      duration: duration == Duration.zero ? null : duration,
      artUri: artUri,
      extras: {'uri': uri, 'folder': folder},
    );
  }

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Track($id, $folder/$fileName)';
}
