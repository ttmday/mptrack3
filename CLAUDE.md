# Mptrack3

Retro terminal-style local music player (bright green on black) for Android
and iOS. The library is browsed as a folder tree and driven from a command
prompt (`mptrack3:~/Music$`) that also works as search.

Follows the `flutter-app-conventions` skill.

## Commands
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter run`
- `flutter build appbundle --release`  (Play Store)

## Services
- `service/library/` — audio files: `AndroidMediaSource` (MediaStore through
  `MediaStoreBridge.kt`) and `IosMediaSource` (app Documents folder, tags via
  `AppDelegate.swift`). Folder tree and search live here too.
- `service/player/` — `PlayerService` (audio_service + just_audio, one source
  per track) and `PlayOrder` (shuffle cycle and history).
- `service/terminal/` — command parser.

## Providers
- `provider/library.dart` — library status, tracks, tree, hidden/virtual
  folders, file operations.
- `provider/player.dart` — playback state, queue sync with the library,
  session restore, sleep timer.
- `provider/browser.dart` — current folder, search, sort.
- `provider/terminal.dart` — runs commands; asks the view for dialogs through
  `TerminalEvent`s.

## Platform notes
- Android permissions: `READ_MEDIA_AUDIO` (13+), `READ_EXTERNAL_STORAGE`
  (max 32), `WRITE_EXTERNAL_STORAGE` (max 29, legacy writes). Writes on 11+ go
  through `createDeleteRequest` / `createWriteRequest`; music can only live
  under `Music/`, `Podcasts/`, `Audiobooks/`... `targetSdk` 35.
- iOS Info.plist: `UIBackgroundModes: audio`, `UIFileSharingEnabled`,
  `LSSupportsOpeningDocumentsInPlace`.

## Exceptions to the conventions
- `PlayerService` extends audio_service's `BaseAudioHandler` and exposes
  rxdart subjects instead of returning `Either`; playback errors are handled
  inside it (skip to the next track).
- Terminal output is English on purpose (shell style); menus are Spanish.
