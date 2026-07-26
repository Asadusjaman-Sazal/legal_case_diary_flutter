/// Guards the app with encrypted database initialization and recovery.
/// Implemented in Task 03 Phase 1.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../database/database_factory.dart';
import '../../database/encryption_key_manager.dart';
import '../providers/database_provider.dart';
import 'database_recovery_dialog.dart';

/// {@template database_guard}
/// Watches [databaseProvider] and renders [child] once the encrypted
/// database is open. While the database is opening it shows a loading screen.
///
/// If opening fails with a [DatabaseFactoryException] (e.g. the encryption key
/// is missing), it presents a [DatabaseRecoveryDialog] that lets the user
/// reset the local database and start fresh.
/// {@endtemplate}
class DatabaseGuard extends ConsumerStatefulWidget {
  /// The widget to display once the database is initialized successfully.
  final Widget child;

  /// Creates a [DatabaseGuard] around [child].
  const DatabaseGuard({
    required this.child,
    super.key,
  });

  @override
  ConsumerState<DatabaseGuard> createState() => _DatabaseGuardState();
}

class _DatabaseGuardState extends ConsumerState<DatabaseGuard> {
  bool _isResetting = false;

  @override
  Widget build(BuildContext context) {
    final databaseAsync = ref.watch(databaseProvider);

    return databaseAsync.when(
      data: (_) => widget.child,
      loading: () => const _LoadingScreen(),
      error: (error, _) => _buildError(error),
    );
  }

  Widget _buildError(Object error) {
    if (error is! DatabaseFactoryException) {
      return _FatalErrorScreen(error: error);
    }

    if (_isResetting) {
      return const _LoadingScreen(message: 'Resetting local database...');
    }

    return _RecoveryScreen(
      onReset: _resetLocalDatabase,
    );
  }

  Future<void> _resetLocalDatabase() async {
    setState(() => _isResetting = true);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final dbFile = File('${directory.path}/app_database.db');
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      await EncryptionKeyManager().deleteKey();
    } finally {
      // Re-run the provider; the next build will see a loading state and then
      // create a fresh encrypted database.
      if (mounted) {
        ref.invalidate(databaseProvider);
      }
    }
  }
}

class _LoadingScreen extends StatelessWidget {
  final String message;

  const _LoadingScreen({this.message = 'Opening case diary...'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _RecoveryScreen extends StatelessWidget {
  final VoidCallback onReset;

  const _RecoveryScreen({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: DatabaseRecoveryDialog(onReset: onReset),
      ),
    );
  }
}

class _FatalErrorScreen extends StatelessWidget {
  final Object error;

  const _FatalErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Fatal error: $error'),
        ),
      ),
    );
  }
}
