// lib/screens/employee_dashboard.dart - NO CHANGES NEEDED HERE
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/components/dashboard_card.dart';
import 'package:sib_expense_app/screens/dashboard_template.dart';
// Import screens for navigation
import 'package:sib_expense_app/screens/affectations_screen.dart';
import 'package:sib_expense_app/screens/expense_claim_screen.dart';
import 'package:sib_expense_app/screens/leave_request_list_screen.dart';
import 'package:sib_expense_app/screens/leave_request_screen.dart';
import 'package:sib_expense_app/screens/project_list_screen.dart';
import 'package:sib_expense_app/screens/task_list_screen.dart';

import '../config/dio_client.dart';
import '../models/dashboard_data_dto.dart';
import 'KpiBarChart.dart';
import 'alerts_screen.dart';
import 'edit_profile_screen.dart';
import 'equipment_list_screen.dart';
import 'login_screen.dart';


class EmployeeDashboard extends StatefulWidget {
  final String token;
  const EmployeeDashboard({Key? key, required this.token}) : super(key: key);

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}
class _EmployeeDashboardState extends State<EmployeeDashboard> {

  // State variables to hold the KPI values dynamically
  int? _pendingClaimsCount;
  int? _openTasksCount;
  int? _approvedLeaveDays;
  int? _workingDays;
  int? _activeProjects;
  int? _finishedTasks;
  bool _isRefreshing = false; // Track refresh state
  String? _refreshError;
  DashboardDataDto? _kpiData;
  final Dio _dio = createDioClient(); // Use centralized Dio
  bool _isLoading = true; // Changed initial state
  String? _errorMessage;
  @override
  void initState() {
    super.initState();
    // Initial data fetch when the dashboard loads
    _refreshDashboardData();
  }

  // Fetches updated KPI data from the backend
  Future<void> _refreshDashboardData() async {
    if (_isRefreshing || !mounted) return;

    if (!_isLoading) { // Only set refreshing if not initial load
      setState(() { _isRefreshing = true; });
    }
    // Clear previous error ONLY if starting a new refresh
    if (_isRefreshing || _isLoading) {
      setState(() { _errorMessage = null; });
    }


    try {
      print("Refreshing Employee Dashboard data using /api/dashboard/data ...");
      // Call the general /api/dashboard/data endpoint
      // Backend service needs to populate the correct fields for EMPLOYEE
      final response = await _dio.get('/api/dashboard/data');

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          // Parse using the general DTO
          _kpiData = DashboardDataDto.fromJson(response.data);
        });
      } else {
        _handleApiError(response, "Failed to refresh dashboard data");
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, "refreshing dashboard data");
      setState(() { _kpiData = null; }); // Clear data on error
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Initial load complete
          _isRefreshing = false;
        });
      }
    }
  }

  // --- Error Handling Helpers (Keep these in the state) ---
  void _handleApiError(Response? response, String defaultMessage) {
    if (!mounted) return;
    String errorMsg = defaultMessage;
    if (response?.data is Map && response!.data.containsKey('error')) {
      errorMsg = response.data['error'];
    }
    else if (response?.statusMessage != null &&
        response!.statusMessage!.isNotEmpty) {
      errorMsg = response.statusMessage!;
    }
    else if (response?.data != null) {
      errorMsg = response!.data.toString();
    }
    setState(() {
      _refreshError = '$errorMsg (Status: ${response?.statusCode ?? 'N/A'})';
    }); // Use _refreshError
    print('$defaultMessage: ${response?.statusCode}, Response: ${response
        ?.data}');
  }

  void _handleGenericError(Object e, String action) {
    if (!mounted) return;
    String errorMsg = 'Error $action';
    if (e is DioException) {
      if (e.response != null && e.response?.data is Map &&
          e.response?.data['error'] != null) {
        errorMsg = e.response?.data['error'];
      }
      else if (e.response != null && e.response?.data != null) {
        errorMsg =
        "Server Error (${e.response?.statusCode}): ${e.response?.data
            .toString()
            .substring(0, 100)}...";
      }
      else if (e.response != null) {
        errorMsg = 'Server Error: ${e.response?.statusCode}';
      }
      else {
        errorMsg = 'Network Error. Please check connection.';
      }
    } else {
      errorMsg = 'An unexpected error occurred.';
      print('Non-Dio Error type: ${e.runtimeType}');
    }
    setState(() {
      _refreshError = errorMsg;
    }); // Use _refreshError
    print('Error during "$action": $e');
  }

  Widget _buildKpiCard({
    required String title, required String value, required IconData icon,
    required Color startColor, required Color endColor, VoidCallback? onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [startColor, endColor],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(alignment: Alignment.topRight, child: Icon(icon, size: 32, color: Colors.white70)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1), maxLines: 1)),
                    const SizedBox(height: 5),
                    Text(title, style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9), height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
  // --- End Build KPI Card ---
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define colors
    const Color blueStart = Color(0xFF3A7BD5); const Color blueEnd = Color(0xFF00D2FF);
    const Color greenStart = Color(0xFF6DD5FA); const Color greenEnd = Color(0xFF23A6D5);
    const Color purpleStart = Color(0xFF8E2DE2); const Color purpleEnd = Color(0xFF4A00E0);
    const Color orangeStart = Color(0xFFFDC830); const Color orangeEnd = Color(0xFFF37335);
    const Color tealStart = Color(0xFF4DB6AC); const Color tealEnd = Color(0xFF00695C); // For Projects card
    const Color brownStart = Color(0xFFA1887F); const Color brownEnd = Color(0xFF6D4C41); // For Equipment card

    // Get KPI values safely from _kpiData
    String pendingClaimsValue = _isLoading ? "..." : (_kpiData?.pendingExpenseClaims?.toString() ?? "0");
    String openTasksValue = _isLoading ? "..." : (_kpiData?.myOpenTasks?.toString() ?? "0");
    String approvedLeaveValue = _isLoading ? "..." : ("${_kpiData?.myApprovedLeaveDaysThisYear?.toString() ?? '0'} j.");
    String activeAssignmentsValue = _isLoading ? "..." : (_kpiData?.myActiveAssignments?.toString() ?? "0");
    String assignedEquipmentValue = _isLoading ? "..." : (_kpiData?.myAssignedEquipmentCount?.toString() ?? "0");
    String activeProjectsValue = _isLoading ? "..." : (_kpiData?.myActiveProjects?.toString() ?? "0");

    return Scaffold( // Build Scaffold directly here
      appBar: AppBar(
        title: const Text('Employee Dashboard'), // Static title for employee
        backgroundColor: Colors.blue[700], // Keep blue AppBar or use Theme
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined), // Standard notifications icon
            tooltip: 'View Alerts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AlertsScreen(token: widget.token), // Pass the token
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
                MaterialPageRoute(builder: (context) => EditProfileScreen(token: widget.token)),
              ).then((_) => _refreshDashboardData()); // Refresh after profile edit
            },
          ),
        ],
      ),
      body: Stack( // Use Stack for background image
        children: [
          Image.asset(
            'assets/dashboard_background2.jpg', // Your background image
            fit: BoxFit.cover,
            width: double.infinity, height: double.infinity,
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshDashboardData,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white)) // White indicator for dark bg
                  : _errorMessage != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 18, backgroundColor: Colors.black54), textAlign: TextAlign.center)))
                  : _kpiData == null
                  ? const Center(child: Text('Could not load dashboard data.', style: TextStyle(color: Colors.white70)))
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Error Card
                    if (_errorMessage != null && !_isLoading) // Show non-loading errors here too
                      Card(
                          color: Colors.redAccent.withOpacity(0.8),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(_errorMessage!, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          )
                      ),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 1.0, // Try adjusting this (e.g., 0.95, 1.0)
                      children: [
                        // Existing Cards with dynamic values
                        _buildKpiCard(title: 'Notes Frais (Attente)', value: pendingClaimsValue, icon: Icons.receipt_long_outlined, startColor: orangeStart, endColor: orangeEnd, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AffectationsScreen(token: widget.token)))),
                        _buildKpiCard(title: 'Tâches Ouvertes', value: openTasksValue, icon: Icons.task_alt_outlined, startColor: blueStart, endColor: blueEnd, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TaskListScreen(token: widget.token)))),
                        _buildKpiCard(title: 'Congés Approuvés (Année)', value: approvedLeaveValue, icon: Icons.beach_access_outlined, startColor: greenStart, endColor: greenEnd, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LeaveRequestListScreen(token: widget.token)))),

                        // --- NEW Cards ---
                        _buildKpiCard(
                          title: 'Mes Projets Actifs',
                          value: activeProjectsValue, // Use new state variable
                          icon: Icons.assignment_turned_in_outlined, // Or work_history
                          startColor: tealStart, endColor: tealEnd, // Teal gradient
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProjectListScreen(token: widget.token))), // Navigate to Project List
                        ),
                        _buildKpiCard(
                          title: 'Mon Matériel Assigné',
                          value: assignedEquipmentValue, // Use new state variable
                          icon: Icons.build_circle_outlined, // Or construction, computer etc.
                          startColor: brownStart, endColor: brownEnd, // Brown gradient
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EquipmentListScreen(token: widget.token))), // Navigate to Equipment List
                        ),
                        // --- END NEW Cards ---

                        // Action Cards
                        _buildKpiCard(title: 'Demander Congé', value: "+", icon: Icons.time_to_leave_outlined, startColor: purpleStart, endColor: purpleEnd, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LeaveRequestScreen(token: widget.token))).then((_) => _refreshDashboardData())),
                        _buildKpiCard(title: 'Soumettre Note Frais', value: "+", icon: Icons.post_add_outlined, startColor: orangeStart.withOpacity(0.8), endColor: orangeEnd.withOpacity(0.8), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ExpenseClaimScreen(token: widget.token))).then((_) => _refreshDashboardData())),
                        _buildKpiCard(title: 'Suivi Journalier', value: "Entrer", icon: Icons.timer_outlined, startColor: Colors.cyan.shade300, endColor: Colors.cyan.shade700, onTap: () { /* TODO: Navigate to Daily Log / Timesheet screen */ }),

                      ],
                    ),
                    // Optional: Add Alerts section if needed for employees
                    // const SizedBox(height: 20),
                    // if (_kpiData?.alerts != null && _kpiData!.alerts!.isNotEmpty)
                    //    _buildAlertsSection(_kpiData!.alerts!),
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