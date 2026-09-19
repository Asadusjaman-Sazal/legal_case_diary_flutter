/// Recording fakes for the print and share seams (Task 14 Phases 2 and 3).
///
/// Both platform services own a channel and the renderer owns an engine encoder
/// plus an isolate, none of which exist on a test host. Replacing them at the
/// provider seam lets a screen test assert *what would have been printed* —
/// which is the part the task is actually about.
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'package:legal_case_diary/core/print/print_document.dart';
import 'package:legal_case_diary/core/print/print_document_renderer.dart';
import 'package:legal_case_diary/core/print/print_service.dart';
import 'package:legal_case_diary/core/services/app_share_service.dart';

/// Stands in for the renderer: records the document, returns fixed bytes.
class RecordingPrintRenderer implements PrintDocumentRenderer {
  /// Every document handed to it, in call order.
  final List<PrintDocument> documents = [];

  /// When false the renderer reports a user cancel (`null`).
  bool cancelled = false;

  @override
  Future<Uint8List?> render(BuildContext context, PrintDocument document) async {
    documents.add(document);
    return cancelled ? null : Uint8List.fromList(const [1, 2, 3]);
  }
}

/// A print job the fake service was asked to present.
typedef PresentedJob = ({Uint8List bytes, String jobName});

/// Stands in for the OS print dialog.
class RecordingPrintService implements PrintService {
  /// Every job presented, in call order.
  final List<PresentedJob> jobs = [];

  /// What the platform reports back; `false` means the user cancelled.
  bool accepts = true;

  @override
  Future<bool> present({
    required Uint8List bytes,
    required String jobName,
  }) async {
    jobs.add((bytes: bytes, jobName: jobName));
    return accepts;
  }
}

/// An invite the fake share service was asked to hand over.
typedef SharedInvite = ({String message, String subject});

/// Stands in for the Android share sheet.
class RecordingShareService implements AppShareService {
  /// Every invite, in call order.
  final List<SharedInvite> invites = [];

  /// What the platform reports back.
  AppShareOutcome outcome = AppShareOutcome.shared;

  @override
  Future<AppShareOutcome> shareApp({
    required String message,
    String subject = '',
  }) async {
    invites.add((message: message, subject: subject));
    return outcome;
  }
}
