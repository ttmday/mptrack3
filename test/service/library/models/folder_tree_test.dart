import 'package:flutter_test/flutter_test.dart';
import 'package:mptrack3/src/service/library/models/folder_tree.dart';

import '../../../helpers/test_tracks.dart';

void main() {
  final tracks = [
    makeTrack('1', folder: 'Music/Rock'),
    makeTrack('2', folder: 'Music/Rock/Live'),
    makeTrack('3', folder: 'Music/Baladas'),
    makeTrack('4', folder: 'Download'),
  ];

  test('builds nested folders with recursive counts', () {
    final tree = FolderTree.build(tracks);
    final home = tree.home;
    expect(home.isVolume, isTrue);
    expect(home.children.map((c) => c.name), ['Download', 'Music']);
    final music = tree.find(const FolderRef('external_primary', 'Music'))!;
    expect(music.totalTracks, 3);
    expect(music.children.map((c) => c.name), ['Baladas', 'Rock']);
    expect(tree.displayPath(music), '~/Music');
  });

  test('keeps empty extra folders', () {
    final tree = FolderTree.build(tracks,
        extraFolders: const [FolderRef('external_primary', 'Music/Salsa')]);
    expect(tree.find(const FolderRef('external_primary', 'Music/Salsa')), isNotNull);
  });

  test('resolves shell paths with accents and prefixes', () {
    final tree = FolderTree.build([
      ...tracks,
      makeTrack('5', folder: 'Música/Clásica'),
    ]);
    final home = tree.home;
    final rock = tree.resolve(home, 'music/rock')!;
    expect(rock.path, 'Music/Rock');
    expect(tree.resolve(rock, '..')!.path, 'Music');
    expect(tree.resolve(rock, '~')!.path, '');
    expect(tree.resolve(home, 'musica/clasica')!.path, 'Música/Clásica');
    expect(tree.resolve(home, 'Down')!.path, 'Download');
    expect(tree.resolve(home, 'nope'), isNull);
  });

  test('multiple volumes start at the virtual root', () {
    final tree = FolderTree.build([
      ...tracks,
      makeTrack('9', folder: 'Music', volume: 'sdcard'),
    ], volumeLabels: const {'external_primary': 'Interno', 'sdcard': 'SD'});
    expect(tree.home.isRoot, isTrue);
    expect(tree.volumes.map((v) => v.name), ['Interno', 'SD']);
    final sdMusic = tree.resolve(tree.root, '/SD/Music')!;
    expect(tree.displayPath(sdMusic), '/SD/Music');
  });
}
