import 'dart:math';

import 'package:flutter_web/material.dart';
import 'package:flutter_web/rendering.dart';

// Developed by Marcelo Glasberg (copyright Aug 2019)

/// The container will ask the [child] to define its own height, and [ifFitsHeight]
/// is true the child will be proportionately resized to fit the height.
/// Otherwise (the default), it will keep its own height.
///
/// Then, if the child doesn't fit the width, it will be shrinked horizontally
/// until if fits, unless [shrinkLimit] is larger than zero, in which case it
/// will shrink only until that limit. Note if [shrinkLimit] is 1.0 the child
/// will not shrink at all. The default [shrinkLimit] is 0.67 (67%).
///
/// This is specially usefull for text that is displayed in a single line.
/// When text doesn't fit the container it will shrink only horizontally,
/// until it reaches the shrink limit. From that point on it will clip,
/// display ellipsis or fade, according to its [Text.overflow] property.
///
class HorizontalFitBox extends SingleChildRenderObjectWidget {
  const HorizontalFitBox({
    Key key,
    this.shrinkLimit = defaultShrinkLimit,
    this.ifFitsHeight = false,
    this.alignment = Alignment.center,
    Widget child,
  })  : assert(shrinkLimit != null && shrinkLimit <= 1.0),
        assert(alignment != null),
        super(key: key, child: child);

  // May shrink down to 67% of its original size.
  static const defaultShrinkLimit = 0.67;

  final double shrinkLimit;

  final bool ifFitsHeight;

  final AlignmentGeometry alignment;

  @override
  _RenderFittedBox createRenderObject(BuildContext context) {
    return _RenderFittedBox(
      shrinkLimit: shrinkLimit,
      ifFitsHeight: ifFitsHeight,
      alignment: alignment,
      textDirection: Directionality.of(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderFittedBox renderObject) {
    renderObject
      ..shrinkLimit = shrinkLimit
      ..ifFitsHeight = ifFitsHeight
      ..alignment = alignment
      ..textDirection = Directionality.of(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<double>('shrinkLimit', shrinkLimit));
    properties.add(EnumProperty<bool>('ifFitsHeight', ifFitsHeight));
    properties.add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
  }
}

class _RenderFittedBox extends RenderProxyBox {
  /// Scales and positions its child within itself.
  ///
  /// The [fit] and [alignment] arguments must not be null.
  _RenderFittedBox({
    double shrinkLimit = HorizontalFitBox.defaultShrinkLimit,
    bool ifFitsHeight = false,
    AlignmentGeometry alignment = Alignment.center,
    TextDirection textDirection,
    RenderBox child,
  })  : assert(shrinkLimit != null && shrinkLimit <= 1.0),
        assert(ifFitsHeight != null),
        assert(alignment != null),
        _shrinkLimit = shrinkLimit,
        _ifFitsHeight = ifFitsHeight,
        _alignment = alignment,
        _textDirection = textDirection,
        super(child);

  Alignment _resolvedAlignment;

  double shrink;

  void _resolve() {
    if (_resolvedAlignment != null) return;
    _resolvedAlignment = alignment.resolve(textDirection);
  }

  void _markNeedResolution() {
    _resolvedAlignment = null;
    markNeedsPaint();
  }

  /// How to inscribe the child into the space allocated during layout.
  double get shrinkLimit => _shrinkLimit;
  double _shrinkLimit;

  set shrinkLimit(double value) {
    assert(value != null);
    if (_shrinkLimit == value) return;
    _shrinkLimit = value;
    _clearPaintData();
    markNeedsPaint();
  }

  /// How to inscribe the child into the space allocated during layout.
  bool get ifFitsHeight => _ifFitsHeight;
  bool _ifFitsHeight;

  set ifFitsHeight(bool value) {
    assert(value != null);
    if (_ifFitsHeight == value) return;
    _ifFitsHeight = value;
    _clearPaintData();
    markNeedsPaint();
  }

  /// How to align the child within its parent's bounds.
  ///
  /// An alignment of (0.0, 0.0) aligns the child to the top-left corner of its
  /// parent's bounds. An alignment of (1.0, 0.5) aligns the child to the middle
  /// of the right edge of its parent's bounds.
  ///
  /// If this is set to an [AlignmentDirectional] object, then
  /// [textDirection] must not be null.
  AlignmentGeometry get alignment => _alignment;
  AlignmentGeometry _alignment;

  set alignment(AlignmentGeometry value) {
    assert(value != null);
    if (_alignment == value) return;
    _alignment = value;
    _clearPaintData();
    _markNeedResolution();
  }

  /// The text direction with which to resolve [alignment].
  ///
  /// This may be changed to null, but only after [alignment] has been changed
  /// to a value that does not depend on the direction.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;

  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    _clearPaintData();
    _markNeedResolution();
  }

  @override
  void performLayout() {
    if (child != null) {
      //

      if (_ifFitsHeight) {
        // Special case when shrinkLimit is 1.0, we can calculate faster.
        if (shrinkLimit == 1.0) {
          double intrinsicHeight = child.getMinIntrinsicHeight(constraints.maxWidth);
          double width = constraints.maxWidth / constraints.maxHeight * intrinsicHeight;

          child.layout(BoxConstraints(maxWidth: width, maxHeight: intrinsicHeight),
              parentUsesSize: true);
        }
        // But it's slower if there's shrink, since we also need intrinsicWidth.
        else {
          double intrinsicWidth = child.getMinIntrinsicWidth(double.infinity);
          double intrinsicHeight = child.getMinIntrinsicHeight(constraints.maxWidth);

          // ---

          shrink =
              ((constraints.maxWidth / constraints.maxHeight) * intrinsicHeight) / intrinsicWidth;

          if (shrink > shrinkLimit)
            child.layout(BoxConstraints(maxWidth: intrinsicWidth, maxHeight: intrinsicHeight),
                parentUsesSize: true);
          else
            child.layout(
                BoxConstraints(
                    maxWidth: (intrinsicHeight * constraints.maxWidth / constraints.maxHeight) /
                        shrinkLimit,
                    maxHeight: intrinsicHeight),
                parentUsesSize: true);
        }
      }

      // Should NOT scaleVertically (_ifFitsHeight = false).
      else {
        // Special case when shrinkLimit is 1.0, we can calculate faster.
        if (shrinkLimit == 1.0) {
          // Note: There must be a 1.0 pixel clearance to maxHeight,
          // because the Text widget may create a phantom fade otherwise.
          child.layout(
              BoxConstraints(
                  maxWidth: constraints.maxWidth, maxHeight: constraints.maxHeight + 1.0),
              parentUsesSize: true);
        }
        // But it's slower if there's shrink, since we also need intrinsicWidth.
        else {
          double intrinsicWidth = child.getMinIntrinsicWidth(double.infinity);

          shrink = constraints.maxWidth / intrinsicWidth;

          // Note: There must be a 1.0 pixel clearance to maxHeight,
          // because the Text widget may create a phantom fade otherwise.
          child.layout(
              BoxConstraints(
                  maxWidth: constraints.maxWidth / max(shrinkLimit, min(shrink, 1.0)),
                  maxHeight: constraints.maxHeight + 1.0),
              parentUsesSize: true);
        }
      }
      // ---

      size = (child.size.width == 0 || child.size.height == 0)
          ? Size(constraints.minWidth, constraints.minHeight)
          : constraints.constrainSizeAndAttemptToPreserveAspectRatio(child.size);

      _clearPaintData();
    }
    //
    else {
      size = constraints.smallest;
    }
  }

  static FittedSizes _applyBoxFit(
    Size inputSize,
    Size outputSize,
    double shrink,
    double shrinkLimit,
    bool ifFitsHeight,
  ) {
    if (inputSize.height <= 0.0 ||
        inputSize.width <= 0.0 ||
        outputSize.height <= 0.0 ||
        outputSize.width <= 0.0) return const FittedSizes(Size.zero, Size.zero);

    Size sourceSize, destinationSize;

    if (ifFitsHeight) {
      if (shrinkLimit == 1.0) {
        sourceSize = inputSize;
        destinationSize =
            Size(sourceSize.width * outputSize.height / sourceSize.height, outputSize.height);
      } else {
        sourceSize = inputSize;
        destinationSize = Size(
            sourceSize.width *
                outputSize.height /
                sourceSize.height *
                max(shrinkLimit, min(shrink, 1.0)),
            outputSize.height);
      }
    }

    // Should NOT scaleVertically.
    else {
      if (shrinkLimit == 1.0) {
        sourceSize = inputSize;
        destinationSize = sourceSize;
      } else {
        sourceSize = inputSize;
        destinationSize =
            Size(inputSize.width * max(shrinkLimit, min(shrink, 1.0)), inputSize.height);
      }
    }

    return FittedSizes(sourceSize, destinationSize);
  }

  bool _hasVisualOverflow;
  Matrix4 _transform;

  void _clearPaintData() {
    _hasVisualOverflow = null;
    _transform = null;
  }

  void _updatePaintData() {
    if (_transform != null) return;

    if (child == null) {
      _hasVisualOverflow = false;
      _transform = Matrix4.identity();
    } else {
      _resolve();
      final Size childSize = child.size;
      final FittedSizes sizes = _applyBoxFit(childSize, size, shrink, shrinkLimit, _ifFitsHeight);
      final double scaleX = sizes.destination.width / sizes.source.width;
      final double scaleY = sizes.destination.height / sizes.source.height;
      final Rect sourceRect = _resolvedAlignment.inscribe(sizes.source, Offset.zero & childSize);
      final Rect destinationRect =
          _resolvedAlignment.inscribe(sizes.destination, Offset.zero & size);
      _hasVisualOverflow =
          sourceRect.width < childSize.width || sourceRect.height < childSize.height;
      assert(scaleX.isFinite && scaleY.isFinite);
      _transform = Matrix4.translationValues(destinationRect.left, destinationRect.top, 0.0)
        ..scale(scaleX, scaleY, 1.0)
        ..translate(-sourceRect.left, -sourceRect.top);
      assert(_transform.storage.every((double value) => value.isFinite));
    }
  }

  void _paintChildWithTransform(PaintingContext context, Offset offset) {
    final Offset childOffset = MatrixUtils.getAsTranslation(_transform);
    if (childOffset == null)
      context.pushTransform(needsCompositing, offset, _transform, super.paint);
    else
      super.paint(context, offset + childOffset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty || child.size.isEmpty) return;
    _updatePaintData();
    if (child != null) {
      if (_hasVisualOverflow)
        context.pushClipRect(
            needsCompositing, offset, Offset.zero & size, _paintChildWithTransform);
      else
        _paintChildWithTransform(context, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {Offset position}) {
    if (size.isEmpty) return false;
    _updatePaintData();
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) {
        return super.hitTestChildren(result, position: position);
      },
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (size.isEmpty) {
      transform.setZero();
    } else {
      _updatePaintData();
      transform.multiply(_transform);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<double>('shrink', shrink));
    properties.add(EnumProperty<double>('shrinkLimit', shrinkLimit));
    properties.add(DiagnosticsProperty<Alignment>('alignment', alignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection, defaultValue: null));
  }
}
