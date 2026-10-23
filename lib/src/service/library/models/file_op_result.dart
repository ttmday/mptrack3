import 'package:equatable/equatable.dart';

/// Outcome of a delete or move that may partially succeed.
class FileOpResult extends Equatable {
  const FileOpResult({
    this.succeeded = const [],
    this.failed = const {},
    this.cancelled = false,
    this.renamed = const {},
  });

  final List<String> succeeded;

  /// Track id -> reason.
  final Map<String, String> failed;

  /// The user dismissed the system confirmation dialog.
  final bool cancelled;

  /// Old id -> new id, on platforms where moving changes the id (iOS).
  final Map<String, String> renamed;

  bool get ok => !cancelled && failed.isEmpty;

  FileOpResult copyWith({
    List<String>? succeeded,
    Map<String, String>? failed,
    bool? cancelled,
    Map<String, String>? renamed,
  }) =>
      FileOpResult(
        succeeded: succeeded ?? this.succeeded,
        failed: failed ?? this.failed,
        cancelled: cancelled ?? this.cancelled,
        renamed: renamed ?? this.renamed,
      );

  @override
  List<Object?> get props => [succeeded, failed, cancelled, renamed];

  @override
  bool? get stringify => true;
}
