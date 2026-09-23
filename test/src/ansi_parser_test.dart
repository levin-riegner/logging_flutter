import 'package:flutter/material.dart';
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

  test('reset restores the inherited text color in dark mode', () {
    final parser = AnsiParser(true);

    parser.parse('\u001b[38;5;196mred\u001b[0m normal');

    expect(parser.spans?.first.style?.color, Colors.red[300]);
    expect(parser.spans?.last.style?.color, isNull);
  });

  test(
    'indexed black differs from reset and unknown colors remain readable',
    () {
      final parser = AnsiParser(true);

      parser.parse('\u001b[38;5;0mblack\u001b[0m default');
      expect(parser.spans?.first.style?.color, Colors.black);
      expect(parser.spans?.last.style?.color, isNull);

      parser.parse('\u001b[48;5;0mbackground\u001b[49m default');
      expect(parser.spans?.first.style?.backgroundColor, Colors.black);
      expect(parser.spans?.last.style?.backgroundColor, isNull);

      parser.parse('\u001b[38;5;201munknown');
      expect(parser.spans?.last.style?.color, isNull);
    },
  );
}
