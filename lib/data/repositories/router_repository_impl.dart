import '../../core/errors/app_error.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/result.dart';
import '../../data/datasources/router_remote_datasource.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/router_info.dart';
import '../../domain/repositories/router_repository.dart';

/// Concrete implementation of [RouterRepository].
///
/// This class:
///   1. Delegates network calls to [RouterRemoteDataSource].
///   2. Catches typed [AppError]s and wraps them in [Result].
///   3. Catches unexpected exceptions and wraps them in [RouterConnectionError].
///
/// The UI layer only sees [Result] — it never receives raw exceptions.
class RouterRepositoryImpl implements RouterRepository {
  RouterRepositoryImpl(this._dataSource);

  final RouterRemoteDataSource _dataSource;

  @override
  Future<String?> discoverRouter() async {
    try {
      return await _dataSource.discoverRouter();
    } catch (e) {
      appLogger.e('[Repo] discoverRouter failed: $e');
      return null;
    }
  }

  @override
  Future<Result<void>> login({
    required String routerIp,
    required String username,
    required String password,
  }) async {
    return _wrap(() => _dataSource.login(
          routerIp: routerIp,
          username: username,
          password: password,
        ));
  }

  @override
  Future<void> logout() async {
    await _dataSource.logout();
  }

  @override
  Future<Result<List<Device>>> getConnectedDevices() async {
    return _wrap(() => _dataSource.getConnectedDevices());
  }

  @override
  Future<Result<void>> blockDevice(String mac) async {
    return _wrap(() => _dataSource.blockDevice(mac));
  }

  @override
  Future<Result<void>> unblockDevice(String mac) async {
    return _wrap(() => _dataSource.unblockDevice(mac));
  }

  @override
  Future<Result<RouterInfo>> getRouterInfo() async {
    return _wrap(() => _dataSource.getRouterInfo());
  }

  // ---------------------------------------------------------------------------
  // Helper: run [fn], catch errors, return Result
  // ---------------------------------------------------------------------------
  Future<Result<T>> _wrap<T>(Future<T> Function() fn) async {
    try {
      final value = await fn();
      return Success(value);
    } on AppError catch (e) {
      appLogger.w('[Repo] AppError: $e');
      return Failure(e);
    } catch (e, st) {
      appLogger.e('[Repo] Unexpected error', error: e, stackTrace: st);
      return Failure(RouterConnectionError(e.toString()));
    }
  }
}
