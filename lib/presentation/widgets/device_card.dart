import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../domain/entities/device.dart';

/// Card representing a single connected device.
///
/// Shows: hostname/MAC, IP, MAC address, blocked status.
/// Has a large Block / Unblock button — the primary action in the app.
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    required this.isActionInProgress,
    required this.onBlock,
    required this.onUnblock,
  });

  final Device device;
  final bool isActionInProgress;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isBlocked = device.isBlocked;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Device icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isBlocked
                    ? scheme.error.withOpacity(0.12)
                    : scheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _deviceIcon(),
                size: 26,
                color: isBlocked ? scheme.error : scheme.primary,
              ),
            ),

            const SizedBox(width: 14),

            // Device info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    device.displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // IP
                  _InfoChip(
                    icon: Icons.lan_outlined,
                    label: device.ip,
                  ),

                  const SizedBox(height: 3),

                  // MAC
                  _InfoChip(
                    icon: Icons.tag_rounded,
                    label: device.mac,
                    monospace: true,
                  ),

                  if (isBlocked) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.block, size: 12, color: scheme.error),
                        const SizedBox(width: 4),
                        Text(
                          'Blocked',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Block / Unblock button
            _ActionButton(
              isBlocked: isBlocked,
              isLoading: isActionInProgress,
              onPressed: isBlocked ? onUnblock : onBlock,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.04);
  }

  IconData _deviceIcon() {
    final name = device.displayName.toLowerCase();
    if (name.contains('phone') || name.contains('android') || name.contains('iphone')) {
      return Icons.smartphone_rounded;
    }
    if (name.contains('laptop') || name.contains('macbook') || name.contains('pc')) {
      return Icons.laptop_rounded;
    }
    if (name.contains('tv') || name.contains('roku') || name.contains('fire')) {
      return Icons.tv_rounded;
    }
    if (name.contains('tablet') || name.contains('ipad')) {
      return Icons.tablet_rounded;
    }
    return Icons.devices_rounded;
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.monospace = false,
  });

  final IconData icon;
  final String label;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              fontFamily: monospace ? 'monospace' : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.isBlocked,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isBlocked;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bgColor = isBlocked
        ? scheme.primary.withOpacity(0.15)
        : scheme.error.withOpacity(0.15);
    final fgColor = isBlocked ? scheme.primary : scheme.error;
    final label = isBlocked ? 'Unblock' : 'Block';
    final icon = isBlocked ? Icons.lock_open_rounded : Icons.block_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fgColor,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: fgColor),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: fgColor,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
