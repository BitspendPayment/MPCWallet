import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:app/services/mpc_service.dart';

/// Bottom navigation shared by the Home and Ark screens. Items are built by
/// route (indices are derived, never hardcoded), and in offline mode the Ark and
/// Services tabs — both Ark-layer — are hidden, leaving only Home + Send.
class AppBottomNav extends StatelessWidget {
  /// Route of the current screen, e.g. '/' or '/ark'.
  final String current;
  const AppBottomNav({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<MpcService>().offlineMode;

    final items = <_NavItem>[
      const _NavItem('/', Icons.account_balance_wallet_outlined,
          Icons.account_balance_wallet, 'Home'),
      if (!offline)
        const _NavItem(
            '/ark', Icons.account_tree_outlined, Icons.account_tree, 'Ark'),
      const _NavItem(
          '/spending/send', Icons.send_outlined, Icons.send, 'Send'),
    ];

    int currentIndex = items.indexWhere((i) => i.route == current);
    if (currentIndex < 0) currentIndex = 0;

    return BottomNavigationBar(
      backgroundColor: const Color(0xFF1E1E1E),
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white38,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: (index) {
        final route = items[index].route;
        if (route == current) return;
        // Send is a pushed modal flow; the other tabs are go() destinations.
        if (route == '/spending/send') {
          context.push(route);
        } else {
          context.go(route);
        }
      },
      items: [
        for (final i in items)
          BottomNavigationBarItem(
            icon: Icon(i.icon),
            activeIcon: Icon(i.activeIcon),
            label: i.label,
          ),
      ],
    );
  }
}

class _NavItem {
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.route, this.icon, this.activeIcon, this.label);
}
