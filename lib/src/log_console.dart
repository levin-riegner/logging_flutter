import 'dart:collection';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'ansi_parser.dart';

final ListQueue<OutputEvent> _outputEventBuffer = ListQueue();

class FullLogs {
  StringBuffer fullLogs = StringBuffer('Start: ');
}

class OutputEvent {
  final Level level;
  final List<String> lines;

  OutputEvent(this.level, this.lines);
}

class LogConsole extends StatefulWidget {
  static final ValueNotifier<int> _bufferVersion = ValueNotifier<int>(0);

  final bool dark;
  final bool showCloseButton;

  LogConsole({this.dark = false, this.showCloseButton = false});

  static Future<void> open(BuildContext context, {bool? dark}) async {
    var logConsole = LogConsole(
      showCloseButton: true,
      dark: dark ?? MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    );
    await Navigator.push<void>(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => logConsole,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  static void add(OutputEvent outputEvent, {int? bufferSize = 1000}) {
    final capacity = bufferSize ?? 1000;
    if (capacity <= 0) {
      throw ArgumentError.value(bufferSize, 'bufferSize', 'must be positive');
    }
    while (_outputEventBuffer.length >= capacity) {
      _outputEventBuffer.removeFirst();
    }
    _outputEventBuffer.add(outputEvent);
    _bufferVersion.value++;
  }

  /// Remove buffered entries from any open console.
  static void clear() {
    _outputEventBuffer.clear();
    _bufferVersion.value++;
  }

  @override
  _LogConsoleState createState() => _LogConsoleState();
}

class RenderedEvent {
  final int id;
  final Level level;
  final TextSpan span;
  final String lowerCaseText;
  final String originalText;

  RenderedEvent(
    this.id,
    this.level,
    this.span,
    this.lowerCaseText, {
    String? originalText,
  }) : originalText = originalText ?? lowerCaseText;
}

class _LogConsoleState extends State<LogConsole> {
  ListQueue<RenderedEvent> _renderedBuffer = ListQueue();
  List<RenderedEvent> _filteredBuffer = [];

  var _scrollController = ScrollController();
  var _filterController = TextEditingController();
  var _filterFocusNode = FocusNode();

  Level _filterLevel = Level.CONFIG;
  double _logFontSize = 14;

  var _currentId = 0;
  bool _scrollListenerEnabled = true;
  bool _followBottom = true;

  @override
  void initState() {
    super.initState();
    LogConsole._bufferVersion.addListener(_onBufferChanged);
    _reloadFromBuffer();

    _scrollController.addListener(() {
      if (!_scrollListenerEnabled || !_scrollController.hasClients) return;
      var scrolledToBottom =
          _scrollController.offset >=
          _scrollController.position.maxScrollExtent;
      setState(() {
        _followBottom = scrolledToBottom;
      });
    });
  }

  @override
  void didUpdateWidget(LogConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dark != widget.dark) _reloadFromBuffer();
  }

  void _reloadFromBuffer() {
    _renderedBuffer.clear();
    for (var event in _outputEventBuffer) {
      _renderedBuffer.add(_renderEvent(event));
    }
    _filteredBuffer = _matchingEvents();
  }

  void _onBufferChanged() {
    if (!mounted) return;
    setState(_reloadFromBuffer);
    _scheduleScrollToBottom();
  }

  List<RenderedEvent> _matchingEvents() {
    return _renderedBuffer.where((it) {
      var logLevelMatches = it.level.value >= _filterLevel.value;
      if (!logLevelMatches) {
        return false;
      } else if (_filterController.text.isNotEmpty) {
        var filterText = _filterController.text.toLowerCase();
        return it.lowerCaseText.contains(filterText);
      } else {
        return true;
      }
    }).toList();
  }

  void _refreshFilter() {
    setState(() {
      _filteredBuffer = _matchingEvents();
    });
    _scheduleScrollToBottom();
  }

  void _scheduleScrollToBottom() {
    if (!_followBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _followBottom) _scrollToBottom();
    });
  }

  @override
  void dispose() {
    LogConsole._bufferVersion.removeListener(_onBufferChanged);
    _scrollController.dispose();
    _filterController.dispose();
    _filterFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: widget.dark
          ? const SystemUiOverlayStyle(
              statusBarColor: Color(0x00000000),
              statusBarBrightness: Brightness.dark,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: Color(0xFF000000),
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Color(0x00000000),
              statusBarBrightness: Brightness.light,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: Color(0xFFFFFFFF),
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
      child: DefaultTextStyle(
        style: TextStyle(
          inherit: false,
          color: widget.dark
              ? const Color(0xFFFFFFFF)
              : const Color(0xFF000000),
          fontSize: 14,
          decoration: TextDecoration.none,
        ),
        child: ColoredBox(
          color: widget.dark
              ? const Color(0xFF000000)
              : const Color(0xFFF5F5F5),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < 360 ||
                      MediaQuery.textScalerOf(context).scale(16) > 20;
                  return Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildTopBar(context, compact: compact),
                          const SizedBox(height: 8),
                          Expanded(child: _buildLogContent()),
                          const SizedBox(height: 8),
                          _buildBottomBar(),
                        ],
                      ),
                      if (!_followBottom)
                        Positioned(
                          right: 16,
                          bottom: 142,
                          child: _RoundControl(
                            dark: widget.dark,
                            icon: _ControlIcon.latest,
                            semanticsLabel: 'Jump to latest log',
                            accent: true,
                            onPressed: _scrollToBottom,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogContent() {
    return ColoredBox(
      color: widget.dark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      child: _filteredBuffer.isEmpty
          ? Center(
              child: Text(
                _outputEventBuffer.isEmpty
                    ? 'No logs yet'
                    : 'No logs match these filters',
                style: TextStyle(
                  color: widget.dark
                      ? const Color(0xFFB0BEC5)
                      : const Color(0xFF546E7A),
                ),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemBuilder: (context, index) {
                final entry = _filteredBuffer[index];
                final levelColor = entry.level.toColor(widget.dark);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          _shortLevelLabel(entry.level),
                          style: TextStyle(
                            color: levelColor,
                            fontSize: _logFontSize,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          entry.span,
                          key: Key(entry.id.toString()),
                          softWrap: true,
                          style: TextStyle(
                            fontSize: _logFontSize,
                            height: 1.35,
                            fontFamily: 'monospace',
                            color: levelColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              itemCount: _filteredBuffer.length,
            ),
    );
  }

  String _shortLevelLabel(Level level) {
    if (level == Level.INFO) return 'I';
    if (level == Level.WARNING) return 'W';
    if (level == Level.SEVERE) return 'E';
    if (level == Level.SHOUT) return '!';
    return 'D';
  }

  Widget _buildTopBar(BuildContext context, {required bool compact}) {
    final count = _filteredBuffer.length == _renderedBuffer.length
        ? '${_filteredBuffer.length}'
        : '${_filteredBuffer.length}/${_renderedBuffer.length}';
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Logs',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Text(
          count,
          style: TextStyle(
            fontSize: 13,
            color: widget.dark
                ? const Color(0xFFB0BEC5)
                : const Color(0xFF546E7A),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _followBottom ? 'LIVE' : 'PAUSED',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: _followBottom
                ? (widget.dark
                      ? const Color(0xFF81C784)
                      : const Color(0xFF1B5E20))
                : (widget.dark
                      ? const Color(0xFFFFB74D)
                      : const Color(0xFF8D5200)),
          ),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundControl(
          dark: widget.dark,
          icon: _ControlIcon.copy,
          semanticsLabel: 'Copy filtered logs',
          accent: true,
          onPressed: () {
            Clipboard.setData(
              ClipboardData(
                text: _filteredBuffer
                    .map((entry) => entry.originalText)
                    .join('\n'),
              ),
            );
          },
        ),
        if (widget.showCloseButton) ...[
          const SizedBox(width: 8),
          _RoundControl(
            dark: widget.dark,
            icon: _ControlIcon.close,
            semanticsLabel: 'Close log console',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ],
    );
    return LogBar(
      dark: widget.dark,
      height: compact ? 96 : 60,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            )
          : Row(children: [title, const Spacer(), actions]),
    );
  }

  Widget _buildBottomBar() {
    const levels = [Level.CONFIG, Level.INFO, Level.WARNING, Level.SEVERE];
    final levelControl = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final level in levels) ...[
          if (level != levels.first) const SizedBox(width: 4),
          _RoundControl(
            dark: widget.dark,
            label: _shortLevelLabel(level),
            semanticsLabel: 'Filter logs from ${_levelLabel(level)} level',
            selected: _filterLevel == level,
            onPressed: () {
              _filterLevel = level;
              _refreshFilter();
            },
          ),
        ],
      ],
    );
    final fontControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundControl(
          dark: widget.dark,
          label: 'A−',
          semanticsLabel: 'Decrease log font size',
          onPressed: () {
            if (_logFontSize > 11) setState(() => _logFontSize--);
          },
        ),
        const SizedBox(width: 4),
        _RoundControl(
          dark: widget.dark,
          label: 'A+',
          semanticsLabel: 'Increase log font size',
          onPressed: () {
            if (_logFontSize < 24) setState(() => _logFontSize++);
          },
        ),
      ],
    );
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(10) > 13 ? 148 : 132,
      child: ColoredBox(
        color: widget.dark ? const Color(0xFF263238) : const Color(0xFFFFFFFF),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 44, child: _buildSearchField()),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('LEVEL', style: _controlCaptionStyle()),
                  const Spacer(),
                  Text('TEXT SIZE', style: _controlCaptionStyle()),
                ],
              ),
              const SizedBox(height: 4),
              Row(children: [levelControl, const Spacer(), fontControls]),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _controlCaptionStyle() => TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: widget.dark ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A),
  );

  Widget _buildSearchField() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.dark ? const Color(0xFF1C2A30) : const Color(0xFFF2F6F7),
        border: Border.all(
          color: widget.dark
              ? const Color(0xFF52646D)
              : const Color(0xFFCEDCE1),
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: _ControlGlyph(
                icon: _ControlIcon.search,
                color: widget.dark
                    ? const Color(0xFFB0BEC5)
                    : const Color(0xFF546E7A),
              ),
            ),
          ),
          if (_filterController.text.isEmpty)
            const IgnorePointer(
              child: Padding(
                padding: EdgeInsets.only(left: 42),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Search logs'),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(
              left: 42,
              right: _filterController.text.isEmpty ? 12 : 48,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: EditableText(
                controller: _filterController,
                focusNode: _filterFocusNode,
                style: TextStyle(
                  fontSize: 16,
                  color: widget.dark
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF000000),
                ),
                cursorColor: widget.dark
                    ? const Color(0xFFFFFFFF)
                    : const Color(0xFF000000),
                backgroundCursorColor: const Color(0xFF9E9E9E),
                textInputAction: TextInputAction.search,
                onChanged: (_) => _refreshFilter(),
              ),
            ),
          ),
          if (_filterController.text.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: _RoundControl(
                dark: widget.dark,
                icon: _ControlIcon.close,
                semanticsLabel: 'Clear search',
                onPressed: () {
                  _filterController.clear();
                  _refreshFilter();
                },
              ),
            ),
        ],
      ),
    );
  }

  String _levelLabel(Level level) {
    if (level == Level.INFO) return 'INFO';
    if (level == Level.WARNING) return 'WARNING';
    if (level == Level.SEVERE) return 'ERROR';
    return 'DEBUG';
  }

  void _scrollToBottom() async {
    if (!_scrollController.hasClients) return;
    _scrollListenerEnabled = false;

    setState(() {
      _followBottom = true;
    });

    var scrollPosition = _scrollController.position;
    await _scrollController.animateTo(
      scrollPosition.maxScrollExtent,
      duration: new Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );

    if (mounted) _scrollListenerEnabled = true;
  }

  RenderedEvent _renderEvent(OutputEvent event) {
    var parser = AnsiParser(widget.dark);
    var text = event.lines.join('\n');
    parser.parse(text);
    return RenderedEvent(
      _currentId++,
      event.level,
      TextSpan(children: parser.spans),
      text.toLowerCase(),
      originalText: text,
    );
  }
}

class LogBar extends StatelessWidget {
  final bool? dark;
  final Widget? child;
  final double height;

  LogBar({this.dark, this.child, this.height = 60});

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? false;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            if (!isDark)
              const BoxShadow(color: Color(0xFFBDBDBD), blurRadius: 3),
          ],
        ),
        child: ColoredBox(
          color: isDark ? const Color(0xFF263238) : const Color(0xFFFFFFFF),
          child: DefaultTextStyle(
            style: TextStyle(
              color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
              fontSize: 16,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 8, 15, 8),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundControl extends StatefulWidget {
  const _RoundControl({
    required this.dark,
    required this.onPressed,
    required this.semanticsLabel,
    this.label,
    this.icon,
    this.selected,
    this.accent = false,
  }) : assert(label != null || icon != null);

  final bool dark;
  final String? label;
  final _ControlIcon? icon;
  final String semanticsLabel;
  final bool? selected;
  final bool accent;
  final VoidCallback onPressed;

  @override
  State<_RoundControl> createState() => _RoundControlState();
}

class _RoundControlState extends State<_RoundControl> {
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.dark
        ? const Color(0xFF67E1AE)
        : const Color(0xFF087B57);
    final foreground = widget.selected == true
        ? (widget.dark ? const Color(0xFF09291E) : const Color(0xFFFFFFFF))
        : widget.accent
        ? accentColor
        : (widget.dark ? const Color(0xFFF3F7F8) : const Color(0xFF24343B));
    final background = widget.selected == true
        ? accentColor
        : widget.accent
        ? (widget.dark ? const Color(0xFF214235) : const Color(0xFFE2F4EA))
        : (widget.dark ? const Color(0xFF36474F) : const Color(0xFFF0F4F5));
    final border = widget.selected == true
        ? accentColor
        : (widget.dark ? const Color(0xFF5A6D75) : const Color(0xFFCFDCE0));
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticsLabel,
      onTap: widget.onPressed,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          onShowFocusHighlight: (focused) => setState(() => _focused = focused),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pressed
                    ? Color.lerp(background, foreground, 0.16)
                    : background,
                border: Border.all(
                  color: _focused ? accentColor : border,
                  width: _focused ? 2 : 1,
                ),
              ),
              child: Center(
                child: widget.icon != null
                    ? _ControlGlyph(icon: widget.icon!, color: foreground)
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.label!,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ControlIcon { copy, close, latest, search }

class _ControlGlyph extends StatelessWidget {
  const _ControlGlyph({required this.icon, required this.color});

  final _ControlIcon icon;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(20, 20),
    painter: _ControlGlyphPainter(icon, color),
  );
}

class _ControlGlyphPainter extends CustomPainter {
  const _ControlGlyphPainter(this.icon, this.color);

  final _ControlIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 20, size.height / 20);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (icon) {
      case _ControlIcon.copy:
        canvas.drawLine(const Offset(4, 14), const Offset(4, 3), stroke);
        canvas.drawLine(const Offset(4, 3), const Offset(14, 3), stroke);
        canvas.drawLine(const Offset(14, 3), const Offset(14, 5), stroke);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(7, 6, 10, 12),
            const Radius.circular(1.5),
          ),
          stroke,
        );
      case _ControlIcon.close:
        canvas.drawLine(const Offset(5, 5), const Offset(15, 15), stroke);
        canvas.drawLine(const Offset(15, 5), const Offset(5, 15), stroke);
      case _ControlIcon.latest:
        canvas.drawLine(const Offset(10, 3), const Offset(10, 14), stroke);
        canvas.drawLine(const Offset(5, 10), const Offset(10, 15), stroke);
        canvas.drawLine(const Offset(10, 15), const Offset(15, 10), stroke);
        canvas.drawLine(const Offset(4, 18), const Offset(16, 18), stroke);
      case _ControlIcon.search:
        canvas.drawCircle(const Offset(8.5, 8.5), 5, stroke);
        canvas.drawLine(const Offset(12.5, 12.5), const Offset(17, 17), stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ControlGlyphPainter oldDelegate) =>
      icon != oldDelegate.icon || color != oldDelegate.color;
}

extension LevelExtension on Level {
  Color toColor(bool dark) {
    if (this == Level.CONFIG) {
      return dark ? const Color(0xFF9E9E9E) : const Color(0xFF616161);
    } else if (this == Level.INFO) {
      return dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    } else if (this == Level.WARNING) {
      return dark ? const Color(0xFFFFB74D) : const Color(0xFFA65300);
    } else if (this == Level.SEVERE) {
      return dark ? const Color(0xFFEF5350) : const Color(0xFFB71C1C);
    } else if (this == Level.SHOUT) {
      return dark ? const Color(0xFFF48FB1) : const Color(0xFFAD1457);
    } else {
      return dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    }
  }
}
