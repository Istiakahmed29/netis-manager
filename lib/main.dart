import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/device_list_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  runApp(
    // ProviderScope is the Riverpod dependency injection root.
    // All providers are accessible anywhere below this widget.
    const ProviderScope(
      child: NetisManagerApp(),
    ),
  );
}

class NetisManagerApp extends ConsumerWidget {
  const NetisManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'NETIS Manager',
      debugShowCheckedModeBanner: false,
      // Force dark theme — it's the only theme this app ships with
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark,
      theme: AppTheme.light,
      home: const _AuthGate(),
    );
  }
}

/// Watches auth state and routes between Login and the device list.
///
/// The "initial" / "loading" state is shown while the app tries to
/// auto-login with saved credentials — shows a splash instead of
/// flashing the login screen.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return switch (auth.status) {
      AuthStatus.initial || AuthStatus.loading => const _SplashScreen(),
      AuthStatus.authenticated => const DeviceListScreen(),
      AuthStatus.unauthenticated => const LoginScreen(),
    };
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.router_rounded, size: 56, color: scheme.primary),
            const SizedBox(height: 20),
            const Text(
              'NETIS Manager',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
