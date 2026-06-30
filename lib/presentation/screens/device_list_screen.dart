import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../domain/entities/device.dart';
import '../providers/auth_provider.dart';
import '../providers/device_list_provider.dart';
import '../widgets/device_card.dart';
import '../widgets/device_list_skeleton.dart';

/// Main screen: shows all connected devices and allows blocking/unblocking.
class DeviceListScreen extends ConsumerStatefulWidget {
  const DeviceListScreen({super.key});

  @override
  ConsumerState<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends ConsumerState<DeviceListScreen> {
  String _searchQuery = '';
  bool _showBlockedOnly = false;

  @override
  void initState() {
    super.initState();
    // Load devices on first render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deviceListProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceListProvider);
    final scheme = Theme.of(context).colorScheme;

    // Filter devices by search and blocked toggle
    final displayed = _filterDevices(state.devices);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NETIS Manager'),
        actions: [
          // Filter: blocked only
          IconButton(
            icon: Icon(
              Icons.block_rounded,
              color: _showBlockedOnly ? scheme.error : null,
            ),
            tooltip: _showBlockedOnly ? 'Show all' : 'Show blocked only',
            onPressed: () =>
                setState(() => _showBlockedOnly = !_showBlockedOnly),
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: state.isLoading
                ? null
                : () => ref.read(deviceListProvider.notifier).refresh(),
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),

      body: Column(
        children: [
          // ── Router info bar ─────────────────────────────────────────────
          _RouterInfoBar(),

          // ── Search ──────────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name, IP or MAC…',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // ── Summary strip ───────────────────────────────────────────────
          if (state.devices.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _StatChip(
                    icon: Icons.devices_rounded,
                    label: '${state.devices.length} devices',
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.block_rounded,
                    label:
                        '${state.devices.where((d) => d.isBlocked).length} blocked',
                    color: scheme.error,
                  ),
                ],
              ),
            ),

          // Error banner
          if (state.error != null)
            _ErrorStrip(
              message: state.error!.message,
              onRetry: () =>
                  ref.read(deviceListProvider.notifier).refresh(),
            ),

          // ── Device list ─────────────────────────────────────────────────
          Expanded(
            child: state.isLoading && state.devices.isEmpty
                ? const DeviceListSkeleton()
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(deviceListProvider.notifier).refresh(),
                    child: displayed.isEmpty
                        ? _EmptyState(hasDevices: state.devices.isNotEmpty)
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: displayed.length,
                            itemBuilder: (ctx, i) {
                              final device = displayed[i];
                              return DeviceCard(
                                key: ValueKey(device.mac),
                                device: device,
                                isActionInProgress:
                                    state.blockingMacs.contains(device.mac),
                                onBlock: () => _block(device),
                                onUnblock: () => _unblock(device),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Device> _filterDevices(List<Device> devices) {
    var list = devices;
    if (_showBlockedOnly) {
      list = list.where((d) => d.isBlocked).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((d) =>
              d.displayName.toLowerCase().contains(q) ||
              d.ip.contains(q) ||
              d.mac.toLowerCase().contains(q))
          .toList();
    }
    // Blocked devices first
    list.sort((a, b) {
      if (a.isBlocked && !b.isBlocked) return -1;
      if (!a.isBlocked && b.isBlocked) return 1;
      return a.displayName.compareTo(b.displayName);
    });
    return list;
  }

  Future<void> _block(Device device) async {
    await ref.read(deviceListProvider.notifier).blockDevice(device.mac);
    if (!mounted) return;
    final error = ref.read(deviceListProvider).error;
    if (error != null) {
      _showSnack(error.message, isError: true);
    } else {
      _showSnack('${device.displayName} blocked');
    }
  }

  Future<void> _unblock(Device device) async {
    await ref.read(deviceListProvider.notifier).unblockDevice(device.mac);
    if (!mounted) return;
    final error = ref.read(deviceListProvider).error;
    if (error != null) {
      _showSnack(error.message, isError: true);
    } else {
      _showSnack('${device.displayName} unblocked');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

/// Small bar at the top showing which router is connected.
class _RouterInfoBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ip = ref.watch(authProvider).routerIp ?? '—';
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: scheme.primary.withOpacity(0.08),
      child: Row(
        children: [
          Icon(Icons.router_rounded, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            'Connected to $ip',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: scheme.primary,
            ),
          ),
          const Spacer(),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.error.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry', style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasDevices});

  final bool hasDevices;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasDevices
                ? Icons.search_off_rounded
                : Icons.devices_other_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            hasDevices ? 'No devices match your search' : 'No devices found',
            style: TextStyle(
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          if (!hasDevices) ...[
            const SizedBox(height: 8),
            Text(
              'Pull down to refresh',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
