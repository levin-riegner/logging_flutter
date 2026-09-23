import 'package:flutter/widgets.dart';

class AnsiParser {
  static const TEXT = 0, BRACKET = 1, CODE = 2;

  final bool dark;

  AnsiParser(this.dark);

  Color? foreground;
  Color? background;
  List<TextSpan>? spans;

  void parse(String s) {
    spans = [];
    var state = TEXT;
    StringBuffer? buffer;
    var text = StringBuffer();
    var code = 0;
    late List<int> codes;

    for (var i = 0, n = s.length; i < n; i++) {
      var c = s[i];

      switch (state) {
        case TEXT:
          if (c == '\u001b') {
            state = BRACKET;
            buffer = StringBuffer(c);
            code = 0;
            codes = [];
          } else {
            text.write(c);
          }
          break;

        case BRACKET:
          buffer!.write(c);
          if (c == '[') {
            state = CODE;
          } else {
            state = TEXT;
            text.write(buffer);
          }
          break;

        case CODE:
          buffer!.write(c);
          var codeUnit = c.codeUnitAt(0);
          if (codeUnit >= 48 && codeUnit <= 57) {
            code = code * 10 + codeUnit - 48;
            continue;
          } else if (c == ';') {
            codes.add(code);
            code = 0;
            continue;
          } else {
            if (text.isNotEmpty) {
              spans!.add(createSpan(text.toString()));
              text.clear();
            }
            state = TEXT;
            if (c == 'm') {
              codes.add(code);
              handleCodes(codes);
            } else {
              text.write(buffer);
            }
          }

          break;
      }
    }

    if (state != TEXT && buffer != null) text.write(buffer);
    spans!.add(createSpan(text.toString()));
  }

  void handleCodes(List<int> codes) {
    if (codes.isEmpty) {
      codes.add(0);
    }

    switch (codes[0]) {
      case 0:
        foreground = getColor(0, true);
        background = getColor(0, false);
        break;
      case 38:
        if (codes.length >= 3 && codes[1] == 5) {
          foreground = getColor(codes[2], true);
        }
        break;
      case 39:
        foreground = getColor(0, true);
        break;
      case 48:
        if (codes.length >= 3 && codes[1] == 5) {
          background = getColor(codes[2], false);
        }
        break;
      case 49:
        background = getColor(0, false);
    }
  }

  Color? getColor(int colorCode, bool foreground) {
    switch (colorCode) {
      case 0:
        return foreground ? const Color(0xFF000000) : const Color(0x00000000);
      case 12:
        return dark ? const Color(0xFF81D4FA) : const Color(0xFF0D47A1);
      case 208:
        return dark ? const Color(0xFFFFB74D) : const Color(0xFFA65300);
      case 196:
        return dark ? const Color(0xFFEF5350) : const Color(0xFFB71C1C);
      case 199:
        return dark ? const Color(0xFFF48FB1) : const Color(0xFFAD1457);
    }
    return foreground ? const Color(0xFF000000) : const Color(0x00000000);
  }

  TextSpan createSpan(String text) {
    return TextSpan(
      text: text,
      style: TextStyle(color: foreground, backgroundColor: background),
    );
  }
}
