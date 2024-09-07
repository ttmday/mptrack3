// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mptrack3/main.dart';
import 'package:mptrack3/src/service/audio_handler.dart';
import 'package:mptrack3/src/service/audio_manager.dart';
import 'package:mptrack3/src/service/audio_query_request.dart';
import 'package:mptrack3/src/service/player_invoke.dart';
import 'package:on_audio_query/on_audio_query.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.

    MyAudioHandler audioHandler = await initAudioService();
    final audioQR = AudioQueryRequest();
    final List<SongModel> songs = [];
    if (await audioQR.checkAndRequestPermissions()) {
      songs.addAll(await audioQR.getSongs());
    }

    AudioManager audioManager = AudioManager(audioHandler);
    PlayerInvoke playerInvoke = PlayerInvoke(audioManager, audioQR);
    await playerInvoke.init(songsList: songs, index: 0);
    await tester.pumpWidget(MyApp(
      audioManager: audioManager,
      playerInvoke: playerInvoke,
    ));

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
