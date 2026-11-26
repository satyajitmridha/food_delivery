import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'addresses_screen.dart';
import 'config.dart';
import 'login_screen.dart';
import 'state.dart';
import 'ui.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.loggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: const LoginPrompt(title: 'Your account', subtitle: 'Log in to save addresses and see your orders.'),
      );
    }
    final u = s.user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(children: [
        Container(
          color: kInk,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${u['name']}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${u['phone']} \u00B7 ${u['email']}', style: const TextStyle(color: Color(0xFFB9BCC6), fontSize: 13)),
          ]),
        ),
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: const Text('My addresses'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddressesScreen())),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.logout, color: kRed),
          title: const Text('Log out', style: TextStyle(color: kRed)),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Log out?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Log out')),
                ],
              ),
            );
            if (ok == true) {
              await s.logout();
              Nav.tab.value = 0;
            }
          },
        ),
        const SizedBox(height: 24),
        Center(child: Text(AppConfig.appName, style: const TextStyle(color: kMuted, fontSize: 12))),
      ]),
    );
  }
}
