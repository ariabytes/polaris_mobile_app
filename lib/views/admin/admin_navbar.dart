import 'package:flutter/material.dart';

import 'admin_homepage.dart';
import 'package:polaris_mobile_app/views/admin/accounts/admin_accounts.dart';
import 'package:polaris_mobile_app/views/admin/materials/admin_materials.dart';
import 'package:polaris_mobile_app/views/admin/profile/admin_profile.dart';

class AdminNavBar extends StatefulWidget {
  const AdminNavBar({super.key});

  @override
  State<AdminNavBar> createState() => _AdminNavBarState();
}

class _AdminNavBarState extends State<AdminNavBar> {
  static const Color cream = Color(0xFFFEEFDD);
  static const Color orange = Color(0xFFF87C4F);
  static const Color navy = Color(0xFF252A5A);

  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    AdminHomepage(),
    AdminAccountsView(),
    AdminMaterialsView(),
    AdminProfileView(),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: cream,
            indicatorColor: orange.withOpacity(0.2),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),

            labelTextStyle:
                WidgetStateProperty.resolveWith((states) {
              final selected =
                  states.contains(WidgetState.selected);

              return TextStyle(
                fontSize: 12,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: selected
                    ? navy
                    : Colors.black54,
              );
            }),

            iconTheme:
                WidgetStateProperty.resolveWith((states) {
              final selected =
                  states.contains(WidgetState.selected);

              return IconThemeData(
                color: selected
                    ? navy
                    : Colors.black54,
              );
            }),
          ),

          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,

            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),

              NavigationDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group),
                label: 'Accounts',
              ),

              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: 'Materials',
              ),

              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}