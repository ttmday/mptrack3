import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:audio_service/audio_service.dart';
import 'package:mptrack3/src/service/audio_manager.dart';

import 'package:mptrack3/src/widget/jersey_message.dart';
import 'package:mptrack3/src/widget/song_tile.dart';

class SongList extends StatelessWidget {
  const SongList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioManager>(builder: (context, provider, _) {
      return ValueListenableBuilder(
        valueListenable: provider.managerNotifier,
        builder: (context, managerState, child) {
          if (managerState == ManagerState.loading) {
            return const JerseyMessage(
              message: "Cargando...",
            );
          }

          if (managerState == ManagerState.error) {
            return const JerseyMessage();
          }

          return child!;
        },
        child: ValueListenableBuilder(
            valueListenable: provider.playlistNotifier,
            builder: (context, playlist, _) {
              if (playlist.isEmpty) {
                return const JerseyMessage(
                  message: '404',
                );
              }
              return ListView.builder(
                  itemCount: playlist.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    MediaItem song = playlist[index];
                    return SongTile(
                        manager: provider, position: index, song: song);
                  });
            }),
      );
    });
  }
}
