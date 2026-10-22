import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mptrack3/src/library/library_repository.dart';
import 'package:mptrack3/src/library/track_search.dart';
import 'package:mptrack3/src/model/folder_tree.dart';
import 'package:mptrack3/src/model/track.dart';
import 'package:mptrack3/src/util/text_normalize.dart';

enum TrackSort { date, name }

/// Navigation state of the folder browser plus the active search.
class BrowserController extends ChangeNotifier {
  BrowserController(this._library, this._prefs) {
    _sort = TrackSort.values
            .where((s) => s.name == _prefs.getString(_sortKey))
            .firstOrNull ??
        TrackSort.date;
    final saved = _prefs.getString(_cwdKey);
    _cwdRef = saved == null ? null : FolderRef.fromKey(saved);
    _library.addListener(_onLibraryChanged);
  }

  static const _sortKey = 'browser.sort';
  static const _cwdKey = 'browser.cwd';

  final LibraryRepository _library;
  final SharedPreferences _prefs;

  /// Null means "home" (or the virtual root when [_atRoot]).
  FolderRef? _cwdRef;
  bool _atRoot = false;
  FolderRef? _previousRef;
  bool _previousAtRoot = false;

  String _query = '';
  List<Track> _results = const [];
  TrackSort _sort = TrackSort.date;

  String get query => _query;
  bool get searching => _query.trim().isNotEmpty;
  List<Track> get results => _results;
  TrackSort get sort => _sort;
  FolderTree get tree => _library.tree;

  FolderNode get cwd {
    final tree = _library.tree;
    if (_atRoot) return tree.root;
    final ref = _cwdRef;
    if (ref == null) return tree.home;
    var path = ref.path;
    while (true) {
      final node = tree.find(FolderRef(ref.volume, path));
      if (node != null) return node;
      if (path.isEmpty) return tree.home;
      final slash = path.lastIndexOf('/');
      path = slash < 0 ? '' : path.substring(0, slash);
    }
  }

  String get cwdLabel => tree.displayPath(cwd);

  bool get canGoUp => !identical(cwd, tree.root) && cwd.parent != null &&
      !(identical(cwd, tree.home) && tree.volumes.length == 1);

  void enter(FolderNode node) {
    _previousRef = _cwdRef;
    _previousAtRoot = _atRoot;
    _atRoot = node.isRoot;
    _cwdRef = node.isRoot ? null : node.ref;
    _prefs.setString(_cwdKey, _cwdRef?.key ?? '');
    notifyListeners();
  }

  /// Goes to the parent folder. Returns false when already at the top.
  bool up() {
    if (!canGoUp) return false;
    enter(cwd.parent!);
    return true;
  }

  /// "cd -": returns to the previous folder.
  void back() {
    final ref = _previousRef;
    final atRoot = _previousAtRoot;
    _previousRef = _cwdRef;
    _previousAtRoot = _atRoot;
    _cwdRef = ref;
    _atRoot = atRoot;
    notifyListeners();
  }

  void setSort(TrackSort sort) {
    _sort = sort;
    _prefs.setString(_sortKey, sort.name);
    notifyListeners();
  }

  /// Tracks directly inside [folder], in the chosen order.
  List<Track> tracksOf(FolderNode folder) {
    final list = List<Track>.of(folder.tracks);
    switch (_sort) {
      case TrackSort.date:
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      case TrackSort.name:
        list.sort((a, b) => a.normalizedTitle.compareTo(b.normalizedTitle));
    }
    return list;
  }

  /// Queue for "play this folder": direct tracks in display order followed
  /// by subfolders.
  List<Track> playlistOf(FolderNode folder) {
    final result = tracksOf(folder);
    for (final child in folder.children) {
      result.addAll(playlistOf(child));
    }
    return result;
  }

  void setQuery(String query) {
    _query = query;
    _results = searchTracks(query, _library.tracks);
    notifyListeners();
  }

  void clearQuery() {
    if (_query.isEmpty) return;
    setQuery('');
  }

  /// Folders whose name matches the current query.
  List<FolderNode> folderResults({int limit = 8}) {
    final tokens = tokenize(_query);
    if (tokens.isEmpty) return const [];
    return tree.root
        .descendants()
        .where((f) => !f.isVolume && f.totalTracks > 0)
        .where((f) {
          final name = normalizeText(f.name);
          return tokens.every(name.contains);
        })
        .take(limit)
        .toList();
  }

  void _onLibraryChanged() {
    if (searching) _results = searchTracks(_query, _library.tracks);
    notifyListeners();
  }

  @override
  void dispose() {
    _library.removeListener(_onLibraryChanged);
    super.dispose();
  }
}
