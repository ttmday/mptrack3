import 'package:flutter_test/flutter_test.dart';
import 'package:mptrack3/src/service/terminal/command_parser.dart';

void main() {
  test('unknown first word is a search', () {
    final parsed = parseInput('jose jose');
    expect(parsed, isA<SearchInput>());
    expect((parsed as SearchInput).query, 'jose jose');
  });

  test('parses flags and quoted arguments', () {
    final parsed = parseInput('mv "El Triste" Baladas') as CommandInput;
    expect(parsed.name, CommandName.mv);
    expect(parsed.args, ['El Triste', 'Baladas']);
    expect(splitSourceAndTarget(parsed.args), ('El Triste', 'Baladas'));

    final play = parseInput('play -s Rock') as CommandInput;
    expect(play.flags, {'s'});
    expect(play.rest, 'Rock');
  });

  test('unquoted mv uses the last word as destination', () {
    final parsed = parseInput('mv el triste Baladas') as CommandInput;
    expect(splitSourceAndTarget(parsed.args), ('el triste', 'Baladas'));
  });

  test('cd - is an argument, not a flag', () {
    final parsed = parseInput('cd -') as CommandInput;
    expect(parsed.args, ['-']);
  });

  test('empty input', () {
    expect(parseInput('   '), isA<EmptyInput>());
    expect(splitArgs('a "" b'), ['a', '', 'b']);
  });

  test('menu and home go back to the main menu', () {
    expect((parseInput('menu') as CommandInput).name, CommandName.menu);
    expect((parseInput('home') as CommandInput).name, CommandName.menu);
  });

  test('rm -r keeps the folder as argument', () {
    final parsed = parseInput('rm -r Baladas') as CommandInput;
    expect(parsed.flags, {'r'});
    expect(parsed.rest, 'Baladas');
  });
}
