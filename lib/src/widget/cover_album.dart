import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mptrack3/src/model/media_item_converter.dart';

class CoverAlbum extends StatelessWidget {
  const CoverAlbum({super.key, required this.song});

  final MediaItem? song;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: song?.getImage(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              height: double.infinity,
              fit: BoxFit.cover,
            );
          }
          return const Text(
            '(Cover album here)',
            textAlign: TextAlign.center,
          );
        });
  }
}
