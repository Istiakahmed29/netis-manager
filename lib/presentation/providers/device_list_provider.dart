import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_error.dart';
import '../../domain/entities/device.dart';
import '../providers/providers.dart';

// ---------------------------------------------------------------------------
// Device list state
// ---------------------------------------------------------------------------

class DeviceListState {
  const DeviceListState({
    this.devices = const [],
    this.isLoading = false,
    this.error,
    this.blockingMacs = const {},
  });

  final List<Device> devices;
  final bool isLoading;
  final AppError? error;

  /// Set of MAC addresses currently being blocked/unblocked (spinner shown).
  final Set<String> blockingMacs;

  DeviceListState copyWith({
    List<Device>? devices,
    bool? isLoading,
    AppError? error,
    Set<String>? blockingMacs,
  }) {
    return DeviceListState(
      devices: devices ?? this.devices,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      blockingMacs: blockingMacs ?? this.blockingMacs,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class DeviceListNotifier extends StateNotifier<DeviceListState> {
  DeviceListNotifier(this._ref) : super(const DeviceListState());

  final Ref _ref;

  RouterRepository get _repo => _ref.read(routerRepositoryProvider);

  /// Fetches the device list from the router.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repo.getConnectedDevices();

    result.fold(
      onSuccess: (devices) => state = state.copyWith(
        devices: devices,
        isLoading: false,
      ),
      onFailure: (e) => state = state.copyWith(
        isLoading: false,
        error: e,
      ),
    );
  }

  /// Blocks [mac] — optimistically updates UI while the request is in flight.
  Future<void> blockDevice(String mac) async {
    // Mark as "in progress"
    state = state.copyWith(blockingMacs: {...state.blockingMacs, mac});

    final result = await _repo.blockDevice(mac);

    result.fold(
      onSuccess: (_) {
        // Optimistic update: flip the blocked flag locally
        final updated = state.devices.map((d) {
          return d.mac == mac ? d.copyWith(isBlocked: true) : d;
        }).toList();
        state = state.copyWith(
          devices: updated,
          blockingMacs: state.blockingMacs.difference({mac}),
        );
      },
      onFailure: (e) {
        state = state.copyWith(
          error: e,
          blockingMacs: state.blockingMacs.difference({mac}),
        );
      },
    );
  }

  /// Unblocks [mac].
  Future<void> unblockDevice(String mac) async {
    state = state.copyWith(blockingMacs: {...state.blockingMacs, mac});

    final result = await _repo.unblockDevice(mac);

    result.fold(
      onSuccess: (_) {
        final updated = state.devices.map((d) {
          return d.mac == mac ? d.copyWith(isBlocked: false) : d;
        }).toList();
        state = state.copyWith(
          devices: updated,
          blockingMacs: state.blockingMacs.difference({mac}),
        );
      },
      onFailure: (e) {
        state = state.copyWith(
          error: e,
          blockingMacs: state.blockingMacs.difference({mac}),
        );
      },
    );
  }
}

final deviceListProvider =
    StateNotifierProvider<DeviceListNotifier, DeviceListState>((ref) {
  return DeviceListNotifier(ref);
});
