import '../../core/utils/result.dart';
import '../entities/device.dart';
import '../entities/router_info.dart';

/// Abstract contract for all router operations.
///
/// The domain layer only knows about this interface — it never imports
/// Dio, HTML parsing, or anything network-specific. This makes the
/// domain testable without a real router.
abstract interface class RouterRepository {
  // ---------------------------------------------------------------------------
  // Discovery
  // ---------------------------------------------------------------------------

  /// Scans candidate IPs and returns the first one that responds as a
  /// NETIS router. Returns null if none found.
  Future<String?> discoverRouter();

  // ---------------------------------------------------------------------------
  // Authentication
  // ---------------------------------------------------------------------------

  /// Authenticates with the router web interface.
  /// On success the session cookie is stored internally for subsequent calls.
  Future<Result<void>> login({
    required String routerIp,
    required String username,
    required String password,
  });

  /// Clears the active session.
  Future<void> logout();

  // ---------------------------------------------------------------------------
  // Device list
  // ---------------------------------------------------------------------------

  /// Returns all devices the router currently knows about (DHCP lease table
  /// merged with the MAC filter list to determine blocked status).
  Future<Result<List<Device>>> getConnectedDevices();

  // ---------------------------------------------------------------------------
  // Block / Unblock
  // ---------------------------------------------------------------------------

  /// Adds [mac] to the router's MAC blacklist (blocks internet access).
  Future<Result<void>> blockDevice(String mac);

  /// Removes [mac] from the router's MAC blacklist.
  Future<Result<void>> unblockDevice(String mac);

  // ---------------------------------------------------------------------------
  // Router info
  // ---------------------------------------------------------------------------

  /// Fetches basic router information from the status page.
  Future<Result<RouterInfo>> getRouterInfo();
}
