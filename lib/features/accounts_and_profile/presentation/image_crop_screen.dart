/// The "Select Image" page for the profile picture and the firm logo.
///
/// The picked image is shown whole, on black, under a frame in the shape the
/// app will use — a circle for the profile picture, the firm card's 148:100
/// rounded rectangle for the logo. Dragging moves that frame over the image and
/// dragging a corner resizes it (down to the 512 px the stored picture needs);
/// everything outside it is dimmed. A rotate button turns the image a quarter
/// clockwise, and Save returns the frame's area (in the rotated image) so the
/// caller stores exactly what the user selected.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../data/avatar_image_processor.dart';

/// What the selection page returns.
class CropSelection {
  /// Creates a selection.
  const CropSelection({
    required this.source,
    required this.rect,
    this.rotationQuarterTurns = 0,
  });

  /// The upright source the page displayed.
  final CropSource source;

  /// The selected area, in the **rotated** image's pixels.
  final CropRect rect;

  /// Quarter turns clockwise the user applied with the rotate button.
  final int rotationQuarterTurns;
}

/// The selection page for one image.
class ImageCropScreen extends StatefulWidget {
  /// Creates the page.
  const ImageCropScreen({
    required this.source,
    required this.aspectRatio,
    required this.circular,
    required this.title,
    this.minSourceSide = 512,
    super.key,
  });

  /// The upright, downscaled image to select from.
  final CropSource source;

  /// Width divided by height of the frame the app will show.
  final double aspectRatio;

  /// A circle (profile) rather than the logo's rounded rectangle.
  final bool circular;

  /// The page title, localized by the caller.
  final String title;

  /// The smallest selected side, in source pixels, that still feeds the stored
  /// target without upscaling — the 512 px avatar/logo.
  final int minSourceSide;

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

/// Where the image and its frame sit on screen.
class _CropLayout {
  const _CropLayout({
    required this.display,
    required this.scale,
    required this.rotatedWidth,
    required this.rotatedHeight,
    required this.frameSize,
    required this.center,
    required this.minFrameWidth,
    required this.maxFrameWidth,
  });

  /// The image's rectangle on screen, after rotation.
  final Rect display;

  /// Source pixels to screen pixels.
  final double scale;

  /// The image's dimensions after the current quarter turns.
  final int rotatedWidth;
  final int rotatedHeight;

  /// The frame's current size on screen.
  final Size frameSize;

  /// The frame's centre on screen.
  final Offset center;

  /// The smallest frame width the 512 px target can be fed from, and the
  /// largest that fits the image.
  final double minFrameWidth;
  final double maxFrameWidth;

  Rect get frameRect => Rect.fromCenter(
    center: center,
    width: frameSize.width,
    height: frameSize.height,
  );

  double get minCenterX => display.left + frameSize.width / 2;
  double get maxCenterX => display.right - frameSize.width / 2;
  double get minCenterY => display.top + frameSize.height / 2;
  double get maxCenterY => display.bottom - frameSize.height / 2;
}

/// Which corner a resize drag belongs to.
enum _CropCorner { topLeft, topRight, bottomLeft, bottomRight }

class _ImageCropScreenState extends State<ImageCropScreen> {
  ui.Image? _image;
  bool _failed = false;

  /// Quarter turns clockwise, 0..3.
  int _turns = 0;

  Offset? _frameCenter;

  /// The frame's current width on screen; null until the first layout, when it
  /// starts at the largest size that fits.
  double? _frameWidth;
  _CropLayout? _layout;

  final GlobalKey _stackKey = GlobalKey();
  Offset? _resizeAnchor;
  _CropCorner? _resizeCorner;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.source.bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  /// Measures the image and the frame for [available], and clamps the existing
  /// frame size and centre into the new display.
  void _ensureLayout(Size available) {
    final image = _image;
    if (image == null) return;
    final rotatedWidth = _turns.isOdd ? image.height : image.width;
    final rotatedHeight = _turns.isOdd ? image.width : image.height;

    final inner = (Offset.zero & available).deflate(16);
    final scale = math.min(
      inner.width / rotatedWidth,
      inner.height / rotatedHeight,
    );
    final display = Rect.fromCenter(
      center: Offset(available.width / 2, available.height / 2),
      width: rotatedWidth * scale,
      height: rotatedHeight * scale,
    );

    // The largest frame of the target ratio that fits inside the displayed
    // image, with a little breathing room for the corner handles.
    final maxWidth = math.max(display.width - 24, 1.0);
    final maxHeight = math.max(display.height - 24, 1.0);
    var maxFrameWidth = maxWidth;
    if (maxFrameWidth / widget.aspectRatio > maxHeight) {
      maxFrameWidth = maxHeight * widget.aspectRatio;
    }
    maxFrameWidth = math.max(maxFrameWidth, 1.0);
    // Never below the source pixels the stored 512 px picture needs; a smaller
    // image simply caps at its own size.
    final minFrameWidth = math.min(
      maxFrameWidth,
      math.max(widget.minSourceSide * scale, 1.0),
    );
    final frameWidth = (_frameWidth ?? maxFrameWidth).clamp(
      minFrameWidth,
      maxFrameWidth,
    );
    final frameHeight = frameWidth / widget.aspectRatio;
    final frameSize = Size(frameWidth, math.max(frameHeight, 1.0));

    final previous = _frameCenter ?? display.center;
    final center = Offset(
      previous.dx.clamp(
        display.left + frameSize.width / 2,
        display.right - frameSize.width / 2,
      ),
      previous.dy.clamp(
        display.top + frameSize.height / 2,
        display.bottom - frameSize.height / 2,
      ),
    );
    _frameWidth = frameWidth;
    _frameCenter = center;
    _layout = _CropLayout(
      display: display,
      scale: scale,
      rotatedWidth: rotatedWidth,
      rotatedHeight: rotatedHeight,
      frameSize: frameSize,
      center: center,
      minFrameWidth: minFrameWidth,
      maxFrameWidth: maxFrameWidth,
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final layout = _layout;
    final center = _frameCenter;
    if (layout == null || center == null) return;
    final next = center + details.delta;
    setState(() {
      _frameCenter = Offset(
        next.dx.clamp(layout.minCenterX, layout.maxCenterX),
        next.dy.clamp(layout.minCenterY, layout.maxCenterY),
      );
    });
  }

  void _onResizeStart(_CropCorner corner) {
    final layout = _layout;
    if (layout == null) return;
    // The opposite corner stays put so the frame grows or shrinks from the
    // corner the user grabbed.
    final frame = layout.frameRect;
    _resizeAnchor = switch (corner) {
      _CropCorner.topLeft => frame.bottomRight,
      _CropCorner.topRight => frame.bottomLeft,
      _CropCorner.bottomLeft => frame.topRight,
      _CropCorner.bottomRight => frame.topLeft,
    };
    _resizeCorner = corner;
  }

  void _onResizeUpdate(DragUpdateDetails details) {
    final layout = _layout;
    final anchor = _resizeAnchor;
    final corner = _resizeCorner;
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (layout == null || anchor == null || corner == null || box == null) {
      return;
    }
    final pointer = box.globalToLocal(details.globalPosition);
    final growsRight =
        corner == _CropCorner.topRight || corner == _CropCorner.bottomRight;
    final growsDown =
        corner == _CropCorner.topLeft || corner == _CropCorner.bottomRight;
    final signX = growsRight ? 1.0 : -1.0;
    final signY = growsDown ? 1.0 : -1.0;

    // The frame cannot leave the image: cap the width at the room left between
    // the fixed corner and the image edge, in both directions.
    final roomX = growsRight
        ? layout.display.right - anchor.dx
        : anchor.dx - layout.display.left;
    final roomY = growsDown
        ? layout.display.bottom - anchor.dy
        : anchor.dy - layout.display.top;
    final maxWidth = math.min(
      layout.maxFrameWidth,
      math.min(roomX, roomY * widget.aspectRatio),
    );
    final minWidth = math.min(layout.minFrameWidth, maxWidth);

    // Fixed ratio: the corner follows the larger of the two drag components.
    final requested = math.max(
      (pointer.dx - anchor.dx) * signX,
      (pointer.dy - anchor.dy) * signY * widget.aspectRatio,
    );
    final width = requested.clamp(minWidth, maxWidth);
    final height = width / widget.aspectRatio;

    setState(() {
      _frameWidth = width;
      _frameCenter = Offset(
        anchor.dx + signX * width / 2,
        anchor.dy + signY * height / 2,
      );
    });
  }

  void _rotate() {
    setState(() {
      _turns = (_turns + 1) % 4;
      // A new orientation starts from the largest frame that fits it.
      _frameWidth = null;
      _layout = null;
    });
  }

  void _save() {
    final layout = _layout;
    if (layout == null) return;
    final frame = layout.frameRect;
    final left = ((frame.left - layout.display.left) / layout.scale).clamp(
      0.0,
      layout.rotatedWidth.toDouble(),
    );
    final top = ((frame.top - layout.display.top) / layout.scale).clamp(
      0.0,
      layout.rotatedHeight.toDouble(),
    );
    final right = ((frame.right - layout.display.left) / layout.scale).clamp(
      0.0,
      layout.rotatedWidth.toDouble(),
    );
    final bottom = ((frame.bottom - layout.display.top) / layout.scale).clamp(
      0.0,
      layout.rotatedHeight.toDouble(),
    );
    final x = left.round().clamp(0, layout.rotatedWidth - 1);
    final y = top.round().clamp(0, layout.rotatedHeight - 1);
    final width = (right.round() - x).clamp(1, layout.rotatedWidth - x);
    final height = (bottom.round() - y).clamp(1, layout.rotatedHeight - y);

    Navigator.of(context).pop(
      CropSelection(
        source: widget.source,
        rect: CropRect(x: x, y: y, width: width, height: height),
        rotationQuarterTurns: _turns,
      ),
    );
  }

  /// A drag handle centred on one [corner] of the frame, with a 44 px touch
  /// area around the small visible dot.
  Widget _cornerHandle(_CropCorner corner, Rect frame) {
    const touchSize = 44.0;
    final center = switch (corner) {
      _CropCorner.topLeft => frame.topLeft,
      _CropCorner.topRight => frame.topRight,
      _CropCorner.bottomLeft => frame.bottomLeft,
      _CropCorner.bottomRight => frame.bottomRight,
    };
    return Positioned(
      left: center.dx - touchSize / 2,
      top: center.dy - touchSize / 2,
      width: touchSize,
      height: touchSize,
      child: GestureDetector(
        key: ValueKey('image-crop-handle-${corner.name}'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _onResizeStart(corner),
        onPanUpdate: _onResizeUpdate,
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final image = _image;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          widget.title,
          style: AppTypography.titleLg.copyWith(color: Colors.white),
        ),
      ),
      body: image == null
          ? Center(
              child: _failed
                  ? Text(
                      l.shared_avatarUnreadable,
                      style: AppTypography.bodyMd.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    )
                  : const CircularProgressIndicator(),
            )
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _ensureLayout(constraints.biggest);
                      final layout = _layout!;
                      final frame = layout.frameRect;
                      return Stack(
                        key: _stackKey,
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: _onPanUpdate,
                              child: CustomPaint(
                                key: const ValueKey('image-crop-canvas'),
                                painter: _CropPainter(
                                  image: image,
                                  turns: _turns,
                                  layout: layout,
                                  circular: widget.circular,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                          for (final corner in _CropCorner.values)
                            _cornerHandle(corner, frame),
                        ],
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              child: Text(l.sharedActions_cancel),
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('image-crop-rotate'),
                          tooltip: l.imageCrop_rotate,
                          onPressed: _rotate,
                          icon: const Icon(
                            Icons.rotate_right,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: const ValueKey('image-crop-save'),
                              onPressed: _save,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              child: Text(l.imageCrop_save),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Draws the rotated image, dims everything outside the fixed frame, and draws
/// the frame's border.
class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.image,
    required this.turns,
    required this.layout,
    required this.circular,
  });

  final ui.Image image;
  final int turns;
  final _CropLayout layout;
  final bool circular;

  @override
  void paint(Canvas canvas, Size size) {
    final display = layout.display;
    canvas.save();
    canvas.translate(display.center.dx, display.center.dy);
    canvas.rotate(turns * math.pi / 2);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(
        center: Offset.zero,
        width: image.width * layout.scale,
        height: image.height * layout.scale,
      ),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    final frame = layout.frameRect;
    final shape = circular
        ? (Path()..addOval(
            Rect.fromCircle(
              center: frame.center,
              radius: math.min(frame.width, frame.height) / 2,
            ),
          ))
        : (Path()..addRRect(
            RRect.fromRectAndRadius(frame, const Radius.circular(8)),
          ));
    final mask = Path()
      ..addRect(display)
      ..addPath(shape, Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      mask,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) => true;
}
