// lib/screens/manager_dashboard.dart - NO CHANGES NEEDED HERE
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:sib_expense_app/components/dashboard_card.dart';
import 'package:sib_expense_app/screens/dashboard_template.dart';
import 'package:sib_expense_app/screens/affectations_screen.dart';
import 'package:sib_expense_app/screens/leave_request_list_screen.dart';
import 'package:sib_expense_app/screens/employees_screen.dart';

import '../config/dio_client.dart';
import '../models/dashboard_data_dto.dart';
import 'leave_request_screen.dart';


class ManagerDashboard extends StatefulWidget {
  final String token;
  const ManagerDashboard({Key? key, required this.token}) : super(key: key);


  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  bool _isLoading = true;
  DashboardDataDto? _kpiData; // State for KPI data
  bool _isRefreshing = false;
  String? _errorMessage;

  final Dio _dio = createDioClient();
  // Example refresh function
  Future<void> _refreshDashboardData() async {
    if (_isRefreshing || !mounted) return;

    if (!_isLoading) { // Only set refreshing if not initial load
      setState(() { _isRefreshing = true; });
    }
    setState(() { _errorMessage = null; });

    try {
      print("Refreshing Manager Dashboard KPIs...");
      // Fetch the general dashboard data - the backend service differentiates by role
      final response = await _dio.get('/api/dashboard/data');

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _kpiData = DashboardDataDto.fromJson(response.data);
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
          _isLoading = false; // Mark initial load complete
          _isRefreshing = false;
        });
      }
    }
  }
  void _handleApiError(Response? response, String defaultMessage) {
    if (!mounted) return;
    String errorMsg = defaultMessage;
    if (response?.data is Map && response!.data.containsKey('error')) { errorMsg = response.data['error']; }
    else if (response?.statusMessage != null && response!.statusMessage!.isNotEmpty) { errorMsg = response.statusMessage!; }
    else if (response?.data != null){ errorMsg = response!.data.toString();}
    setState(() { _errorMessage = '$errorMsg (Status: ${response?.statusCode ?? 'N/A'})'; });
    print('$defaultMessage: ${response?.statusCode}, Response: ${response?.data}');
  }
  void _handleGenericError(Object e, String action) {
    if (!mounted) return;
    String errorMsg = 'Error $action: ${e.toString()}';
    if (e is DioError) {
      if (e.response != null && e.response?.data is Map && e.response?.data['error'] != null) { errorMsg = e.response?.data['error'];}
      else if (e.response != null && e.response?.data != null) { errorMsg = "Server Error (${e.response?.statusCode}): ${e.response?.data.toString().substring(0,100)}..."; }
      else if (e.response != null) { errorMsg = 'Server Error: ${e.response?.statusCode}'; }
      else { errorMsg = 'Network Error. Please check connection.'; }
    }
    setState(() { _errorMessage = errorMsg; });
    print('Error $action: $e');
  }
  @override
  Widget build(BuildContext context) {
    // Define colors for Manager cards
    const Color orangeStart = Color(0xFFFDC830); /*...*/ const Color orangeEnd = Color(0xFFF37335);
    const Color redStart = Color(0xFFEB5757); /*...*/ const Color redEnd = Color(0xFFB82E1F);
    const Color indigoStart = Color(0xFF5C6BC0); /*...*/ const Color indigoEnd = Color(0xFF283593);
    const Color tealStart = Color(0xFF4DB6AC); /*...*/ const Color tealEnd = Color(0xFF00695C);
    const Color cyanStart = Color(0xFF4DD0E1); /*...*/ const Color cyanEnd = Color(0xFF0097A7);

    // Get KPI values safely
    String pendingClaimsValue = _isLoading ? "..." : (_kpiData?.pendingExpenseClaims?.toString() ?? "0");
    String pendingLeaveValue = _isLoading ? "..." : (_kpiData?.pendingLeaveRequests?.toString() ?? "0");
    String activeAssignmentsValue = _isLoading ? "..." : (_kpiData?.teamAssignments?['ACTIVE']?.toString() ?? "0"); // Example accessing map data
    String totalEmployeesValue = _isLoading ? "..." : (_kpiData?.totalUsers?.toString() ?? "0"); // Assuming totalUsers includes employees + manager? Adjust if needed

    return DashboardTemplate(
      title: 'Manager Dashboard',
      token: widget.token,
      onRefresh: _refreshDashboardData,
      kpiCards: [
        // --- Error Card ---
        if (_errorMessage != null && !_isLoading)
          Card(
              color: Colors.redAccent.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Error loading data:\n$_errorMessage!", style: TextStyle(color: Colors.red[900])),
              )
          ),
        // --- End Error Card ---

        DashboardCard(
          title: 'Notes de Frais (À Valider)',
          value: pendingClaimsValue, // Use dynamic value
          icon: Icons.check_circle_outline,
          startColor: orangeStart, endColor: orangeEnd,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AffectationsScreen(token: widget.token))),
        ),
        DashboardCard(
          title: 'Demandes Congé (À Valider)',
          value: pendingLeaveValue, // Use dynamic value
          icon: Icons.event_available_outlined,
          startColor: redStart, endColor: redEnd,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LeaveRequestListScreen(token: widget.token))),
        ),
        DashboardCard(
          title: 'Affectations Actives (Équipe)',
          value: activeAssignmentsValue, // Use dynamic value
          icon: Icons.timeline_outlined,
          startColor: tealStart, endColor: tealEnd,
          onTap: () { /* TODO: Navigate to team assignments screen */ },
        ),
        DashboardCard(
          title: 'Gérer Employés',
          value: totalEmployeesValue, // Use dynamic value
          icon: Icons.group_outlined,
          startColor: indigoStart, endColor: indigoEnd,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EmployeesScreen(token: widget.token))),
        ),
        DashboardCard(
          title: 'Rapports d\'équipe',
          value: "Générer", // Keep static or change if report count is available
          icon: Icons.bar_chart_outlined,
          startColor: cyanStart, endColor: cyanEnd,
          onTap: () { /* TODO: Navigate to reports screen */ },
        ),
        // Manager might also request leave for themselves
        DashboardCard(
          title: 'Demander Congé (Perso)',
          value: "+",
          icon: Icons.time_to_leave_outlined,
          startColor: Colors.purple.shade300, endColor: Colors.purple.shade700,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LeaveRequestScreen(token: widget.token))).then((_) => _refreshDashboardData()),
        ),
      ],
    );
  }
}