import 'dart:async';

import 'package:equatable/equatable.dart';

enum LineKind { input, info, success, error }

class TerminalLine extends Equatable {
  const TerminalLine(this.text, this.kind);

  final String text;
  final LineKind kind;

  @override
  List<Object?> get props => [text, kind];
}

/// One-shot requests from the terminal that only the view can fulfil.
sealed class TerminalEvent {
  const TerminalEvent();
}

final class ShowHelpEvent extends TerminalEvent {
  const ShowHelpEvent();
}

final class OpenNowPlayingEvent extends TerminalEvent {
  const OpenNowPlayingEvent();
}

/// Asks the view for a yes/no confirmation; the view must call [answer].
final class ConfirmEvent extends TerminalEvent {
  ConfirmEvent(this.message);

  final String message;
  final _completer = Completer<bool>();

  Future<bool> get result => _completer.future;

  void answer(bool confirmed) {
    if (!_completer.isCompleted) _completer.complete(confirmed);
  }
}
