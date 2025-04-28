// lib/screens/dashboard_template.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/screens/edit_profile_screen.dart';
import 'package:sib_expense_app/screens/login_screen.dart';

class DashboardTemplate extends StatelessWidget { // Can likely be StatelessWidget now
  final String title;
  final String token;
  final List<Widget> kpiCards; // Renamed for clarity
  final Future<void> Function() onRefresh; // Callback for refresh

  const DashboardTemplate({
    Key? key,
    required this.title,
    required this.token,
    required this.kpiCards,
    required this.onRefresh,
  }) : super(key: key);

  // Logout function remains useful
  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Check context validity before navigating
    if (Navigator.of(context).canPop()) {
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
    final Color scaffoldBgColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: appBarColor,
        elevation: 1, // Subtle elevation
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(token: token),
                ),
              ).then((_) => onRefresh()); // Refresh after profile edit
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
          // Removed PopupMenuButton
        ],
      ),
      backgroundColor: scaffoldBgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh, // Use the passed refresh function
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 1.0, // Adjust ratio for new card design (try 1.0 or 0.95)
              children: kpiCards, // Display the cards provided by the specific dashboard
            ),
          ),
        ),
      ),
      // Removed FloatingActionButton
    );
  }
}