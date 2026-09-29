import 'package:flutter/material.dart';
import '../models/utilisateur.dart';
import '../services/auth_service.dart';
import 'achat/achat_screen.dart';
import 'caisse/caisse_screen.dart';
import 'stats/stats_screen.dart';
import 'stock/stock_hub_screen.dart';
import 'vente/vente_screen.dart';

class _TabDefinition {
  final String code;
  final String label;
  final Widget icon;
  final Widget selectedIcon;
  final Widget screen;
  final bool Function(Utilisateur? user) isAllowed;

  const _TabDefinition({
    required this.code,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
    required this.isAllowed,
  });
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static final List<_TabDefinition> _allTabs = [
    _TabDefinition(
      code: 'VENTES',
      label: 'Ventes',
      icon: const Icon(Icons.shopping_cart_outlined),
      selectedIcon: const Icon(Icons.shopping_cart_rounded, color: Colors.black),
      screen: const VenteScreen(),
      isAllowed: (user) => user == null || user.profil.canAccessVente,
    ),
    _TabDefinition(
      code: 'STOCKS',
      label: 'Stocks',
      icon: const Icon(Icons.inventory_2_outlined),
      selectedIcon: const Icon(Icons.inventory_2_rounded, color: Colors.black),
      screen: const StockHubScreen(),
      isAllowed: (user) => user == null || user.profil.canAccessStock,
    ),
    _TabDefinition(
      code: 'ACHATS',
      label: 'Achats',
      icon: const Icon(Icons.local_shipping_outlined),
      selectedIcon: const Icon(Icons.local_shipping_rounded, color: Colors.black),
      screen: const AchatScreen(),
      isAllowed: (user) => user == null || user.profil.canAccessAchat,
    ),
    _TabDefinition(
      code: 'CAISSE',
      label: 'Caisse',
      icon: const Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: const Icon(Icons.account_balance_wallet_rounded, color: Colors.black),
      screen: const CaisseScreen(),
      isAllowed: (user) => user == null || user.profil.canAccessCaisse,
    ),
    _TabDefinition(
      code: 'STATS',
      label: 'Stats',
      icon: const Icon(Icons.bar_chart_outlined),
      selectedIcon: const Icon(Icons.bar_chart_rounded, color: Colors.black),
      screen: const StatsScreen(),
      isAllowed: (user) => user == null || user.profil.canAccessStats,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final user = AuthService.instance.currentUser;
        final availableTabs = _allTabs.where((t) => t.isAllowed(user)).toList();

        final effectiveIndex = availableTabs.isEmpty
            ? 0
            : _currentIndex.clamp(0, availableTabs.length - 1);

        if (availableTabs.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Aucun module autorisé pour ce profil',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: effectiveIndex,
            children: availableTabs.map((t) => t.screen).toList(),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              child: NavigationBar(
                height: 65,
                backgroundColor: Colors.white,
                indicatorColor: Colors.black.withValues(alpha: 0.08),
                selectedIndex: effectiveIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                },
                destinations: availableTabs
                    .map(
                      (t) => NavigationDestination(
                        icon: t.icon,
                        selectedIcon: t.selectedIcon,
                        label: t.label,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
