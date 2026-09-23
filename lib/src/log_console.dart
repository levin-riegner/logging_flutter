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
  bool _showLevelMenu = false;

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
    return DefaultTextStyle(
      style: TextStyle(
        inherit: false,
        color: widget.dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        fontSize: 14,
        decoration: TextDecoration.none,
      ),
      child: ColoredBox(
        color: widget.dark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildTopBar(context),
                    const SizedBox(height: 8),
                    Expanded(child: _buildLogContent()),
                    const SizedBox(height: 8),
                    _buildBottomBar(),
                  ],
                ),
                if (_showLevelMenu) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _showLevelMenu = false),
                    ),
                  ),
                  Positioned(right: 12, bottom: 68, child: _buildLevelMenu()),
                ],
                if (!_followBottom && !_showLevelMenu)
                  Positioned(
                    right: 16,
                    bottom: 76,
                    child: _ConsoleButton(
                      label: '↓',
                      semanticsLabel: 'Jump to latest log',
                      color: widget.dark
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFF01579B),
                      onPressed: _scrollToBottom,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogContent() {
    return ColoredBox(
      color: widget.dark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1600,
          child: ListView.builder(
            shrinkWrap: true,
            controller: _scrollController,
            itemBuilder: (context, index) {
              var logEntry = _filteredBuffer[index];
              return Text.rich(
                logEntry.span,
                key: Key(logEntry.id.toString()),
                style: TextStyle(
                  fontSize: _logFontSize,
                  color: logEntry.level.toColor(widget.dark),
                ),
              );
            },
            itemCount: _filteredBuffer.length,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return LogBar(
      dark: widget.dark,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Text(
            "Log Console",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Spacer(),
          _ConsoleButton(
            label: 'Copy',
            semanticsLabel: 'Copy filtered logs',
            color: const Color(0xFF69F0AE),
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
          _ConsoleButton(
            label: '+',
            semanticsLabel: 'Increase log font size',
            color: widget.dark
                ? const Color(0xFFFFFFFF)
                : const Color(0xFF000000),
            onPressed: () {
              setState(() {
                _logFontSize++;
              });
            },
          ),
          _ConsoleButton(
            label: '−',
            semanticsLabel: 'Decrease log font size',
            color: widget.dark
                ? const Color(0xFFFFFFFF)
                : const Color(0xFF000000),
            onPressed: () {
              setState(() {
                _logFontSize--;
              });
            },
          ),
          if (widget.showCloseButton)
            _ConsoleButton(
              label: '×',
              semanticsLabel: 'Close log console',
              color: const Color(0xFFEF9A9A),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return LogBar(
      dark: widget.dark,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: widget.dark
                      ? const Color(0xFF9E9E9E)
                      : const Color(0xFF616161),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SizedBox(
                height: 44,
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.centerLeft,
                  children: [
                    if (_filterController.text.isEmpty)
                      const IgnorePointer(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Filter log output'),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: EditableText(
                          controller: _filterController,
                          focusNode: _filterFocusNode,
                          style: TextStyle(
                            fontSize: 18,
                            color: widget.dark
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFF000000),
                          ),
                          cursorColor: widget.dark
                              ? const Color(0xFFFFFFFF)
                              : const Color(0xFF000000),
                          backgroundCursorColor: const Color(0xFF9E9E9E),
                          onChanged: (_) => _refreshFilter(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _ConsoleButton(
            label: _levelLabel(_filterLevel),
            semanticsLabel: 'Filter log level',
            color: widget.dark
                ? const Color(0xFFFFFFFF)
                : const Color(0xFF000000),
            onPressed: () => setState(() => _showLevelMenu = true),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelMenu() {
    return SizedBox(
      width: 128,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.dark
              ? const Color(0xFF263238)
              : const Color(0xFFFFFFFF),
          border: Border.all(
            color: widget.dark
                ? const Color(0xFF607D8B)
                : const Color(0xFFBDBDBD),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final level in [
              Level.CONFIG,
              Level.INFO,
              Level.WARNING,
              Level.SEVERE,
            ])
              _ConsoleButton(
                label: _levelLabel(level),
                color: widget.dark
                    ? const Color(0xFFFFFFFF)
                    : const Color(0xFF000000),
                onPressed: () {
                  _filterLevel = level;
                  setState(() => _showLevelMenu = false);
                  _refreshFilter();
                },
              ),
          ],
        ),
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

  LogBar({this.dark, this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? false;
    return SizedBox(
      height: 60,
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

class _ConsoleButton extends StatefulWidget {
  const _ConsoleButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.semanticsLabel,
  });

  final String label;
  final String? semanticsLabel;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_ConsoleButton> createState() => _ConsoleButtonState();
}

class _ConsoleButtonState extends State<_ConsoleButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticsLabel ?? widget.label,
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
          onTap: widget.onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _focused ? widget.color.withValues(alpha: 0.2) : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Text(
                    widget.label,
                    style: TextStyle(color: widget.color, fontSize: 18),
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

extension LevelExtension on Level {
  Color toColor(bool dark) {
    if (this == Level.CONFIG) {
      return dark ? const Color(0x61FFFFFF) : const Color(0x61000000);
    } else if (this == Level.INFO) {
      return dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    } else if (this == Level.WARNING) {
      return const Color(0xFFFF9800);
    } else if (this == Level.SEVERE) {
      return const Color(0xFFF44336);
    } else if (this == Level.SHOUT) {
      return const Color(0xFFFF4081);
    } else {
      return dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    }
  }
}
