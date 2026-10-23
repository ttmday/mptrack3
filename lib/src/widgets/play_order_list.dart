import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mptrack3/src/service/library/models/index.dart';

/// Track list that follows the play order and scrolls to the song the user
/// just tapped.
///
/// In shuffle mode tapping a song reorders the queue so that song becomes
/// the first track. The new order is applied after a short delay (so the
/// tap feedback is seen in place) and, if the change came from a tap in
/// this list, the list then scrolls to the first track so the tapped song
/// stays in view. Reorders not caused by a tap (the next song starting)
/// keep the user's scroll position. Rows must share the same [itemExtent].
class PlayOrderList extends StatefulWidget {
  const PlayOrderList({
    super.key,
    required this.tracks,
    required this.trackBuilder,
    required this.itemExtent,
    this.leading = const [],
  });

  final List<Track> tracks;
  final Widget Function(BuildContext context, Track track) trackBuilder;
  final double itemExtent;

  /// Rows shown before the tracks (folders, ".."), same height as tracks.
  final List<Widget> leading;

  @override
  State<PlayOrderList> createState() => _PlayOrderListState();
}

class _PlayOrderListState extends State<PlayOrderList> {
  static const _reorderDelay = Duration(milliseconds: 300);
  static const _tapWindow = Duration(seconds: 2);
  static const _scrollDuration = Duration(milliseconds: 350);

  final _controller = ScrollController();
  late List<Track> _shown = widget.tracks;
  Timer? _pending;
  DateTime? _lastTap;

  @override
  void didUpdateWidget(covariant PlayOrderList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.tracks;
    if (_sameOrder(_shown, next)) {
      _shown = next;
    } else if (_sameIds(_shown, next)) {
      _pending?.cancel();
      _pending = Timer(_reorderDelay, _applyReorder);
    } else {
      _pending?.cancel();
      _shown = next;
    }
  }

  void _applyReorder() {
    if (!mounted) return;
    setState(() => _shown = widget.tracks);
    final tap = _lastTap;
    _lastTap = null;
    if (tap == null || DateTime.now().difference(tap) > _tapWindow) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      final position = _controller.position;
      final firstTrack = widget.leading.length * widget.itemExtent;
      _controller.animateTo(
        firstTrack.clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: _scrollDuration,
        curve: Curves.easeOutCubic,
      );
    });
  }

  static bool _sameOrder(List<Track> a, List<Track> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  static bool _sameIds(List<Track> a, List<Track> b) {
    if (a.length != b.length) return false;
    final ids = a.map((t) => t.id).toSet();
    return b.every((t) => ids.contains(t.id));
  }

  @override
  void dispose() {
    _pending?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leading = widget.leading;
    return ListView.builder(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemExtent: widget.itemExtent,
      itemCount: leading.length + _shown.length,
      itemBuilder: (context, index) {
        if (index < leading.length) return leading[index];
        return Listener(
          onPointerUp: (_) => _lastTap = DateTime.now(),
          child: widget.trackBuilder(context, _shown[index - leading.length]),
        );
      },
    );
  }
}
