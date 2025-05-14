// lib/screens/dashboard_template.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/screens/edit_profile_screen.dart';
import 'package:sib_expense_app/screens/login_screen.dart';

import 'alerts_screen.dart';

class DashboardTemplate extends StatelessWidget {
  final String title;
  final String token;
  final List<Widget> kpiCards; // List of KPI cards to display
  final Future<void> Function() onRefresh;
  // Optional: Add a slot for alerts if you want the template to handle its placement
  // final Widget? alertsSection;

  const DashboardTemplate({
    Key? key,
    required this.title,
    required this.token,
    required this.kpiCards,
    required this.onRefresh,
    // this.alertsSection,
  }) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Ensure context is still valid for navigation
    if (Navigator.of(context).mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color appBarColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    // Background color is handled by the Stack with Image now

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: appBarColor,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined), // Standard notifications icon
            tooltip: 'View Alerts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AlertsScreen(token: token), // Pass the token
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(token: token),
                ),
              ).then((_) => onRefresh());
            },
          ),

        ],
      ),
      body: Stack( // Use Stack for background image
        children: [
          Image.asset(
            'assets/dashboard_background2.jpg', // Your desired background
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column( // Column to hold alerts then grid
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Optional slot for alerts - specific dashboard will build it
                    // if (alertsSection != null) alertsSection!,
                    // if (alertsSection != null) const SizedBox(height: 16),

                    // Grid for KPI Cards
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 1.0, // Adjust as needed for your cards
                      children: kpiCards,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // FAB removed from template - add to specific dashboards if needed
    );
  }
}