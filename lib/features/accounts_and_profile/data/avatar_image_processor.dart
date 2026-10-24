/// The shared 50 KB avatar pipeline, for profile pictures and chamber logos.
///
/// Every stored avatar is a 512 px square JPEG under [avatarMaxBytes], so a
/// private storage bucket can enforce one small file size for every account.
/// The re-encode also drops EXIF, which is where a phone photo carries its GPS
/// position, and bakes the orientation in so a sideways photo shows upright.
///
/// Decoding runs in an isolate: a modern phone camera produces 12 million
/// pixels, and doing that on the UI isolate would visibly stall the screen.
library;

import 'dart:isolate';
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
