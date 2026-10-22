import 'package:mptrack3/src/model/track.dart';
import 'package:mptrack3/src/util/text_normalize.dart';

/// Identifies a directory on a given storage volume.
class FolderRef {
  const FolderRef(this.volume, this.path);

  final String volume;

  /// Relative path from the volume root, '' for the root itself.
  final String path;

  String get key => '$volume:$path';

  String child(String name) => path.isEmpty ? name : '$path/$name';

  @override
  bool operator ==(Object other) =>
      other is FolderRef && other.volume == volume && other.path == path;

  @override
  int get hashCode => Object.hash(volume, path);

  @override
  String toString() => key;

  static FolderRef? fromKey(String key) {
    final i = key.indexOf(':');
    if (i <= 0) return null;
    return FolderRef(key.substring(0, i), key.substring(i + 1));
  }
}

/// A directory node. The tree root is virtual and contains one node per
/// storage volume.
class FolderNode {
  FolderNode._({
    required this.name,
    required this.volume,
    required this.path,
    required this.parent,
  });

  final String name;

  /// Null only for the virtual root.
  final String? volume;
  final String path;
  final FolderNode? parent;

  final Map<String, FolderNode> _children = {};
  final List<Track> tracks = [];
  int _totalTracks = 0;
  List<FolderNode>? _sortedChildren;

  bool get isRoot => parent == null;
  bool get isVolume => parent != null && parent!.isRoot;
  int get totalTracks => _totalTracks;

  FolderRef? get ref => volume == null ? null : FolderRef(volume!, path);

  List<FolderNode> get children => _sortedChildren ??= (_children.values
          .toList()
        ..sort((a, b) => normalizeText(a.name).compareTo(normalizeText(b.name))));

  /// Every track under this node, own tracks first then each child in order.
  List<Track> allTracks() {
    final result = <Track>[...tracks];
    for (final child in children) {
      result.addAll(child.allTracks());
    }
    return result;
  }

  /// Every descendant folder (depth first), excluding this node.
  Iterable<FolderNode> descendants() sync* {
    for (final child in children) {
      yield child;
      yield* child.descendants();
    }
  }

  FolderNode _childOrCreate(String segment) {
    return _children.putIfAbsent(segment, () {
      _sortedChildren = null;
      return FolderNode._(
        name: segment,
        volume: volume,
        path: path.isEmpty ? segment : '$path/$segment',
        parent: this,
      );
    });
  }

  int _computeTotals() {
    var total = tracks.length;
    for (final child in _children.values) {
      total += child._computeTotals();
    }
    _totalTracks = total;
    return total;
  }

  bool isAncestorOf(FolderNode other) {
    var node = other.parent;
    while (node != null) {
      if (identical(node, this)) return true;
      node = node.parent;
    }
    return false;
  }

  @override
  String toString() => 'FolderNode(${ref ?? '/'})';
}

class FolderTree {
  FolderTree._(this.root, this.volumeLabels);

  final FolderNode root;
  final Map<String, String> volumeLabels;

  static FolderTree empty() =>
      FolderTree._(FolderNode._(name: '/', volume: null, path: '', parent: null), const {});

  /// Builds the tree. [extraFolders] are directories that should exist even
  /// if they contain no tracks yet (e.g. folders created by the user).
  /// [volumeLabels] maps volume ids to human-readable names.
  static FolderTree build(
    Iterable<Track> tracks, {
    Iterable<FolderRef> extraFolders = const [],
    Map<String, String> volumeLabels = const {},
  }) {
    final root = FolderNode._(name: '/', volume: null, path: '', parent: null);
    final volumes = <String, FolderNode>{};

    FolderNode volumeNode(String volume) {
      return volumes.putIfAbsent(volume, () {
        final node = FolderNode._(
          name: volumeLabels[volume] ?? volume,
          volume: volume,
          path: '',
          parent: root,
        );
        root._children[node.name] = node;
        return node;
      });
    }

    FolderNode nodeFor(String volume, String path) {
      var node = volumeNode(volume);
      for (final segment in path.split('/')) {
        if (segment.isEmpty) continue;
        node = node._childOrCreate(segment);
      }
      return node;
    }

    for (final track in tracks) {
      nodeFor(track.volume, track.folder).tracks.add(track);
    }
    for (final folder in extraFolders) {
      nodeFor(folder.volume, folder.path);
    }
    root._computeTotals();
    return FolderTree._(root, volumeLabels);
  }

  List<FolderNode> get volumes => root.children;

  /// Where the browser starts: the only volume, or the virtual root when
  /// several volumes exist.
  FolderNode get home => volumes.length == 1 ? volumes.first : root;

  FolderNode? find(FolderRef ref) {
    final volume = root._children.values
        .where((v) => v.volume == ref.volume)
        .firstOrNull;
    if (volume == null) return null;
    var node = volume;
    for (final segment in ref.path.split('/')) {
      if (segment.isEmpty) continue;
      final next = node._children[segment];
      if (next == null) return null;
      node = next;
    }
    return node;
  }

  /// Shell-like path shown in the prompt, e.g. "~/Music/Rock".
  String displayPath(FolderNode node) {
    if (node.isRoot) return '/';
    final home = this.home;
    if (identical(node, home)) return '~';
    final segments = <String>[];
    FolderNode? current = node;
    while (current != null && !identical(current, home) && !current.isRoot) {
      segments.insert(0, current.name);
      current = current.parent;
    }
    final prefix = (identical(current, home) && !home.isRoot) ? '~' : '';
    return '$prefix/${segments.join('/')}';
  }

  /// Resolves a shell-like [input] path relative to [from].
  ///
  /// Supports "..", ".", "~", "/" and nested segments. Segment matching is
  /// case and accent insensitive; an unambiguous prefix is accepted.
  FolderNode? resolve(FolderNode from, String input) {
    var text = input.trim();
    if (text.isEmpty) return from;
    FolderNode current = from;
    if (text.startsWith('~')) {
      current = home;
      text = text.substring(1);
    } else if (text.startsWith('/')) {
      current = root;
    }
    for (final segment in text.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        current = current.parent ?? current;
        continue;
      }
      final next = matchChild(current, segment);
      if (next == null) return null;
      current = next;
    }
    return current;
  }

  /// Finds a direct child of [parent] by name (exact, normalized, then
  /// unique normalized prefix).
  FolderNode? matchChild(FolderNode parent, String name) {
    final exact = parent._children[name];
    if (exact != null) return exact;
    final wanted = normalizeText(name);
    final children = parent.children;
    final normalized =
        children.where((c) => normalizeText(c.name) == wanted).toList();
    if (normalized.length == 1) return normalized.first;
    final prefixed =
        children.where((c) => normalizeText(c.name).startsWith(wanted)).toList();
    if (prefixed.length == 1) return prefixed.first;
    return null;
  }
}
