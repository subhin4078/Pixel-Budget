import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'card_backdrop.dart';

enum SceneKind { home, records, statistics, travel, trip, settings }

class _SceneSpec {
  const _SceneSpec(
    this.background, {
    required this.focusX,
    this.imageLeft = -86,
    required this.foreground,
    required this.person,
  });
  final String background;

  /// Horizontal offset of the blurred ambient copy, in reference units.
  final double focusX;
  final double imageLeft;
  final String foreground;

  /// Cutout placement relative to the clear illustration (565 × 318).
  /// The cutout canvas matches the background, but the girl in it is drawn
  /// at a different size, so each page has a measured offset and scale.
  final Rect person;

  Rect get clearRect => Rect.fromLTWH(imageLeft, 0, 565, 318);
  Rect get personRect => person.shift(clearRect.topLeft);
}

const _scenes = {
  SceneKind.home: _SceneSpec(
    '01-home-scrapbook.png',
    focusX: -590,
    foreground: 'home-character-foreground.png',
    person: Rect.fromLTWH(21.6, 5.4, 519.8, 292.6),
  ),
  SceneKind.records: _SceneSpec(
    '03-records-desk.png',
    focusX: -890,
    foreground: 'records-character-foreground.png',
    person: Rect.fromLTWH(89.2, 43.3, 446.4, 251.2),
  ),
  SceneKind.statistics: _SceneSpec(
    '04-stats-observatory.png',
    focusX: -727,
    foreground: 'stats-character-foreground.png',
    person: Rect.fromLTWH(104.1, 66.2, 412.4, 232.1),
  ),
  SceneKind.travel: _SceneSpec(
    '05-travel-platform.png',
    focusX: -300,
    imageLeft: -40,
    foreground: 'travel-character-foreground.png',
    person: Rect.fromLTWH(28.4, 16.9, 507.7, 285.8),
  ),
  SceneKind.trip: _SceneSpec(
    '06-travel-terrace.png',
    focusX: -500,
    imageLeft: -150,
    foreground: 'travel-terrace-character-foreground.png',
    person: Rect.fromLTWH(95.0, 55.5, 428.3, 241.5),
  ),
  SceneKind.settings: _SceneSpec(
    '02-add-corridor.png',
    focusX: -350,
    foreground: 'add-character-foreground.png',
    person: Rect.fromLTWH(30, 35, 479, 270),
  ),
};

/// Illustrated page: a clear scene on top that fades into a blurred copy of
/// itself, with glass cards floating over it. Reference width is 393.
class ScenePage extends StatelessWidget {
  const ScenePage({
    super.key,
    required this.kind,
    required this.title,
    required this.body,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.contentTop = 168,
    this.bottomInset = 104,
  });
  final SceneKind kind;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  /// Where the first card starts, in reference units.
  final double contentTop;
  final double bottomInset;
  final List<Widget> Function(BuildContext context, double scale) body;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final s = constraints.maxWidth / 393;
      final spec = _scenes[kind]!;
      final ambientHeight = math.max(constraints.maxHeight, 852 * s);
      final ambientWidth = ambientHeight * 1672 / 941;
      final top =
          kind == SceneKind.trip
              ? MediaQuery.paddingOf(context).top + 2
              : math.max(30 * s, MediaQuery.paddingOf(context).top + 6);
      final textExtra = math.max(
        0.0,
        MediaQuery.textScalerOf(context).scale(10) - 10,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: IgnorePointer(
              child: ClipRect(
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Palette.background),
                    ),
                    Positioned(
                      left: spec.focusX * s + (1514 * s - ambientWidth) / 2,
                      top: 0,
                      width: ambientWidth,
                      height: ambientHeight,
                      child: Opacity(
                        opacity: .55,
                        child: ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: 10 * s,
                            sigmaY: 10 * s,
                          ),
                          child: Image.asset(
                            'assets/backgrounds/${spec.background}',
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0, .25, .42, .7, 1],
                            colors: [
                              for (final a in [.04, .1, .3, .5, .62])
                                Palette.background.withValues(alpha: a),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            primary: false,
            key: PageStorageKey(kind),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: _BackdropScope(
                builder:
                    (host) => Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          left: spec.clearRect.left * s,
                          top: spec.clearRect.top * s,
                          width: spec.clearRect.width * s,
                          height: spec.clearRect.height * s,
                          child: IgnorePointer(
                            child: ShaderMask(
                              blendMode: BlendMode.dstIn,
                              shaderCallback:
                                  (bounds) => const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white,
                                      Colors.white,
                                      Colors.transparent,
                                    ],
                                    stops: [0, .52, 1],
                                  ).createShader(bounds),
                              child: Image.asset(
                                'assets/backgrounds/${spec.background}',
                                fit: BoxFit.fill,
                                gaplessPlayback: true,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          right: 0,
                          height: 200 * s,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0, .5, 1],
                                  colors: [
                                    for (final a in [.62, .2, 0.0])
                                      const Color(
                                        0xFF211B50,
                                      ).withValues(alpha: a),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Order: card glass, then the girl, then titles and card content.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CardBackdrops(host: host),
                          ),
                        ),
                        _person(spec, s),
                        Positioned(
                          left:
                              kind == SceneKind.trip
                                  ? 0
                                  : (leading == null ? 18 : 6) * s,
                          right:
                              (kind == SceneKind.travel ||
                                      kind == SceneKind.settings
                                  ? 18
                                  : 8) *
                              s,
                          top: top,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (leading != null) leading!,
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top:
                                        leading == null
                                            ? 0
                                            : kind == SceneKind.trip
                                            ? 4
                                            : 8,
                                  ),
                                  child: _SceneTitle(
                                    title: title,
                                    subtitle: subtitle,
                                    large: kind == SceneKind.home,
                                    rightAligned:
                                        kind == SceneKind.travel ||
                                        kind == SceneKind.settings,
                                  ),
                                ),
                              ),
                              ...actions,
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            16 * s,
                            contentTop * s + textExtra * 2,
                            16 * s,
                            bottomInset +
                                textExtra * 1.5 +
                                MediaQuery.paddingOf(context).bottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: body(context, s),
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _person(_SceneSpec spec, double s) => Positioned(
    left: spec.personRect.left * s,
    top: spec.personRect.top * s,
    width: spec.personRect.width * s,
    height: spec.personRect.height * s,
    child: IgnorePointer(
      child: ExcludeSemantics(
        child: Image.asset(
          'assets/foregrounds/${spec.foreground}',
          fit: BoxFit.fill,
          gaplessPlayback: true,
        ),
      ),
    ),
  );
}

class _BackdropScope extends StatefulWidget {
  const _BackdropScope({required this.builder});
  final Widget Function(CardBackdropHost host) builder;
  @override
  State<_BackdropScope> createState() => _BackdropScopeState();
}

class _BackdropScopeState extends State<_BackdropScope> {
  final _host = CardBackdropHost();
  @override
  Widget build(BuildContext context) =>
      CardBackdropScope(host: _host, child: widget.builder(_host));
}

class _SceneTitle extends StatelessWidget {
  const _SceneTitle({
    required this.title,
    required this.subtitle,
    required this.large,
    required this.rightAligned,
  });
  final String title;
  final String? subtitle;
  final bool large;
  final bool rightAligned;

  static const _shadow = [Shadow(color: Color(0x9930235C), blurRadius: 6)];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment:
        rightAligned ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(
        title,
        textAlign: rightAligned ? TextAlign.right : TextAlign.start,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: large ? 23 : 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.25,
          shadows: _shadow,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 3),
        Text(
          subtitle!,
          textAlign: rightAligned ? TextAlign.right : TextAlign.start,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFFFFF4FB),
            shadows: _shadow,
          ),
        ),
      ],
    ],
  );
}

/// Round translucent button that stays legible over the illustration.
class SceneIconButton extends StatelessWidget {
  const SceneIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.showBackground = true,
  });
  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool showBackground;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(2),
    child: Material(
      color:
          showBackground
              ? const Color(0xFF211B50).withValues(alpha: .45)
              : Colors.transparent,
      shape: const CircleBorder(),
      child: IconButton(tooltip: tooltip, onPressed: onPressed, icon: icon),
    ),
  );
}
