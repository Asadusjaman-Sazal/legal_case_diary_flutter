/// Shared long-press menu for text fields.
///
/// Flutter's standard actions are kept, with Paste always available for an
/// editable field. A field may supply its own paste handler when it needs to
/// clean the clipboard text first.
library;

import 'package:flutter/material.dart';

/// Builds Flutter's standard text-selection menu with Paste made available.
///
/// The standard buttons, labels and enabled states are preserved. Paste is
/// inserted even while Flutter's clipboard check is still unknown, because the
/// menu is built before that check can finish on some phones. [onPaste] replaces
/// only the Paste action; the standard paste runs when it is null.
Widget buildTextFieldContextMenu(
  BuildContext context,
  EditableTextState editableTextState, {
  Future<void> Function(EditableTextState)? onPaste,
}) {
  final items = List<ContextMenuButtonItem>.of(
    editableTextState.contextMenuButtonItems,
  );
  final pasteIndex = items.indexWhere(
    (item) => item.type == ContextMenuButtonType.paste,
  );
  final paste = ContextMenuButtonItem(
    onPressed: onPaste == null
        ? () => editableTextState.pasteText(SelectionChangedCause.toolbar)
        : () => onPaste(editableTextState),
    type: ContextMenuButtonType.paste,
  );
  if (pasteIndex >= 0) {
    items[pasteIndex] = items[pasteIndex].copyWith(onPressed: paste.onPressed);
  } else if (!editableTextState.widget.readOnly) {
    final shareIndex = items.indexWhere(
      (item) => item.type == ContextMenuButtonType.share,
    );
    final selectAllIndex = items.indexWhere(
      (item) => item.type == ContextMenuButtonType.selectAll,
    );
    final insertAt = shareIndex >= 0
        ? shareIndex
        : (selectAllIndex >= 0 ? selectAllIndex : items.length);
    items.insert(insertAt, paste);
  }
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: items,
  );
}
