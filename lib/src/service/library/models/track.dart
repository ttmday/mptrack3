import 'package:audio_service/audio_service.dart';
import 'package:equatable/equatable.dart';

import 'package:mptrack3/src/utils/text.dart';

/// A playable audio file.
///
/// [volume] identifies the storage ("external_primary" on Android,
/// "documents" on iOS) and [folder] is the directory relative to that
/// volume without leading or trailing slashes, e.g. "Music/Rock".
class Track extends Equatable {
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

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String? ?? '',
        uri: json['uri'] as String? ?? '',
        volume: json['volume'] as String? ?? '',
        folder: json['folder'] as String? ?? '',
        fileName: json['fileName'] as String? ?? '',
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String?,
        album: json['album'] as String?,
        duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
        dateAdded: json['dateAdded'] as int? ?? 0,
        size: json['size'] as int? ?? 0,
        filePath: json['filePath'] as String?,
      );

  /// MediaStore id on Android, path relative to Documents on iOS.
  final String id;

  /// content:// on Android, file:// on iOS.
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
  final String? filePath;

  late final String searchText =
      normalizeText('$title ${artist ?? ''} ${album ?? ''} $folder $fileName');
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

  /// Artist without MediaStore's "<unknown>" placeholder.
  String get displayArtist =>
      (artist == null || artist!.isEmpty || artist == '<unknown>') ? '' : artist!;

  Track copyWith({
    String? id,
    String? uri,
    String? folder,
    String? filePath,
    Duration? duration,
  }) =>
      Track(
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'uri': uri,
        'volume': volume,
        'folder': folder,
        'fileName': fileName,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': duration.inMilliseconds,
        'dateAdded': dateAdded,
        'size': size,
        'filePath': filePath,
      };

  MediaItem toMediaItem({Uri? artUri}) => MediaItem(
        id: id,
        title: title,
        artist: displayArtist.isEmpty ? null : displayArtist,
        album: folderName.isEmpty ? album : folderName,
        duration: duration == Duration.zero ? null : duration,
        artUri: artUri,
        extras: {'uri': uri, 'folder': folder},
      );

  @override
  List<Object?> get props => [
        id,
        uri,
        volume,
        folder,
        fileName,
        title,
        artist,
        album,
        duration,
        dateAdded,
        size,
        filePath,
      ];

  @override
  bool? get stringify => true;
}
