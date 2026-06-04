import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/server_connect_screen.dart';
import 'screens/onboarding/dkg_progress_screen.dart';
import 'screens/onboarding/wallet_ready_screen.dart';
import 'screens/onboarding/signer_selection_screen.dart';
import 'screens/onboarding/password_create_screen.dart';
import 'screens/onboarding/google_signin_screen.dart';
import 'screens/onboarding/restore_screen.dart';
import 'screens/settings/backup_settings_screen.dart';
import 'screens/spending/send_screen.dart';
import 'screens/spending/review_screen.dart';
import 'screens/spending/signing_screen.dart';
import 'screens/policies/policies_screen.dart';
import 'screens/policies/edit_policy_screen.dart';
import 'screens/receive_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/ark/ark_screen.dart';
import 'screens/ark/ark_receive_screen.dart';
import 'screens/ark/ark_send_screen.dart';
import 'screens/ark/ark_board_screen.dart';

import 'package:provider/provider.dart';
import 'services/mpc_service.dart';
import 'services/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Best-effort push init. No-ops gracefully when Firebase config is missing
  // (e.g. CI builds without google-services.json).
  await PushService.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final svc = MpcService();
          svc.initFuture = svc.init();
          // The FCM token can only be registered once the wallet is
          // authenticated — DKG or session restore is what populates
          // client.userId. init() alone doesn't log in, so register on the
          // first change where a user id exists. Idempotent; PushService also
          // re-registers on token rotation.
          late final VoidCallback tokenListener;
          tokenListener = () {
            if (svc.client?.userId != null) {
              svc.removeListener(tokenListener);
              PushService.registerCurrentToken(svc);
            }
          };
          svc.addListener(tokenListener);
          return svc;
        }),
      ],
      child: const MerlinWalletApp(),
    ),
  );
}

class MerlinWalletApp extends StatefulWidget {
  const MerlinWalletApp({super.key});

  @override
  State<MerlinWalletApp> createState() => _MerlinWalletAppState();
}

class _MerlinWalletAppState extends State<MerlinWalletApp> {
  late final GoRouter _router = _buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Merlin Wallet',
      theme: AppTheme.darkTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

GoRouter _buildRouter() => GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/onboarding/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/onboarding/signer-selection',
      builder: (context, state) => const SignerSelectionScreen(),
    ),
    GoRoute(
      path: '/onboarding/password',
      builder: (context, state) => const PasswordCreateScreen(),
    ),
    GoRoute(
      path: '/onboarding/google-signin',
      builder: (context, state) => const GoogleSignInScreen(),
    ),
    GoRoute(
      path: '/onboarding/restore',
      builder: (context, state) => const RestoreScreen(),
    ),
    GoRoute(
      path: '/onboarding/server',
      builder: (context, state) => const ServerConnectionScreen(),
    ),
    GoRoute(
      path: '/settings/backup',
      builder: (context, state) => const BackupSettingsScreen(),
    ),
    GoRoute(
      path: '/onboarding/dkg',
      builder: (context, state) => const DkgProgressScreen(),
    ),
GoRoute(
      path: '/onboarding/ready',
      builder: (context, state) => const WalletReadyScreen(),
    ),
    GoRoute(
      path: '/spending/send',
      builder: (context, state) => const SendScreen(),
    ),
    GoRoute(
      path: '/receive',
      builder: (context, state) => const ReceiveScreen(),
    ),
    GoRoute(
      path: '/spending/review',
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>? ?? {};
        return ReviewScreen(extras: extras);
      },
    ),
    GoRoute(
      path: '/spending/signing',
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>? ?? {};
        return SigningScreen(extras: extras);
      },
    ),
    GoRoute(
      path: '/ark',
      builder: (context, state) => const ArkScreen(),
    ),
    GoRoute(
      path: '/ark/receive',
      builder: (context, state) => const ArkReceiveScreen(),
    ),
    GoRoute(
      path: '/ark/send',
      builder: (context, state) => const ArkSendScreen(),
    ),
    GoRoute(
      path: '/ark/board',
      builder: (context, state) => const ArkBoardScreen(),
    ),
    GoRoute(
      path: '/policies',
      builder: (context, state) => const PoliciesScreen(),
    ),
    GoRoute(
      path: '/policies/edit',
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>?;
        return EditPolicyScreen(extras: extras);
      },
    ),
  ],
);
