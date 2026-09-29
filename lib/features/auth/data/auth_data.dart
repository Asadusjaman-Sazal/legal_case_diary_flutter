/// Auth data layer (Task 17).
///
/// Everything the app needs to know about identity lives behind these exports:
/// the [AuthRepository] boundary and its value types, the Supabase
/// implementation, the secure session store, and the local identity cache.
library;

export 'auth_repository.dart';
export 'local_auth_service.dart';
export 'session_store.dart';
export 'supabase_auth_repository.dart';
