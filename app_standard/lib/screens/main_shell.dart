import 'package:flutter/material.dart';
import 'achat/achat_screen.dart';
import 'caisse/caisse_screen.dart';
import 'stats/stats_screen.dart';
import 'stock/stock_hub_screen.dart';
import 'vente/vente_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Onglet Ventes actif par défaut
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const VenteScreen(),
    const StockHubScreen(),
    const AchatScreen(),
    const CaisseScreen(),
    const StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.shopping_cart_outlined),
                selectedIcon: Icon(Icons.shopping_cart_rounded, color: Colors.black),
                label: 'Ventes',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2_rounded, color: Colors.black),
                label: 'Stocks',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping_rounded, color: Colors.black),
                label: 'Achats',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: Colors.black),
                label: 'Caisse',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart_rounded, color: Colors.black),
                label: 'Stats',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

