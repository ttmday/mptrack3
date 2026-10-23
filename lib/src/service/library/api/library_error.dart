import 'package:equatable/equatable.dart';

class LibraryError extends Equatable {
  const LibraryError({required this.code, this.message});

  /// A code from `LibraryErrors`.
  final String code;
  final String? message;

  @override
  List<Object?> get props => [code, message];

  @override
  bool? get stringify => true;
}
