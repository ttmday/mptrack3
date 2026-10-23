import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/constants/extensions.dart';
import 'package:mptrack3/src/provider/player.dart';
import 'package:provider/provider.dart';

class _ProgressTrackShape extends SliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool? isEnabled,
    bool? isDiscrete,
  }) {
    return Rect.fromLTWH(
      0,
      0,
      parentBox.size.width,
      parentBox.size.height,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool? isEnabled,
    bool? isDiscrete,
    required TextDirection textDirection,
  }) {
    final paint = Paint();
    paint.color = AppColors.primary.withValues(alpha: .055);
    final canvas = context.canvas;
    final top = parentBox.size.height * 0.5 - 2;
    const double rcircular = .8;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          0,
          top,
          parentBox.size.width,
          8,
        ),
        const Radius.circular(rcircular),
      ),
      paint,
    );

    paint.color = AppColors.accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          0,
          top,
          thumbCenter.dx,
          8,
        ),
        const Radius.circular(rcircular),
      ),
      paint,
    );
  }
}

class TrackProgress extends StatefulWidget {
  const TrackProgress({super.key, this.compact = true});

  /// Smaller labels for the home header.
  final bool compact;

  @override
  State<TrackProgress> createState() => _TrackProgressState();
}

class _TrackProgressState extends State<TrackProgress> {
  /// Value while the user drags, so the thumb does not jump back.
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final labelStyle = AppDesign.textTheme(context)
        .bodySmall!
        .copyWith(fontSize: widget.compact ? 10.0 : 12.0);
    return ValueListenableBuilder<ProgressState>(
      valueListenable: player.progress,
      builder: (context, progress, _) {
        final max = progress.duration.inMilliseconds.toDouble();
        final current = _dragValue ??
            min(max, progress.position.inMilliseconds.toDouble());
        final shown = Duration(milliseconds: current.toInt());
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackShape: _ProgressTrackShape(),
                  thumbShape: SliderComponentShape.noOverlay,
                  overlayShape: SliderComponentShape.noOverlay,
                  allowedInteraction: SliderInteraction.tapAndSlide,
                  trackHeight: 16.0,
                ),
                child: Slider(
                  min: 0.0,
                  max: max <= 0 ? 1.0 : max,
                  value: max <= 0 ? 0.0 : current.clamp(0.0, max),
                  onChanged: max <= 0
                      ? null
                      : (value) => setState(() => _dragValue = value),
                  onChangeEnd: (value) {
                    player.seek(Duration(milliseconds: value.toInt()));
                    setState(() => _dragValue = null);
                  },
                ),
              ),
            ),
            const SizedBox(height: AppDesign.padding),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.headphones, size: 14.0),
                    const SizedBox(width: AppDesign.padding * .35),
                    Text(shown.formatStr, style: labelStyle),
                  ],
                ),
                Text(progress.duration.formatStr, style: labelStyle),
              ],
            ),
          ],
        );
      },
    );
  }
}
