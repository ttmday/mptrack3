import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/library/library_repository.dart';
import 'package:mptrack3/src/model/track.dart';

/// Album art for [track], with a retro placeholder when there is none.
class CoverAlbum extends StatefulWidget {
  const CoverAlbum({super.key, required this.track, this.size = 256});

  final Track? track;

  /// Requested pixel size of the artwork.
  final int size;

  @override
  State<CoverAlbum> createState() => _CoverAlbumState();
}

class _CoverAlbumState extends State<CoverAlbum> {
  Future<Uint8List?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  void didUpdateWidget(covariant CoverAlbum oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track?.id != widget.track?.id) _future = _load();
  }

  Future<Uint8List?>? _load() {
    final track = widget.track;
    if (track == null) return null;
    return context.read<LibraryRepository>().artwork(track, size: widget.size);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: bytes != null
              ? Image.memory(
                  bytes,
                  key: ValueKey(widget.track?.id),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              : const _Placeholder(key: ValueKey('placeholder')),
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final side = constraints.biggest.shortestSide;
      return Container(
        color: AppColors.secondary.withValues(alpha: .35),
        alignment: Alignment.center,
        child: Text(
          '[♪]',
          style: TextStyle(
            fontFamily: 'Jersey10',
            fontSize: side.isFinite ? side * .32 : 32,
            color: AppColors.accent.withValues(alpha: .7),
          ),
        ),
      );
    });
  }
}
