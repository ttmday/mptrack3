import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/constants/extensions.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/provider/player.dart';
import 'package:mptrack3/src/service/library/models/index.dart';

/// Songs that play after the current one.
///
/// When the queue changes (a song was tapped or the next one started) the
/// list waits a moment so the tap is seen, then shows the new order and
/// scrolls back to the top, where the next song is.
class UpNextList extends StatefulWidget {
  const UpNextList({super.key});

  @override
  State<UpNextList> createState() => _UpNextListState();
}

class _UpNextListState extends State<UpNextList> {
  static const _refreshDelay = Duration(milliseconds: 320);
  static const _limit = 30;

  late final PlayerProvider _player;
  final _controller = ScrollController();
  late List<Track> _upcoming;
  Timer? _pending;

  @override
  void initState() {
    super.initState();
    _player = context.read<PlayerProvider>();
    _upcoming = _player.upcoming(limit: _limit);
    _player.queueVersion.addListener(_onQueueChanged);
  }

  void _onQueueChanged() {
    _pending?.cancel();
    _pending = Timer(_refreshDelay, () {
      if (!mounted) return;
      setState(() => _upcoming = _player.upcoming(limit: _limit));
      if (_controller.hasClients) {
        _controller.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  void dispose() {
    _player.queueVersion.removeListener(_onQueueChanged);
    _pending?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _play(Track track) {
    final queueIndex = _player.queue.indexWhere((t) => t.id == track.id);
    if (queueIndex >= 0) _player.playQueueIndex(queueIndex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppDesign.textTheme(context);
    final muted = theme.bodySmall!.copyWith(color: AppColors.foreground);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${Strings.upNext} (${_upcoming.length})', style: muted),
        const Divider(color: AppColors.border, height: 12),
        Expanded(
          child: _upcoming.isEmpty
              ? Center(child: Text(Strings.queueEmpty, style: muted))
              : ListView.builder(
                  controller: _controller,
                  padding: EdgeInsets.zero,
                  itemCount: _upcoming.length,
                  itemBuilder: (context, index) {
                    final track = _upcoming[index];
                    return InkWell(
                      onTap: () => _play(track),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            SizedBox(width: 28, child: Text('${index + 1}', style: muted)),
                            Expanded(
                              child: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.bodyMedium!.copyWith(color: AppColors.accent),
                              ),
                            ),
                            Text(
                              track.duration == Duration.zero ? '' : track.duration.formatStr,
                              style: theme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
