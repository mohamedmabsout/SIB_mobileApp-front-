import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/screens/edit_profile_screen.dart';
import 'package:sib_expense_app/screens/expense_claim_screen.dart';
import 'package:sib_expense_app/screens/employees_screen.dart';
import 'package:sib_expense_app/screens/affectations_screen.dart';
import 'package:sib_expense_app/screens/leave_request_list_screen.dart';
import 'package:sib_expense_app/screens/login_screen.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:sib_expense_app/screens/leave_request_screen.dart'; // Import the LeaveRequestScreen
class DashboardScreen extends StatefulWidget {
  final String token;

  const DashboardScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    print("The session in dashboard is  ${widget.token}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Manage Users', // Add tooltips
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmployeesScreen(token: widget.token),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'View Assignments/Claims', // Adjust tooltip
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  // Assuming AffectationsScreen now shows Expense Claims or Assignments
                  builder: (context) => AffectationsScreen(token: widget.token),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.time_to_leave), // Or Icons.time_to_leave
            tooltip: 'Request Leave',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LeaveRequestListScreen(token: widget.token), // Pass the token
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined), // Or Icons.person_outline, Icons.settings
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(token: widget.token), // Navigate to Edit Profile
                ),
              );
            },
          ),
          // PopupMenuButton remains
        ],

      ),
      body: Stack(
        children: [
          // Background Image
          Image.asset(
            'assets/dashboard_background.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            // Optional: Adjust background image brightness
            // color: Colors.black.withOpacity(0.2),
            // colorBlendMode: BlendMode.darken,
          ),
          // Content (Dashboard)
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Date Filter
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filtrer par date',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                color: Colors.blue[900],
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            const Text('01/02/2025-28/02/2025'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Expense Claims
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notes de frais',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                color: Colors.green[900],
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            Text('Brouillon: 0', style: TextStyle(color: Colors.grey[700])),
                            Text('Validation Manager: 0', style: TextStyle(color: Colors.grey[700])),
                            Text('Validation RH: 0', style: TextStyle(color: Colors.grey[700])),
                            Text('Attente paiement: 0', style: TextStyle(color: Colors.grey[700])),
                            Text('Payé: 0', style: TextStyle(color: Colors.grey[700])),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Assignments
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Affectations',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                color: Colors.orange[900],
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            Text('En cours: 0', style: TextStyle(color: Colors.grey[700])),
                            Text('Validation Qualité: 0', style: TextStyle(color: Colors.grey[700])),
                            Text('Terminée: 0', style: TextStyle(color: Colors.grey[700])),
                            Text('Bloquée: 0', style: TextStyle(color: Colors.grey[700])),
                            Text('Télécharger le calendrier des affectations',
                                style: TextStyle(color: Colors.blue[700])),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Daily Logs
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comptage journalier',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                color: Colors.red[900],
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            Text('Jours travaillés: 0', style: TextStyle(color: Colors.grey[700])),
                            Text('Jours non-travaillés: 28', style: TextStyle(color: Colors.grey[700])),
                            Text('Cumul précédent: 0', style: TextStyle(color: Colors.grey[700])),
                            Text('Cumul total: 28', style: TextStyle(color: Colors.grey[700])),
                          ],
                        ),
                      ),
                    ),

                    // Calendar with styling
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      color: Colors.white.withOpacity(0.8), // Add a background to the card
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2010, 10, 16),
                          lastDay: DateTime.utc(2030, 3, 14),
                          focusedDay: _focusedDay,
                          calendarFormat: _calendarFormat,
                          selectedDayPredicate: (day) {
                            return isSameDay(_selectedDay, day);
                          },
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onFormatChanged: (format) {
                            setState(() {
                              _calendarFormat = format;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                          calendarStyle: const CalendarStyle(
                            //backgroundColor: Colors.transparent, // Ensure the calendar background is transparent
                            todayDecoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            weekendTextStyle: TextStyle(color: Colors.red),
                            defaultTextStyle: TextStyle(color: Colors.black),
                          ),
                          headerStyle: HeaderStyle(
                            titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            formatButtonTextStyle: TextStyle(color: Colors.white),
                            formatButtonDecoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(5.0),
                            ),
                            leftChevronIcon: Icon(Icons.chevron_left, color: Colors.black),
                            rightChevronIcon: Icon(Icons.chevron_right, color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}