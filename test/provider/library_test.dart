import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right, Unit, unit;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mptrack3/src/provider/library.dart';
import 'package:mptrack3/src/service/library/api/errors_const.dart';
import 'package:mptrack3/src/service/library/api/library_error.dart';
import 'package:mptrack3/src/service/library/media_source.dart';
import 'package:mptrack3/src/service/library/models/index.dart';

import '../helpers/test_tracks.dart';

class FakeMediaSource implements MediaSource {
  List<Track> tracks = [];
  Either<LibraryError, FileOpResult>? deleteResult;
  final _changes = StreamController<void>.broadcast();

  @override
  Future<PermissionStatus> requestPermission() async => PermissionStatus.granted;

  @override
  Future<Either<LibraryError, LibrarySnapshot>> load() async =>
      Right(LibrarySnapshot(tracks: List.of(tracks)));

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Uint8List?> artwork(Track track, {int size = 512}) async => null;

  @override
  bool get systemConfirmsWrites => true;

  @override
  String? writeRestriction(FolderRef target) =>
      target.path.startsWith('Music') ? null : 'only Music/';

  @override
  Future<Either<LibraryError, Unit>> createFolder(FolderRef folder) async =>
      const Right(unit);

  @override
  Future<Either<LibraryError, Unit>> removeEmptyFolder(FolderRef folder) async =>
      const Right(unit);

  @override
  Future<Either<LibraryError, FileOpResult>> delete(List<Track> tracks) async =>
      deleteResult ?? Right(FileOpResult(succeeded: tracks.map((t) => t.id).toList()));

  @override
  Future<Either<LibraryError, FileOpResult>> move(
          List<Track> tracks, FolderRef target) async =>
      Right(FileOpResult(succeeded: tracks.map((t) => t.id).toList()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMediaSource source;
  late LibraryProvider library;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    source = FakeMediaSource()
      ..tracks = [
        makeTrack('1', folder: 'Music/Rock'),
        makeTrack('2', folder: 'Music'),
      ];
    library = LibraryProvider(await SharedPreferences.getInstance(), source: source);
    await library.init();
  });

  test('loads the library and builds the tree', () {
    expect(library.status, LibraryStatus.ready);
    expect(library.tracks.length, 2);
    expect(library.tree.home.totalTracks, 2);
  });

  test('reload reports new and removed tracks', () async {
    source.tracks = [makeTrack('2', folder: 'Music'), makeTrack('3', folder: 'Music')];
    final diff = await library.reload();
    expect(diff.added.map((t) => t.id), ['3']);
    expect(diff.removedIds, {'1'});
  });

  test('created folders appear even without tracks', () async {
    final music = library.tree.find(const FolderRef('external_primary', 'Music'))!;
    expect(await library.createFolder(music, 'Salsa'), isNull);
    expect(library.tree.find(const FolderRef('external_primary', 'Music/Salsa')), isNotNull);
  });

  test('folders outside allowed places are rejected', () async {
    expect(await library.createFolder(library.tree.home, 'Salsa'), 'only Music/');
  });

  test('a failed delete keeps the tracks and reports every one', () async {
    source.deleteResult =
        const Left(LibraryError(code: LibraryErrors.platform, message: 'denied'));
    final result = await library.deleteTracks(library.tracks);
    expect(result.failed.length, 2);
    expect(library.tracks.length, 2);
  });
}
