import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard/dashboard_screen.dart';
import '../incidents/incidents_list_screen.dart';
import '../incidents/report_incident_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    IncidentsListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Incidents',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showReportSheet(context),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Report', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showReportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.92,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          child: ReportIncidentScreen(),
        ),
      ),
    );
  }
}
