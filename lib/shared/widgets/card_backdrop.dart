import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Lets a scene paint every card's glass background in one earlier layer,
/// so the character can sit between card backgrounds and card content.
class CardBackdropHost {
  final _slots = <RenderCardSlot>[];
  RenderCardBackdrops? _painter;

  void _add(RenderCardSlot slot) {
    _slots.add(slot);
    _changed();
  }

  void _remove(RenderCardSlot slot) {
    _slots.remove(slot);
    _changed();
  }

  void _changed() {
    final painter = _painter;
    if (painter != null && painter.attached) painter.markNeedsPaint();
  }
}

class CardBackdropScope extends InheritedWidget {
  const CardBackdropScope({
    super.key,
    required this.host,
    required super.child,
  });
  final CardBackdropHost host;

  static CardBackdropHost? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CardBackdropScope>()?.host;

  @override
  bool updateShouldNotify(CardBackdropScope oldWidget) =>
      oldWidget.host != host;
}

/// Wraps card content; its [decoration] is painted by [CardBackdrops].
class CardSlot extends SingleChildRenderObjectWidget {
  const CardSlot({
    super.key,
    required this.host,
    required this.decoration,
    super.child,
  });
  final CardBackdropHost host;
  final Decoration decoration;

  @override
  RenderCardSlot createRenderObject(BuildContext context) =>
      RenderCardSlot(host, decoration, createLocalImageConfiguration(context));

  @override
  void updateRenderObject(BuildContext context, RenderCardSlot renderObject) {
    renderObject
      ..host = host
      ..decoration = decoration
      ..configuration = createLocalImageConfiguration(context);
  }
}

class RenderCardSlot extends RenderProxyBox {
  RenderCardSlot(this._host, this._decoration, this._configuration);

  CardBackdropHost _host;
  set host(CardBackdropHost value) {
    if (value == _host) return;
    if (attached) _host._remove(this);
    _host = value;
    if (attached) _host._add(this);
  }

  Decoration _decoration;
  Decoration get decoration => _decoration;
  set decoration(Decoration value) {
    if (value == _decoration) return;
    _decoration = value;
    _host._changed();
  }

  ImageConfiguration _configuration;
  ImageConfiguration get configuration => _configuration;
  set configuration(ImageConfiguration value) {
    if (value == _configuration) return;
    _configuration = value;
    _host._changed();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _host._add(this);
  }

  @override
  void detach() {
    _host._remove(this);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    _host._changed();
  }
}

/// Paints the registered card backgrounds. Put it below the character.
class CardBackdrops extends LeafRenderObjectWidget {
  const CardBackdrops({super.key, required this.host});
  final CardBackdropHost host;

  @override
  RenderCardBackdrops createRenderObject(BuildContext context) =>
      RenderCardBackdrops(host);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCardBackdrops renderObject,
  ) => renderObject.host = host;
}

class RenderCardBackdrops extends RenderBox {
  RenderCardBackdrops(this._host);

  CardBackdropHost _host;
  set host(CardBackdropHost value) {
    if (value == _host) return;
    if (_host._painter == this) _host._painter = null;
    _host = value;
    if (attached) _host._painter = this;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _host._painter = this;
  }

  @override
  void detach() {
    if (_host._painter == this) _host._painter = null;
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final slot in _host._slots) {
      if (!slot.attached || !slot.hasSize) continue;
      final rect = MatrixUtils.transformRect(
        slot.getTransformTo(this),
        Offset.zero & slot.size,
      );
      final painter = slot.decoration.createBoxPainter();
      painter.paint(
        context.canvas,
        offset + rect.topLeft,
        slot.configuration.copyWith(size: rect.size),
      );
      painter.dispose();
    }
  }
}
