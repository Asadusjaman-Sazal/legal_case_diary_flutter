/// The shared 50 KB avatar pipeline, for profile pictures and chamber logos.
///
/// A profile picture is a 512 px square JPEG; a chamber logo is the firm card
/// frame's 512 x 346 (148:100). Both stay under [avatarMaxBytes], so a private
/// storage bucket can enforce one small file size for every account. The
/// re-encode also drops EXIF, which is where a phone photo carries its GPS
/// position, and bakes the orientation in so a sideways photo shows upright.
///
/// Decoding runs in an isolate: a modern phone camera produces 12 million
/// pixels, and doing that on the UI isolate would visibly stall the screen.
library;

import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The hard cap for a stored avatar, in bytes (50 KB).
///
/// The Supabase bucket repeats this number; the client is the polite half, the
/// bucket is the boundary.
const int avatarMaxBytes = 50 * 1024;

/// The longest side an avatar is stored at, in pixels.
///
/// The largest place an avatar is drawn is a 96 px circle on a high-density
/// screen, so 512 leaves room for a future larger use without ever being the
/// reason a file is too big.
const int avatarMaxSide = 512;

/// Why an image could not become an avatar.
class AvatarImageException implements Exception {
  /// The source could not be decoded (an unconverted HEIC, a corrupt file, or
  /// bytes that are not an image at all).
  const AvatarImageException.unreadable();

  @override
  String toString() => 'AvatarImageException: the picture could not be read';
}

/// Resizes, crops and re-encodes [source] into an avatar JPEG.
///
/// Throws [AvatarImageException] when the bytes are not a decodable image. The
/// returned bytes are always at most [avatarMaxBytes]: the quality steps walk
/// down and the final step shrinks to 256 px, which fits even noise.
Future<Uint8List> processAvatar(Uint8List source) async {
  final Uint8List? result;
  try {
    result = await Isolate.run(() => _process(source));
  } on Object {
    throw const AvatarImageException.unreadable();
  }
  if (result == null) throw const AvatarImageException.unreadable();
  return result;
}

/// The isolate's half: null means "this is not an image we can use".
Uint8List? _process(Uint8List source) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(source);
  } on Object {
    return null;
  }
  if (decoded == null) return null;

  var square = img.copyResizeCropSquare(
    img.bakeOrientation(decoded),
    size: avatarMaxSide,
    interpolation: img.Interpolation.average,
  );
  // JPEG has no alpha, and leaving a transparent PNG alone would encode its
  // empty pixels as black. White is what a photo's background would be.
  if (square.hasAlpha) {
    final canvas = img.Image(
      width: avatarMaxSide,
      height: avatarMaxSide,
      numChannels: 3,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, square);
    square = canvas;
  }

  // Each step is encoded from the same decoded picture, so a lower quality
  // never compounds the previous step's artifacts.
  for (final (side, quality) in const <(int, int)>[
    (avatarMaxSide, 85),
    (avatarMaxSide, 70),
    (448, 60),
    (384, 50),
    (320, 40),
    (256, 35),
  ]) {
    final sized = side == avatarMaxSide
        ? square
        : img.copyResizeCropSquare(
            square,
            size: side,
            interpolation: img.Interpolation.average,
          );
    final bytes = img.encodeJpg(sized, quality: quality);
    if (bytes.length <= avatarMaxBytes) return bytes;
  }
  return null;
}

/// An upright, downscaled copy of a picked image, ready for the crop screen.
///
/// The bytes are a JPEG with the EXIF orientation already baked in, so the
/// rectangle the user selects on screen is the rectangle the processor crops.
class CropSource {
  /// Creates a crop source.
  const CropSource({
    required this.bytes,
    required this.width,
    required this.height,
  });

  /// The normalized JPEG the crop screen draws and the processor crops.
  final Uint8List bytes;

  /// Its width in pixels.
  final int width;

  /// Its height in pixels.
  final int height;
}

/// A selected area, in [CropSource] pixels.
class CropRect {
  /// Creates a crop rectangle.
  const CropRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Left edge.
  final int x;

  /// Top edge.
  final int y;

  /// Width; at least 1.
  final int width;

  /// Height; at least 1.
  final int height;
}

/// The longest side kept for the crop screen.
///
/// The picker already caps its output at 1024 px; this is the guard for a
/// source that arrives another way. The final avatar is at most 512, so nothing
/// a person can select needs more.
const int _cropDisplayMaxSide = 1600;

/// Reads a picked image upright and downscaled for the crop screen.
///
/// Throws [AvatarImageException] when the bytes are not a decodable image.
Future<CropSource> prepareCropSource(Uint8List source) async {
  CropSource? result;
  try {
    result = await Isolate.run(() => _prepareCropSource(source));
  } on Object {
    throw const AvatarImageException.unreadable();
  }
  if (result == null) throw const AvatarImageException.unreadable();
  return result;
}

CropSource? _prepareCropSource(Uint8List source) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(source);
  } on Object {
    return null;
  }
  if (decoded == null) return null;

  var upright = img.bakeOrientation(decoded);
  final longSide = math.max(upright.width, upright.height);
  if (longSide > _cropDisplayMaxSide) {
    final scale = _cropDisplayMaxSide / longSide;
    upright = img.copyResize(
      upright,
      width: (upright.width * scale).round(),
      height: (upright.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }
  // JPEG has no alpha; flatten now, so the crop preview already shows the white
  // background the final picture will have.
  if (upright.hasAlpha) {
    final canvas = img.Image(
      width: upright.width,
      height: upright.height,
      numChannels: 3,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, upright);
    upright = canvas;
  }
  return CropSource(
    bytes: img.encodeJpg(upright, quality: 90),
    width: upright.width,
    height: upright.height,
  );
}

/// Crops [source] to [rect] and encodes a [targetWidth] x [targetHeight] JPEG.
///
/// The profile picture passes a square target; the firm logo passes the
/// 148:100 frame's ratio, so the selected area is exactly what the frame shows.
/// The bytes are at most [avatarMaxBytes], by the same quality/size ladder as
/// [processAvatar].
Future<Uint8List> processCroppedImage(
  CropSource source,
  CropRect rect, {
  required int targetWidth,
  required int targetHeight,
  int rotationQuarterTurns = 0,
}) async {
  if (targetWidth < 1 || targetHeight < 1) {
    throw const AvatarImageException.unreadable();
  }
  final turns = rotationQuarterTurns % 4;
  // The rectangle is in the rotated image's pixels, so the clamp uses the
  // dimensions that image will have after the rotation.
  final rotatedWidth = turns.isOdd ? source.height : source.width;
  final rotatedHeight = turns.isOdd ? source.width : source.height;
  final x = rect.x.clamp(0, rotatedWidth - 1);
  final y = rect.y.clamp(0, rotatedHeight - 1);
  final width = rect.width.clamp(1, rotatedWidth - x);
  final height = rect.height.clamp(1, rotatedHeight - y);

  final Uint8List? result;
  try {
    result = await Isolate.run(
      () => _processCropped(
        source.bytes,
        x: x,
        y: y,
        width: width,
        height: height,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        turns: turns,
      ),
    );
  } on Object {
    throw const AvatarImageException.unreadable();
  }
  if (result == null) throw const AvatarImageException.unreadable();
  return result;
}

Uint8List? _processCropped(
  Uint8List source, {
  required int x,
  required int y,
  required int width,
  required int height,
  required int targetWidth,
  required int targetHeight,
  required int turns,
}) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(source);
  } on Object {
    return null;
  }
  if (decoded == null) return null;

  var upright = decoded;
  for (var i = 0; i < turns; i++) {
    upright = _rotateClockwise(upright);
  }
  final cropped = img.copyCrop(
    upright,
    x: x,
    y: y,
    width: width,
    height: height,
  );
  var image = img.copyResize(
    cropped,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.average,
  );
  if (image.hasAlpha) {
    final canvas = img.Image(
      width: targetWidth,
      height: targetHeight,
      numChannels: 3,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, image);
    image = canvas;
  }

  // The same ladder as the square avatar: the first step that fits the bucket
  // wins, and every step is encoded from the same resized picture.
  for (final (scale, quality) in const <(double, int)>[
    (1, 85),
    (1, 70),
    (0.875, 60),
    (0.75, 50),
    (0.625, 40),
    (0.5, 35),
  ]) {
    final w = (targetWidth * scale).round().clamp(1, targetWidth);
    final h = (targetHeight * scale).round().clamp(1, targetHeight);
    final sized = w == targetWidth && h == targetHeight
        ? image
        : img.copyResize(
            image,
            width: w,
            height: h,
            interpolation: img.Interpolation.average,
          );
    final bytes = img.encodeJpg(sized, quality: quality);
    if (bytes.length <= avatarMaxBytes) return bytes;
  }
  return null;
}

/// Rotates [source] a quarter turn clockwise.
///
/// The screen's canvas uses the same clockwise convention, so the rectangle a
/// person selects on the rotated preview is the rectangle this crops.
img.Image _rotateClockwise(img.Image source) {
  final out = img.Image(
    width: source.height,
    height: source.width,
    numChannels: source.numChannels,
  );
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      out.setPixel(source.height - 1 - y, x, source.getPixel(x, y));
    }
  }
  return out;
}
