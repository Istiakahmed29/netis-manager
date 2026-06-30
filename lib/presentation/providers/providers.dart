import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/credential_storage.dart';
import '../data/datasources/router_remote_datasource.dart';
import '../data/repositories/router_repository_impl.dart';
import '../domain/repositories/router_repository.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

/// HTTP client / web scraper for the NETIS router.
/// Single instance — keeps the session cookie alive between calls.
final routerDataSourceProvider = Provider<RouterRemoteDataSource>(
  (_) => RouterRemoteDataSource(),
);

/// Secure credential storage (Android Keystore backed).
final credentialStorageProvider = Provider<CredentialStorage>(
  (_) => CredentialStorage(),
);

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

final routerRepositoryProvider = Provider<RouterRepository>((ref) {
  return RouterRepositoryImpl(ref.read(routerDataSourceProvider));
});
