/// Parses the text typed in the bottom prompt.
///
/// The first word decides: a known command runs it, anything else is
/// treated as a search query.
library;

enum CommandName {
  help,
  ls,
  cd,
  pwd,
  play,
  pause,
  stop,
  next,
  prev,
  shuffle,
  repeat,
  mkdir,
  mv,
  rm,
  rmdir,
  find,
  sleep,
  refresh,
  clear,
  hide,
  unhide,
  sort,
  np,
  menu,
}

const Map<String, CommandName> _aliases = {
  'help': CommandName.help,
  '?': CommandName.help,
  'ls': CommandName.ls,
  'dir': CommandName.ls,
  'cd': CommandName.cd,
  'pwd': CommandName.pwd,
  'play': CommandName.play,
  'pause': CommandName.pause,
  'stop': CommandName.stop,
  'next': CommandName.next,
  'prev': CommandName.prev,
  'shuffle': CommandName.shuffle,
  'repeat': CommandName.repeat,
  'mkdir': CommandName.mkdir,
  'mv': CommandName.mv,
  'rm': CommandName.rm,
  'rmdir': CommandName.rmdir,
  'find': CommandName.find,
  'sleep': CommandName.sleep,
  'refresh': CommandName.refresh,
  'rescan': CommandName.refresh,
  'clear': CommandName.clear,
  'hide': CommandName.hide,
  'unhide': CommandName.unhide,
  'sort': CommandName.sort,
  'np': CommandName.np,
  'menu': CommandName.menu,
  'home': CommandName.menu,
};

sealed class ParsedInput {
  const ParsedInput();
}

class EmptyInput extends ParsedInput {
  const EmptyInput();
}

class SearchInput extends ParsedInput {
  const SearchInput(this.query);
  final String query;
}

class CommandInput extends ParsedInput {
  const CommandInput(this.name, this.args, this.flags);
  final CommandName name;

  /// Positional arguments (quotes removed).
  final List<String> args;

  /// Single-dash flags without the dash, e.g. "-s" -> "s".
  final Set<String> flags;

  /// All positional arguments joined back with spaces.
  String get rest => args.join(' ');
}

ParsedInput parseInput(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const EmptyInput();
  final tokens = splitArgs(text);
  if (tokens.isEmpty) return const EmptyInput();
  final name = _aliases[tokens.first.toLowerCase()];
  if (name == null) return SearchInput(text);

  final args = <String>[];
  final flags = <String>{};
  for (final token in tokens.skip(1)) {
    if (RegExp(r'^-[a-zA-Z]+$').hasMatch(token)) {
      flags.addAll(token.substring(1).split(''));
    } else {
      args.add(token);
    }
  }
  return CommandInput(name, args, flags);
}

/// Splits on whitespace, keeping "double" or 'single' quoted groups together.
List<String> splitArgs(String text) {
  final result = <String>[];
  final buffer = StringBuffer();
  String? quote;
  var hasToken = false;
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (quote != null) {
      if (char == quote) {
        quote = null;
      } else {
        buffer.write(char);
      }
      continue;
    }
    if (char == '"' || char == "'") {
      quote = char;
      hasToken = true;
      continue;
    }
    if (char.trim().isEmpty) {
      if (hasToken || buffer.isNotEmpty) {
        result.add(buffer.toString());
        buffer.clear();
        hasToken = false;
      }
      continue;
    }
    buffer.write(char);
    hasToken = true;
  }
  if (hasToken || buffer.isNotEmpty) result.add(buffer.toString());
  return result;
}

/// Splits "mv" arguments into (source, destination). The destination is
/// the last argument; everything before it is the source. Returns null when
/// fewer than two arguments are present.
(String, String)? splitSourceAndTarget(List<String> args) {
  if (args.length < 2) return null;
  return (args.sublist(0, args.length - 1).join(' '), args.last);
}
