import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/constants/extensions.dart';
import 'package:mptrack3/src/service/audio_manager.dart';
import 'package:provider/provider.dart';

class MyTrackShape extends SliderTrackShape {
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
    paint.color = AppColors.primary.withOpacity(.055);
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

class TrackProgress extends StatelessWidget {
  const TrackProgress({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Size q = MediaQuery.sizeOf(context);
    return Consumer<AudioManager>(builder: (context, provider, _) {
      return ValueListenableBuilder(
          valueListenable: provider.progressNotifier,
          builder: (context, progress, _) {
            final duration = progress.total;
            final position = progress.current;

            return Column(
              children: [
                SizedBox(
                  width: q.width,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackShape: MyTrackShape(),
                      thumbShape: SliderComponentShape.noThumb,
                      overlayShape: SliderComponentShape.noOverlay,
                      allowedInteraction: SliderInteraction.tapAndSlide,
                      trackHeight: 2.5,
                    ),
                    child: Slider(
                      min: 0.0,
                      max: duration.inMilliseconds.toDouble(),
                      value: min(duration.inMilliseconds.toDouble(),
                          position.inMilliseconds.toDouble()),
                      onChanged: (double value) {
                        provider.seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  ),
                ),
                const SizedBox(
                  height: AppDesign.padding,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.headphones,
                          size: 14.0,
                        ),
                        const SizedBox(
                          width: AppDesign.padding * .35,
                        ),
                        Text(
                          position.formatStr,
                          style: AppDesign.textTheme(context)
                              .bodySmall!
                              .copyWith(fontSize: 10.0),
                        ),
                      ],
                    ),
                    Text(
                      duration.formatStr,
                      style: AppDesign.textTheme(context)
                          .bodySmall!
                          .copyWith(fontSize: 10.0),
                    ),
                  ],
                )
              ],
            );
          });
    });
  }
}
