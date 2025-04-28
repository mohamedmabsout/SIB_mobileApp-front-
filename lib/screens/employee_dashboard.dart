// lib/screens/employee_dashboard.dart - NO CHANGES NEEDED HERE
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:sib_expense_app/components/dashboard_card.dart';
import 'package:sib_expense_app/screens/dashboard_template.dart';
// Import screens for navigation
import 'package:sib_expense_app/screens/affectations_screen.dart';
import 'package:sib_expense_app/screens/expense_claim_screen.dart';
import 'package:sib_expense_app/screens/leave_request_list_screen.dart';
import 'package:sib_expense_app/screens/leave_request_screen.dart';

import '../config/dio_client.dart';
import '../models/dashboard_data_dto.dart';


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
  bool _isRefreshing = false; // Track refresh state
  String? _refreshError;

  final Dio _dio = createDioClient(); // Use centralized Dio

  @override
  void initState() {
    super.initState();
    // Initial data fetch when the dashboard loads
    _refreshDashboardData();
  }

  // Fetches updated KPI data from the backend
  Future<void> _refreshDashboardData() async {
    if (_isRefreshing || !mounted) return; // Prevent concurrent refreshes

    setState(() {
      _isRefreshing = true;
      _refreshError = null; // Clear previous errors
    });

    try {
      print("Refreshing Employee Dashboard data...");

      // --- Option 1: Fetch dedicated employee KPIs endpoint (if exists) ---
      // Example: final response = await _dio.get('/api/dashboard/employee-kpis');
      // if (response.statusCode == 200) {
      //   final data = response.data;
      //   if (!mounted) return;
      //   setState(() {
      //     _pendingClaimsCount = data['myPendingClaims'] as int?;
      //     _openTasksCount = data['myOpenTasks'] as int?;
      //     _approvedLeaveDays = data['myApprovedLeaveDaysThisYear'] as int?;
      //   });
      // } else {
      //    _handleApiError(response, "Failed to refresh KPI data");
      // }


      // --- Option 2: Fetch the general dashboard data and extract needed values ---
      // (More likely if you implemented the dynamic dashboard endpoint)
      final response = await _dio.get('/api/dashboard/data');
      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        final dashboardDto = DashboardDataDto.fromJson(response.data);
        setState(() {
          // Use the specific fields for the employee from the DTO
          _pendingClaimsCount = dashboardDto
              .pendingExpenseClaims; // Assuming backend adjusts this for employee
          _openTasksCount = dashboardDto.myOpenTasks;
          _approvedLeaveDays = dashboardDto.myApprovedLeaveDaysThisYear;
        });
      } else {
        _handleApiError(response, "Failed to refresh dashboard data");
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, "refreshing dashboard data");
    } finally {
      if (mounted) {
        setState(() {
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

  @override
  Widget build(BuildContext context) {
    // Define colors for Employee cards
    const Color blueStart = Color(0xFF3A7BD5);
    const Color blueEnd = Color(0xFF00D2FF);
    const Color greenStart = Color(0xFF6DD5FA);
    const Color greenEnd = Color(0xFF23A6D5);
    const Color purpleStart = Color(0xFF8E2DE2);
    const Color purpleEnd = Color(0xFF4A00E0);
    const Color orangeStart = Color(0xFFFDC830);
    const Color orangeEnd = Color(0xFFF37335);

    String pendingClaimsValue = _isRefreshing ? "..." : (_pendingClaimsCount?.toString() ?? "0");
    String openTasksValue = _isRefreshing ? "..." : (_openTasksCount?.toString() ?? "0");
    String approvedLeaveValue = _isRefreshing ? "..." : ("${_approvedLeaveDays?.toString() ?? '0'} j.");

    return DashboardTemplate(
      title: 'Employee Dashboard',
      token: widget.token,
      onRefresh: _refreshDashboardData, // Pass the actual refresh function
      kpiCards: [
        if (_refreshError != null) // Show error as a card if refresh failed
          Card(
              color: Colors.redAccent.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_refreshError!, style: TextStyle(color: Colors.red[900])),
              )
          ),
        DashboardCard(
          title: 'Mes Notes de Frais (En Attente)',
          value: pendingClaimsValue, // Use state variable
          icon: Icons.receipt_long_outlined,
          startColor: orangeStart, endColor: orangeEnd,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AffectationsScreen(token: widget.token))),
        ),
        DashboardCard(
          title: 'Mes Tâches Ouvertes',
          value: openTasksValue, // Use state variable
          icon: Icons.task_alt_outlined,
          startColor: blueStart, endColor: blueEnd,
          onTap: () { /* TODO: Navigate to TaskListScreen */ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task list screen not yet implemented.'))); },
        ),
        DashboardCard(
          title: 'Congés Approuvés (Année)',
          value: approvedLeaveValue, // Use state variable
          icon: Icons.beach_access_outlined,
          startColor: greenStart, endColor: greenEnd,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LeaveRequestListScreen(token: widget.token))),
        ),
        DashboardCard(
          title: 'Demander un Congé',
          value: "+ Nouveau", // Keep static or change if needed
          icon: Icons.time_to_leave_outlined,
          startColor: purpleStart, endColor: purpleEnd,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LeaveRequestScreen(token: widget.token))).then((_) => _refreshDashboardData()), // Refresh after possibly submitting
        ),
        DashboardCard(
          title: 'Soumettre Note de Frais',
          value: "+ Nouveau", // Keep static
          icon: Icons.post_add_outlined,
          startColor: orangeStart.withOpacity(0.8), endColor: orangeEnd.withOpacity(0.8),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ExpenseClaimScreen(token: widget.token))).then((_) => _refreshDashboardData()), // Refresh after possibly submitting
        ),
        // Add more cards if needed based on your DashboardDataDto for employees
      ],
    );
  }
}