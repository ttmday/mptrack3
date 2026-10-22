import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mptrack3/src/browser/browser_controller.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/library/library_repository.dart';
import 'package:mptrack3/src/library/media_source.dart';
import 'package:mptrack3/src/library/track_search.dart';
import 'package:mptrack3/src/model/folder_tree.dart';
import 'package:mptrack3/src/model/track.dart';
import 'package:mptrack3/src/player/play_order.dart';
import 'package:mptrack3/src/player/player_controller.dart';
import 'package:mptrack3/src/terminal/command_parser.dart';

enum LineKind { input, info, success, error }

class TerminalLine {
  const TerminalLine(this.text, this.kind);
  final String text;
  final LineKind kind;
}

/// UI hooks the terminal needs (dialogs, navigation).
abstract class TerminalHost {
  Future<bool> confirm(String message);
  void openNowPlaying();
  void showHelp();
}

/// Executes prompt input and keeps a short output log.
class TerminalController extends ChangeNotifier {
  TerminalController({
    required this.library,
    required this.browser,
    required this.player,
  }) {
    _diffSub = library.diffs.listen(_onLibraryDiff);
  }

  final LibraryRepository library;
  final BrowserController browser;
  final PlayerController player;
  TerminalHost? host;

  static const _maxLines = 60;
  final List<TerminalLine> _lines = [];
  final List<String> _history = [];
  StreamSubscription<LibraryDiff>? _diffSub;

  /// Index where the output of the last command starts.
  int _blockStart = 0;

  /// Text the prompt should take (e.g. tapping a command in the help).
  final suggestion = ValueNotifier<String?>(null);

  List<TerminalLine> get lines => List.unmodifiable(_lines);

  /// Number of lines printed since the last command was typed.
  int get lastBlockLength => _lines.length - _blockStart;
  List<String> get history => List.unmodifiable(_history);

  void echo(String text, [LineKind kind = LineKind.info]) {
    for (final line in text.split('\n')) {
      _lines.add(TerminalLine(line, kind));
    }
    if (_lines.length > _maxLines) {
      final removed = _lines.length - _maxLines;
      _lines.removeRange(0, removed);
      _blockStart = (_blockStart - removed).clamp(0, _lines.length);
    }
    notifyListeners();
  }

  /// Puts [text] in the prompt, ready to be completed and sent.
  void suggest(String text) {
    suggestion.value = null;
    suggestion.value = text;
  }

  void error(String text) => echo(text, LineKind.error);
  void success(String text) => echo(text, LineKind.success);

  void clear() {
    _lines.clear();
    _blockStart = 0;
    notifyListeners();
  }

  /// Called on every keystroke: plain text filters the list live.
  void onTyping(String text) {
    final parsed = parseInput(text);
    if (parsed is SearchInput) {
      browser.setQuery(parsed.query);
    } else if (parsed is CommandInput && parsed.name == CommandName.find) {
      browser.setQuery(parsed.rest);
    } else {
      browser.clearQuery();
    }
  }

  /// Called on enter. Returns true when the prompt should be cleared.
  Future<bool> submit(String text) async {
    final parsed = parseInput(text);
    if (parsed is SearchInput) {
      final results = browser.results;
      if (results.isEmpty) {
        error('find: no match for "${parsed.query}"');
        return false;
      }
      await player.playTracks(results, label: 'find: ${parsed.query}');
      return false;
    }
    if (parsed is! CommandInput) return true;
    _history.add(text.trim());
    _blockStart = _lines.length;
    echo('\$ ${text.trim()}', LineKind.input);
    try {
      await _run(parsed);
    } catch (e) {
      error('${parsed.name.name}: $e');
    }
    return parsed.name != CommandName.find;
  }

  Future<void> _run(CommandInput cmd) async {
    switch (cmd.name) {
      case CommandName.help:
        if (host == null) {
          echo('commands: menu cd ls play pause next prev shuffle repeat '
              'find mkdir mv rm rmdir sleep sort hide unhide refresh clear np');
        } else {
          host!.showHelp();
          echo('help: tap a command to use it');
        }
      case CommandName.menu:
        browser.clearQuery();
        browser.enter(browser.tree.home);
      case CommandName.clear:
        clear();
      case CommandName.pwd:
        echo(browser.cwdLabel);
      case CommandName.ls:
        _ls(cmd);
      case CommandName.cd:
        _cd(cmd);
      case CommandName.play:
        await _play(cmd);
      case CommandName.pause:
        await player.pause();
      case CommandName.stop:
        await player.stop();
      case CommandName.next:
        await player.next();
      case CommandName.prev:
        await player.previous();
      case CommandName.shuffle:
        await _shuffle(cmd);
      case CommandName.repeat:
        await _repeat(cmd);
      case CommandName.find:
        browser.setQuery(cmd.rest);
        echo('find: ${browser.results.length} match(es)');
      case CommandName.mkdir:
        await _mkdir(cmd);
      case CommandName.mv:
        await _mv(cmd);
      case CommandName.rm:
        await _rm(cmd);
      case CommandName.rmdir:
        await _rmdir(cmd);
      case CommandName.sleep:
        _sleep(cmd);
      case CommandName.refresh:
        echo('scanning...');
        final diff = await library.reload();
        success('library: ${library.tracks.length} tracks '
            '(+${diff.added.length} / -${diff.removedIds.length})');
      case CommandName.hide:
        await _hide(cmd);
      case CommandName.unhide:
        await _unhide(cmd);
      case CommandName.sort:
        _sort(cmd);
      case CommandName.np:
        host?.openNowPlaying();
    }
  }

  // ---------------------------------------------------------------------

  FolderNode? _folderArg(String arg) => browser.tree.resolve(browser.cwd, arg);

  void _ls(CommandInput cmd) {
    final folder = cmd.args.isEmpty ? browser.cwd : _folderArg(cmd.rest);
    if (folder == null) {
      error('ls: ${cmd.rest}: no such folder');
      return;
    }
    final children = folder.children;
    final tracks = browser.tracksOf(folder);
    final out = <String>[
      for (final c in children.take(12)) '${c.name}/  (${c.totalTracks})',
      if (children.length > 12) '... ${children.length - 12} more folders',
      for (final t in tracks.take(8)) t.title,
      if (tracks.length > 8) '... ${tracks.length - 8} more tracks',
    ];
    echo(out.isEmpty ? '(empty)' : out.join('\n'));
  }

  void _cd(CommandInput cmd) {
    if (cmd.args.isEmpty) {
      browser.enter(browser.tree.home);
      return;
    }
    if (cmd.rest == '-') {
      browser.back();
      return;
    }
    final folder = _folderArg(cmd.rest);
    if (folder == null) {
      error('cd: ${cmd.rest}: no such folder');
      return;
    }
    browser.clearQuery();
    browser.enter(folder);
  }

  Future<void> _play(CommandInput cmd) async {
    final shuffled = cmd.flags.contains('s');
    if (cmd.args.isEmpty) {
      if (!shuffled && player.queue.isNotEmpty) {
        await player.play();
        return;
      }
      await playFolder(browser.cwd, shuffled);
      return;
    }
    final folder = _folderArg(cmd.rest);
    if (folder != null && folder.totalTracks > 0) {
      await playFolder(folder, shuffled);
      return;
    }
    final match = _findTrack(cmd.rest, 'play');
    if (match == null) return;
    final node = browser.tree.find(FolderRef(match.volume, match.folder));
    final tracks = node == null ? [match] : browser.tracksOf(node);
    await player.playFrom(tracks, match,
        label: node == null ? '' : browser.tree.displayPath(node),
        context: node?.ref);
  }

  Future<void> playFolder(FolderNode folder, bool shuffled) async {
    final label = browser.tree.displayPath(folder);
    final ok = await player.playFolder(folder, browser.playlistOf(folder), label,
        shuffled: shuffled);
    if (!ok) {
      error('play: $label has no tracks');
    } else {
      success('playing $label${shuffled ? ' (shuffle)' : ''}');
    }
  }

  Future<void> _shuffle(CommandInput cmd) async {
    final arg = cmd.rest.toLowerCase();
    final value = switch (arg) {
      'on' => true,
      'off' => false,
      '' => !player.shuffle.value,
      _ => null,
    };
    if (value == null) {
      error('shuffle: use on | off');
      return;
    }
    await player.setShuffle(value);
    echo('shuffle: ${value ? 'on' : 'off'}');
  }

  Future<void> _repeat(CommandInput cmd) async {
    final arg = cmd.rest.toLowerCase();
    if (arg.isEmpty) {
      await player.cycleRepeat();
    } else {
      final mode = RepeatMode.values.where((m) => m.name == arg).firstOrNull;
      if (mode == null) {
        error('repeat: use off | one | all');
        return;
      }
      await player.setRepeat(mode);
    }
    echo('repeat: ${player.repeat.value.name}');
  }

  Future<void> _mkdir(CommandInput cmd) async {
    if (cmd.args.isEmpty) {
      error('mkdir: missing folder name');
      return;
    }
    await createFolder(browser.cwd, cmd.rest);
  }

  /// Returns the created folder node, or null on error.
  ///
  /// When the platform does not allow music folders in [parent] (Android
  /// 11+ outside Music/), the folder is created inside Music/ instead.
  Future<FolderNode?> createFolder(FolderNode parent, String name) async {
    parent = await _writableParent(parent, name.trim());
    final parentRef = parent.ref;
    final message = await library.createFolder(parent, name);
    if (message != null) {
      error('mkdir: $message');
      return null;
    }
    final node = parentRef == null
        ? null
        : browser.tree.find(FolderRef(parentRef.volume, parentRef.child(name.trim())));
    success('created ${node == null ? name.trim() : browser.tree.displayPath(node)}');
    return node;
  }

  Future<FolderNode> _writableParent(FolderNode parent, String name) async {
    final ref = parent.ref;
    final volume = ref?.volume ?? browser.tree.home.volume;
    if (volume == null || name.isEmpty) return parent;
    if (ref != null &&
        library.source.writeRestriction(FolderRef(volume, ref.child(name))) == null) {
      return parent;
    }
    var music = browser.tree.find(FolderRef(volume, 'Music'));
    if (music == null) {
      final root = browser.tree.find(FolderRef(volume, ''));
      if (root == null || await library.createFolder(root, 'Music') != null) {
        return parent;
      }
      music = browser.tree.find(FolderRef(volume, 'Music'));
    }
    if (music == null) return parent;
    echo('mkdir: Android only allows music folders inside Music/, using ~/Music');
    return music;
  }

  Future<void> _mv(CommandInput cmd) async {
    final split = splitSourceAndTarget(cmd.args);
    if (split == null) {
      error('mv: usage: mv <song> <folder>   (use quotes for names with spaces)');
      return;
    }
    final (source, target) = split;
    final folder = _folderArg(target);
    if (folder == null || folder.isRoot) {
      error('mv: $target: no such folder (create it with mkdir)');
      return;
    }
    final track = _findTrack(source, 'mv');
    if (track == null) return;
    await moveTracks([track], folder);
  }

  Future<void> moveTracks(List<Track> tracks, FolderNode folder) async {
    final result = await library.moveTracks(tracks, folder);
    _report(result, 'mv', 'moved', 'to ${browser.tree.displayPath(folder)}');
  }

  Future<void> _rm(CommandInput cmd) async {
    if (cmd.args.isEmpty) {
      error('rm: missing song name');
      return;
    }
    if (cmd.flags.contains('r')) {
      final folder = _folderArg(cmd.rest);
      if (folder == null) {
        error('rm: ${cmd.rest}: no such folder');
        return;
      }
      await deleteFolder(folder);
      return;
    }
    final track = _findTrack(cmd.rest, 'rm');
    if (track == null) return;
    await deleteTracks([track]);
  }

  Future<void> deleteTracks(List<Track> tracks) async {
    if (!library.source.systemConfirmsWrites) {
      final message = tracks.length == 1
          ? Strings.confirmDeleteSong(tracks.single.title)
          : Strings.confirmDeleteSongs(tracks.length);
      final ok = await host?.confirm(message) ?? false;
      if (!ok) {
        echo('rm: cancelled');
        return;
      }
    }
    final result = await library.deleteTracks(tracks);
    _report(result, 'rm', 'deleted', '');
  }

  void _report(FileOpResult result, String cmd, String verb, String suffix) {
    if (result.cancelled) {
      echo('$cmd: cancelled');
      return;
    }
    if (result.succeeded.isNotEmpty) {
      final count = result.succeeded.length;
      success('$verb $count song${count == 1 ? '' : 's'} $suffix'.trim());
    }
    for (final reason in result.failed.values.toSet()) {
      error('$cmd: $reason');
    }
  }

  Future<void> _rmdir(CommandInput cmd) async {
    final folder = cmd.args.isEmpty ? null : _folderArg(cmd.rest);
    if (folder == null) {
      error('rmdir: ${cmd.rest}: no such folder');
      return;
    }
    if (cmd.flags.contains('r')) {
      await deleteFolder(folder);
    } else {
      await removeFolder(folder);
    }
  }

  /// Deletes [folder] together with every song inside it (asks first).
  Future<void> deleteFolder(FolderNode folder) async {
    final ref = folder.ref;
    if (ref == null || ref.path.isEmpty) {
      error('rm: cannot delete a storage root');
      return;
    }
    final label = browser.tree.displayPath(folder);
    final tracks = folder.allTracks();
    final ok =
        await host?.confirm(Strings.confirmDeleteFolder(label, tracks.length)) ?? false;
    if (!ok) {
      echo('rm: cancelled');
      return;
    }
    if (tracks.isNotEmpty) {
      final result = await library.deleteTracks(tracks);
      _report(result, 'rm', 'deleted', 'from $label');
      if (!result.ok) return;
    }
    // The tree was rebuilt: look the folder up again before removing it.
    final current = browser.tree.find(ref);
    if (current != null && current.totalTracks == 0) {
      await library.removeFolder(current);
    }
    success('removed $label');
  }

  Future<void> removeFolder(FolderNode folder) async {
    // If the browser was inside it, it falls back to the nearest parent.
    final message = await library.removeFolder(folder);
    if (message != null) {
      error('rmdir: $message');
      return;
    }
    success('removed ${folder.name}/');
  }

  void _sleep(CommandInput cmd) {
    final arg = cmd.rest.toLowerCase();
    if (arg.isEmpty) {
      final at = player.sleepAt.value;
      echo(at == null
          ? 'sleep: off'
          : 'sleep: pausing in ${at.difference(DateTime.now()).inMinutes + 1} min');
      return;
    }
    if (arg == 'off' || arg == '0') {
      player.setSleepTimer(null);
      echo('sleep: off');
      return;
    }
    final minutes = int.tryParse(arg.replaceAll('m', ''));
    if (minutes == null || minutes <= 0 || minutes > 600) {
      error('sleep: use minutes (1-600) or off');
      return;
    }
    player.setSleepTimer(Duration(minutes: minutes));
    success('sleep: pausing in $minutes min');
  }

  Future<void> _hide(CommandInput cmd) async {
    final folder = cmd.args.isEmpty ? browser.cwd : _folderArg(cmd.rest);
    if (folder == null) {
      error('hide: choose a folder');
      return;
    }
    await hideFolder(folder);
  }

  Future<void> hideFolder(FolderNode folder) async {
    final ref = folder.ref;
    if (ref == null || ref.path.isEmpty) {
      error('hide: choose a folder');
      return;
    }
    final label = browser.tree.displayPath(folder);
    final wasInside = identical(folder, browser.cwd) || folder.isAncestorOf(browser.cwd);
    if (wasInside) browser.enter(folder.parent ?? browser.tree.home);
    await library.hideFolder(ref);
    success('hidden $label  (unhide to restore)');
  }

  Future<void> _unhide(CommandInput cmd) async {
    final hidden = library.hiddenFolders.toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (cmd.args.isEmpty) {
      echo(hidden.isEmpty
          ? 'unhide: no hidden folders'
          : 'hidden:\n${hidden.map((h) => '  ${h.path}').join('\n')}');
      return;
    }
    final wanted = cmd.rest.toLowerCase().replaceAll(RegExp(r'^~?/+|/+$'), '');
    final match = hidden
        .where((h) =>
            h.path.toLowerCase() == wanted ||
            h.path.toLowerCase().endsWith('/$wanted'))
        .toList();
    if (match.length != 1) {
      error('unhide: ${match.isEmpty ? 'not hidden' : 'ambiguous'}: ${cmd.rest}');
      return;
    }
    await library.unhideFolder(match.single);
    await library.reload();
    success('visible again: ${match.single.path}');
  }

  void _sort(CommandInput cmd) {
    final sort = TrackSort.values.where((s) => s.name == cmd.rest.toLowerCase()).firstOrNull;
    if (sort == null) {
      error('sort: use name | date');
      return;
    }
    browser.setSort(sort);
    echo('sort: ${sort.name}');
  }

  /// Resolves a song argument, printing errors for missing/ambiguous names.
  Track? _findTrack(String name, String cmd) {
    final match = resolveTrack(name, browser.cwd.allTracks(), library.tracks);
    if (match.isEmpty) {
      error('$cmd: $name: no such song');
      return null;
    }
    if (!match.isUnique) {
      final shown = match.matches.take(5).map((t) => '  ${t.title}').join('\n');
      error('$cmd: "$name" matches ${match.matches.length} songs, be more specific:\n$shown');
      return null;
    }
    return match.single;
  }

  void _onLibraryDiff(LibraryDiff diff) {
    // Only report background changes (file ops print their own result).
    if (diff.added.isNotEmpty) {
      success('+${diff.added.length} new song${diff.added.length == 1 ? '' : 's'}: '
          '${diff.added.take(3).map((t) => t.title).join(', ')}'
          '${diff.added.length > 3 ? '...' : ''}');
    }
  }

  @override
  void dispose() {
    _diffSub?.cancel();
    super.dispose();
  }
}
