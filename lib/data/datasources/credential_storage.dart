import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/router_constants.dart';
import '../../core/utils/logger.dart';

/// Persists router credentials using Android Keystore (via flutter_secure_storage).
///
/// On Android, flutter_secure_storage encrypts values with AES-256 and
/// stores the encryption key in the Android Keystore — inaccessible to
/// other apps and not included in unencrypted backups.
class CredentialStorage {
  CredentialStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
        );

  final FlutterSecureStorage _storage;

  Future<void> saveCredentials({
    required String routerIp,
    required String username,
    required String password,
  }) async {
    await Future.wait([
      _storage.write(key: RouterConstants.storageKeyRouterIP, value: routerIp),
      _storage.write(key: RouterConstants.storageKeyUsername, value: username),
      _storage.write(key: RouterConstants.storageKeyPassword, value: password),
    ]);
    appLogger.i('[Credentials] Saved for $routerIp');
  }

  Future<SavedCredentials?> loadCredentials() async {
    final results = await Future.wait([
      _storage.read(key: RouterConstants.storageKeyRouterIP),
      _storage.read(key: RouterConstants.storageKeyUsername),
      _storage.read(key: RouterConstants.storageKeyPassword),
    ]);

    final ip = results[0];
    final username = results[1];
    final password = results[2];

    if (ip == null || username == null || password == null) return null;

    appLogger.d('[Credentials] Loaded for $ip');
    return SavedCredentials(routerIp: ip, username: username, password: password);
  }

  Future<void> clearCredentials() async {
    await Future.wait([
      _storage.delete(key: RouterConstants.storageKeyRouterIP),
      _storage.delete(key: RouterConstants.storageKeyUsername),
      _storage.delete(key: RouterConstants.storageKeyPassword),
    ]);
    appLogger.i('[Credentials] Cleared');
  }
}

class SavedCredentials {
  const SavedCredentials({
    required this.routerIp,
    required this.username,
    required this.password,
  });

  final String routerIp;
  final String username;
  final String password;
}
