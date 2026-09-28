import 'package:flutter/material.dart';

import 'student_homepage.dart';
import 'package:polaris_mobile_app/views/student/profile/student_profile.dart';
import 'package:polaris_mobile_app/views/student/material/create_material.dart';
import 'package:polaris_mobile_app/views/student/material/my_materials.dart';
import 'package:polaris_mobile_app/views/student/discover/discover_page.dart';


class StudentNavBar extends StatefulWidget {
  const StudentNavBar({super.key});

  @override
  State<StudentNavBar> createState() => _StudentNavBarState();
}

class _StudentNavBarState extends State<StudentNavBar> {
  static const Color cream = Color(0xFFFCF6F0);
  static const Color navy = Color(0xFF252A5A);
  static const Color purple = Color(0xFF7B5EA7);
  static const Color gold = Color(0xFFE8B94A);

  static const int _createTabIndex = 2;

  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    StudentHomepage(),
    DiscoverPage(),
    MyMaterialsView(),
    StudentProfileView(),
  ];

  int _screenIndexFor(int navBarIndex) {
    if (navBarIndex < _createTabIndex) {
      return navBarIndex;
    }

    return navBarIndex - 1;
  }

  int _navBarIndexFor(int screenIndex) {
    if (screenIndex < _createTabIndex) {
      return screenIndex;
    }

    return screenIndex + 1;
  }

  void _onDestinationSelected(int navBarIndex) {
    print('NAVBAR CLICKED: $navBarIndex');

    if (navBarIndex == _createTabIndex) {
      _openCreateMaterial();
      return;
    }

    setState(() {
      _selectedIndex = _screenIndexFor(navBarIndex);
    });

    print('SCREEN INDEX: $_selectedIndex');
  }

  void _openCreateMaterial() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateMaterialView(),
        fullscreenDialog: true,
      ),
    );
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
            backgroundColor: const Color.fromARGB(255, 255, 246, 238),
            indicatorColor: gold.withOpacity(0.2),
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
            selectedIndex: _navBarIndexFor(_selectedIndex),
            onDestinationSelected: _onDestinationSelected,

            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),

              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Discover',
              ),

              NavigationDestination(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: purple,
                  size: 36,
                ),
                selectedIcon: Icon(
                  Icons.add_circle,
                  color: purple,
                  size: 38,
                ),
                label: 'Create',
              ),

              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: 'My Materials',
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