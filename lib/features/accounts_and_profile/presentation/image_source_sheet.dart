/// The two ways into an image: the phone's gallery, or the file manager.
///
/// The system gallery is another app, so it cannot carry our own Files button.
/// Edit therefore opens this small chooser: **Gallery** opens the phone's
/// gallery app on Android (the photo library on iOS), and the **Files** action
/// at the bottom right opens the file manager filtered to images. Both return
/// bytes; the caller prepares and crops them.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';

enum _PictureSource { gallery, files }

/// The host's gallery picker (`MainActivity.configureGalleryChannel`).
///
/// `image_picker`'s Android gallery path can land in the document picker, whose
/// UI is the phone's file manager; `ACTION_PICK` always opens the installed
/// gallery app.
const MethodChannel _galleryChannel = MethodChannel(
  'com.legumsoft.legalcasediary/gallery_picker',
);

/// Asks for a source and returns the chosen image's bytes, or null.
///
/// A dismissed chooser or a cancelled picker returns null; the caller leaves
/// the current picture alone.
Future<Uint8List?> pickPictureBytes(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final choice = await showModalBottomSheet<_PictureSource>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              key: const ValueKey('image-source-gallery'),
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.onSurface,
              ),
              title: Text(
                l.imageSource_gallery,
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_PictureSource.gallery),
            ),
            // The same plain icon-and-black-text row as Gallery, directly under
            // it and aligned with it (user request).
            ListTile(
              key: const ValueKey('image-source-files'),
              leading: const Icon(
                Icons.folder_open,
                color: AppColors.onSurface,
              ),
              title: Text(
                l.imageSource_files,
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              onTap: () => Navigator.of(sheetContext).pop(_PictureSource.files),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null) return null;

  try {
    if (choice == _PictureSource.gallery) {
      // Android goes through the host's ACTION_PICK: image_picker's own gallery
      // path can show DocumentsUI (the file manager) on phones without the
      // system Photo Picker. Other platforms keep the photo-library picker.
      final String? path;
      if (defaultTargetPlatform == TargetPlatform.android) {
        path = await _galleryChannel.invokeMethod<String>('pick');
      } else {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 90,
        );
        path = picked?.path;
      }
      if (path == null) return null;
      return File(path).readAsBytes();
    }
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return null;
    return file.readAsBytes();
  } on Object {
    // A picker that cannot open or a file that cannot be read: the caller keeps
    // the current picture and says why.
    return null;
  }
}
