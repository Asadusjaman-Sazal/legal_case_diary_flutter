/// A full-screen crop step for the profile picture and the chamber logo.
///
/// The picked image is shown in the shape the app will use — a circle for the
/// profile picture, the firm card's 148:100 rounded frame for the logo — with
/// everything outside that shape dimmed. Pinch zooms, dragging moves the
/// picture, and **Use** returns the selected area as a [CropRect] against the
/// normalized source. The caller then processes that rectangle at the target
/// aspect, so the stored image is exactly the area the user chose.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../data/avatar_image_processor.dart';

/// What the crop screen returns: its normalized source and the chosen rectangle.
class CropSelection {
  /// Creates a selection.
  const CropSelection({required this.source, required this.rect});

  /// The upright source the crop screen displayed.
  final CropSource source;

  /// The selected area in that source's pixels.
  final CropRect rect;
}

/// The crop page for one image.
class ImageCropScreen extends StatefulWidget {
  /// Creates the crop page.
  const ImageCropScreen({
    required this.source,
    required this.aspectRatio,
    required this.circular,
    required this.title,
    super.key,
  });

  /// The upright, downscaled image to crop.
  final CropSource source;

  /// Width divided by height of the area the app will show.
  final double aspectRatio;

  /// A circle (profile) rather than the logo's rounded rectangle.
  final bool circular;

  /// The page title, localized by the caller.
  final String title;

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  ui.Image? _image;
  bool _failed = false;

  /// The on-screen box the crop covers.
  Size _viewport = Size.zero;

  /// Scale at which the image exactly covers the viewport.
  double _coverScale = 1;
  double _scale = 1;
  Offset _offset = Offset.zero;
  bool _initialized = false;

  double _startScale = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;

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

  /// Sets the initial cover/centre whenever the viewport is first measured or
  /// changes shape. No `setState`: this runs from the build that needs it.
  void _ensureInitialized(Size viewport) {
    if (_initialized && _viewport == viewport) return;
    final image = _image;
    if (image == null) return;
    _viewport = viewport;
    _coverScale = math.max(
      viewport.width / image.width,
      viewport.height / image.height,
    );
    _scale = _coverScale;
    _offset = Offset(
      (viewport.width - image.width * _scale) / 2,
      (viewport.height - image.height * _scale) / 2,
    );
    _initialized = true;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _scale;
    _startOffset = _offset;
    _startFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size viewport) {
    final newScale = (_startScale * details.scale).clamp(
      _coverScale,
      _coverScale * 4,
    );
    final imagePoint = (_startOffset - _startFocal) / _startScale;
    final raw = details.localFocalPoint - imagePoint * newScale;
    final image = _image;
    if (image == null) return;
    final scaledWidth = image.width * newScale;
    final scaledHeight = image.height * newScale;
    setState(() {
      _scale = newScale;
      _offset = Offset(
        raw.dx.clamp(viewport.width - scaledWidth, 0.0),
        raw.dy.clamp(viewport.height - scaledHeight, 0.0),
      );
    });
  }

  /// Turns the visible viewport into a source-pixel rectangle and returns it.
  void _confirm() {
    final image = _image;
    if (image == null) return;
    final left = (-_offset.dx / _scale).clamp(0.0, image.width.toDouble());
    final top = (-_offset.dy / _scale).clamp(0.0, image.height.toDouble());
    final right = ((_viewport.width - _offset.dx) / _scale).clamp(
      0.0,
      image.width.toDouble(),
    );
    final bottom = ((_viewport.height - _offset.dy) / _scale).clamp(
      0.0,
      image.height.toDouble(),
    );
    final x = left.round().clamp(0, image.width - 1);
    final y = top.round().clamp(0, image.height - 1);
    final width = (right.round() - x).clamp(1, image.width - x);
    final height = (bottom.round() - y).clamp(1, image.height - y);

    Navigator.of(context).pop(
      CropSelection(
        source: widget.source,
        rect: CropRect(x: x, y: y, width: width, height: height),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          style: AppTypography.titleLg.copyWith(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l.sharedActions_cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _image == null || _failed ? null : _confirm,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text(
              l.imageCrop_use,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: _image == null
          ? Center(
              child: _failed
                  ? Text(
                      l.shared_avatarUnreadable,
                      style: AppTypography.bodyMd.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    )
                  : const CircularProgressIndicator(),
            )
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = math.max(constraints.maxWidth - 32, 1.0);
                  final maxHeight = math.max(constraints.maxHeight - 96, 1.0);
                  var width = maxWidth;
                  var height = width / widget.aspectRatio;
                  if (height > maxHeight) {
                    height = maxHeight;
                    width = height * widget.aspectRatio;
                  }
                  final viewport = Size(
                    math.max(width, 1),
                    math.max(height, 1),
                  );
                  _ensureInitialized(viewport);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: viewport.width,
                        height: viewport.height,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: (details) =>
                              _onScaleUpdate(details, viewport),
                          child: CustomPaint(
                            key: const ValueKey('image-crop-canvas'),
                            painter: _CropPainter(
                              image: _image!,
                              scale: _scale,
                              offset: _offset,
                              circular: widget.circular,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          l.imageCrop_hint,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySm.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

/// Paints the image under the crop, dims everything outside the crop shape,
/// and draws its border.
class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.image,
    required this.scale,
    required this.offset,
    required this.circular,
  });

  final ui.Image image;
  final double scale;
  final Offset offset;
  final bool circular;

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = Offset.zero & size;
    canvas.save();
    canvas.clipRect(viewport);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(
        offset.dx,
        offset.dy,
        image.width * scale,
        image.height * scale,
      ),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    final shape = circular
        ? (Path()..addOval(
            Rect.fromCircle(
              center: viewport.center,
              radius: math.min(size.width, size.height) / 2,
            ),
          ))
        : (Path()..addRRect(
            RRect.fromRectAndRadius(viewport, const Radius.circular(8)),
          ));
    final mask = Path()
      ..addRect(viewport)
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
  bool shouldRepaint(covariant _CropPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.scale != scale ||
      oldDelegate.offset != offset ||
      oldDelegate.circular != circular;
}
