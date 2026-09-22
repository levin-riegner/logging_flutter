import 'package:flutter_test/flutter_test.dart';
import 'package:logging_flutter/src/ansi_parser.dart';

void main() {
  test('keeps an unfinished escape sequence as text', () {
    final parser = AnsiParser(false);

    parser.parse('start \u001b[38;5');

    expect(
      parser.spans?.map((span) => span.toPlainText()).join(),
      'start \u001b[38;5',
    );
  });

  test('ignores incomplete color codes without throwing', () {
    final parser = AnsiParser(false);

    parser.parse('before \u001b[38m after');

    expect(
      parser.spans?.map((span) => span.toPlainText()).join(),
      'before  after',
    );
  });
}
