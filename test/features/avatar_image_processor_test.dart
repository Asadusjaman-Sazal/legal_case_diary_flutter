/// The shared 50 KB avatar pipeline.
///
/// The promise is narrow and testable: whatever the camera produced, the stored
/// picture is a square JPEG no larger than 50 KB, metadata gone. Noise is the
/// worst case for JPEG, so one case starts from a deliberately hostile image.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:legal_case_diary/features/accounts_and_profile/data/avatar_image_processor.dart';

/// A deterministic, highly detailed image — the opposite of a smooth photo.
img.Image _noise(int width, int height) {
  final random = math.Random(7);
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    pixel
      ..r = random.nextInt(256)
      ..g = random.nextInt(256)
      ..b = random.nextInt(256);
  }
  return image;
}

/// A smooth image, which compresses like a real photograph.
img.Image _gradient(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixel(
        x,
        y,
        img.ColorRgb8(x * 255 ~/ width, y * 255 ~/ height, 128),
      );
    }
  }
  return image;
}

void main() {
  test('a noisy photo becomes a 512 square JPEG under 50 KB', () async {
    final source = img.encodeJpg(_noise(900, 600), quality: 95);

    final bytes = await processAvatar(source);

    expect(bytes.length, lessThanOrEqualTo(avatarMaxBytes));
    // JPEG magic, so the bucket's image/jpeg rule and the file extension agree.
    expect(bytes.sublist(0, 2), <int>[0xFF, 0xD8]);
    final decoded = img.decodeJpg(bytes)!;
    // Noise cannot fit 512 px in 50 KB, so the pipeline is allowed to step the
    // side down; it may never exceed 512, and it never goes above the cap.
    expect(decoded.width, decoded.height);
    expect(decoded.width, lessThanOrEqualTo(avatarMaxSide));
  });

  test('a portrait picture is centre-cropped to a square at 512', () async {
    final source = img.encodeJpg(_gradient(600, 900));

    final bytes = await processAvatar(source);

    final decoded = img.decodeJpg(bytes)!;
    expect(decoded.width, decoded.height);
    expect(decoded.width, avatarMaxSide);
  });

  test('a transparent PNG is flattened onto white, not black', () async {
    final transparent = img.Image(width: 300, height: 300, numChannels: 4);
    img.fill(transparent, color: img.ColorRgba8(0, 0, 0, 0));

    final bytes = await processAvatar(img.encodePng(transparent));

    final decoded = img.decodeJpg(bytes)!;
    expect(decoded.numChannels, 3);
    final corner = decoded.getPixel(0, 0);
    expect(corner.r, greaterThan(230));
    expect(corner.g, greaterThan(230));
    expect(corner.b, greaterThan(230));
  });

  test('a tiny picture is still stored as a 512 square', () async {
    final bytes = await processAvatar(img.encodeJpg(_gradient(64, 64)));

    expect(bytes.length, lessThanOrEqualTo(avatarMaxBytes));
    final decoded = img.decodeJpg(bytes)!;
    expect(decoded.width, avatarMaxSide);
  });

  test('bytes that are not an image are refused', () async {
    await expectLater(
      processAvatar(Uint8List.fromList(<int>[1, 2, 3, 4, 5])),
      throwsA(isA<AvatarImageException>()),
    );
  });
}
