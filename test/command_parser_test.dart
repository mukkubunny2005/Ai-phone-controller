import 'package:flutter_test/flutter_test.dart';
import 'package:aiphonecontroller/command_parser.dart';

void main() {
  group('AutomationCommandParser', () {
    test('normalizes punctuation and repeated whitespace', () {
      expect(AutomationCommandParser.normalize('  OPEN   Chrome!  '), 'open chrome');
    });

    test('splits then and and then in the right order', () {
      expect(
        AutomationCommandParser.split('open Chrome and then read screen then back'),
        ['open Chrome and', 'read screen', 'back'],
      );
    });

    test('splits semicolon-delimited workflows', () {
      expect(
        AutomationCommandParser.split('open Chrome; read screen; back'),
        ['open Chrome', 'read screen', 'back'],
      );
    });

    test('keeps a single command as one step', () {
      expect(AutomationCommandParser.split('read screen'), ['read screen']);
    });

    test('ignores empty steps around separators', () {
      expect(AutomationCommandParser.split('; open Chrome ;; back ;'), ['open Chrome', 'back']);
    });
  });
}
