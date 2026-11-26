import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'account_screen.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'state.dart';
import 'ui.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  @override
  void initState() {
    super.initState();
    Nav.tab.addListener(_onTab);
  }

  @override
  void dispose() {
    Nav.tab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final count = context.select<AppState, int>((s) => s.cartCount);
    return Scaffold(
      body: IndexedStack(
        index: Nav.tab.value,
        children: const [HomeScreen(), CartScreen(), OrdersScreen(), AccountScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: Nav.tab.value,
        onDestinationSelected: (i) => Nav.tab.value = i,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Home'),
          NavigationDestination(
            icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.shopping_basket_outlined)),
            label: 'Cart',
          ),
          const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
          const NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
        ],
      ),
    );
  }
}
