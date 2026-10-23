import 'package:equatable/equatable.dart';

enum PlayState { stopped, paused, loading, playing }

class ProgressState extends Equatable {
  const ProgressState(this.position, this.duration);

  static const zero = ProgressState(Duration.zero, Duration.zero);

  final Duration position;
  final Duration duration;

  @override
  List<Object?> get props => [position, duration];
}
