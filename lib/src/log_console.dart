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
                          _buildBottomBar(compact: compact),
                        ],
                      ),
                      if (_showLevelMenu) ...[
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _showLevelMenu = false),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: compact ? 164 : 116,
                          child: _buildLevelMenu(),
                        ),
                      ],
                      if (!_followBottom && !_showLevelMenu)
                        Positioned(
                          right: 16,
                          bottom: compact ? 172 : 124,
                          child: _ConsoleButton(
                            label: '↓ Latest',
                            semanticsLabel: 'Jump to latest log',
                            color: widget.dark
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFF01579B),
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
        _ConsoleButton(
          label: 'Copy',
          semanticsLabel: 'Copy filtered logs',
          color: widget.dark
              ? const Color(0xFF69F0AE)
              : const Color(0xFF006B3C),
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
        if (widget.showCloseButton)
          _ConsoleButton(
            label: 'Close',
            semanticsLabel: 'Close log console',
            color: widget.dark
                ? const Color(0xFFECEFF1)
                : const Color(0xFF263238),
            onPressed: () => Navigator.pop(context),
          ),
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

  Widget _buildBottomBar({required bool compact}) {
    final foreground = widget.dark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
    final levelControl = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Level'),
        const SizedBox(width: 8),
        _ConsoleButton(
          label: _levelLabel(_filterLevel),
          semanticsLabel: 'Filter log level',
          color: foreground,
          onPressed: () => setState(() => _showLevelMenu = true),
        ),
      ],
    );
    final fontControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ConsoleButton(
          label: 'A−',
          semanticsLabel: 'Decrease log font size',
          color: foreground,
          onPressed: () {
            if (_logFontSize > 11) setState(() => _logFontSize--);
          },
        ),
        _ConsoleButton(
          label: 'A+',
          semanticsLabel: 'Increase log font size',
          color: foreground,
          onPressed: () {
            if (_logFontSize < 24) setState(() => _logFontSize++);
          },
        ),
      ],
    );
    return SizedBox(
      height: compact ? 156 : 108,
      child: ColoredBox(
        color: widget.dark ? const Color(0xFF263238) : const Color(0xFFFFFFFF),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            children: [
              SizedBox(height: 44, child: _buildSearchField()),
              const SizedBox(height: 4),
              if (compact) ...[
                Align(alignment: Alignment.centerLeft, child: levelControl),
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight, child: fontControls),
              ] else
                Row(children: [levelControl, const Spacer(), fontControls]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.dark
              ? const Color(0xFF78909C)
              : const Color(0xFF90A4AE),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_filterController.text.isEmpty)
            const IgnorePointer(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Search logs'),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(
              left: 12,
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
              child: _ConsoleButton(
                label: '×',
                semanticsLabel: 'Clear search',
                color: widget.dark
                    ? const Color(0xFFB0BEC5)
                    : const Color(0xFF546E7A),
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
